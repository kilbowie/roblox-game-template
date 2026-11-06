--[[
	DataService: loads, autosaves and releases each player's save data.

	- Session locking: a save record carries the JobId of the server that owns it. Another
	  server will not load it until the lock is released or goes stale, which prevents the
	  classic "joined a new server before the old one saved" data loss and item duplication.
	- If data cannot be loaded, the player is kicked rather than allowed to play on a blank
	  save that would later overwrite their real progress.
	- In Studio without API access, it falls back to in-memory data and warns once.

	Usage from other services:
		local data = DataService.Get(player)      -- nil until loaded
		data.power += 1
		DataService.MarkDirty(player)
		DataService.SaveNow(player)               -- yields; use for purchases only
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Signal = require(Shared:WaitForChild("Signal"))

type Profile = {
	key: string,
	data: { [string]: any },
	dirty: boolean,
	saving: boolean,
	released: boolean,
}

local DataService = {}

-- Fired once a player's data is ready: (player, data)
DataService.Loaded = Signal.new()

local LOAD_ATTEMPTS = 6
local LOCKED_RETRY_SECONDS = 8

local store: DataStore? = nil
local memoryOnly = false
local profiles: { [Player]: Profile } = {}

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Fill in keys that exist in the template but not in an older save.
local function reconcile(data: { [string]: any }, template: { [string]: any })
	for key, default in template do
		if data[key] == nil then
			data[key] = deepCopy(default)
		elseif type(default) == "table" and type(data[key]) == "table" and next(default) ~= nil then
			reconcile(data[key], default)
		end
	end
end

local function keyFor(player: Player): string
	return `player_{player.UserId}`
end

local function enterMemoryMode(reason: any)
	if memoryOnly then
		return
	end
	memoryOnly = true
	warn(
		"[DataService] Using in-memory data (nothing will save). Enable Game Settings > Security >"
			.. " 'Enable Studio Access to API Services' to test real saves. Reason:",
		reason
	)
end

-- Returns (success, data or nil, lockedByAnotherServer, error)
local function tryAcquire(key: string): (boolean, { [string]: any }?, boolean, any)
	local loaded: { [string]: any }? = nil
	local locked = false

	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key, function(record)
			record = record or {}
			local lock = record.lock
			local now = os.time()
			if
				lock
				and lock.jobId ~= game.JobId
				and now - (lock.at or 0) < GameConfig.Data.SessionLockSeconds
			then
				locked = true
				return nil -- cancel the write; another live server owns this save
			end
			locked = false
			loaded = record.data
			record.lock = { jobId = game.JobId, at = now }
			return record
		end)
	end)

	if not ok then
		return false, nil, false, err
	end
	return true, loaded, locked, nil
end

local function newData(): { [string]: any }
	local data = deepCopy(GameConfig.DataTemplate)
	data.firstJoin = os.time()
	return data
end

local function loadProfile(player: Player)
	local key = keyFor(player)
	local data: { [string]: any }? = nil

	if store and not memoryOnly then
		for attempt = 1, LOAD_ATTEMPTS do
			local ok, loaded, locked, err = tryAcquire(key)
			if ok and not locked then
				data = loaded or newData()
				break
			elseif not ok and RunService:IsStudio() then
				enterMemoryMode(err)
				break
			elseif not ok then
				warn(`[DataService] Load attempt {attempt} failed for {player.Name}:`, err)
				task.wait(attempt * 2)
			else
				-- Locked by another server that is probably still saving. Wait for it.
				task.wait(LOCKED_RETRY_SECONDS)
			end
			if not player.Parent then
				return
			end
		end
	end

	if memoryOnly then
		data = newData()
	end

	if not data then
		player:Kick("We couldn't load your save safely. Please rejoin in a minute; your progress is safe.")
		return
	end

	local loadedData = data :: { [string]: any }
	reconcile(loadedData, GameConfig.DataTemplate)
	loadedData.lastJoin = os.time()

	local profile: Profile = {
		key = key,
		data = loadedData,
		dirty = false,
		saving = false,
		released = false,
	}

	if not player.Parent then
		-- They left while we were loading: release the lock we just took.
		profiles[player] = profile
		DataService._release(player)
		return
	end

	profiles[player] = profile
	DataService.Loaded:Fire(player, loadedData)
end

-- Writes the profile. Returns true only if the data is durably saved.
local function write(profile: Profile, release: boolean): boolean
	if memoryOnly or not store then
		profile.dirty = false
		return true
	end

	while profile.saving do
		task.wait()
	end
	profile.saving = true

	local lostLock = false
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(profile.key, function(record)
			record = record or {}
			local lock = record.lock
			if lock and lock.jobId ~= game.JobId then
				-- Our lock went stale and another server took over. Never overwrite its data.
				lostLock = true
				return nil
			end
			record.data = profile.data
			record.lock = if release then nil else { jobId = game.JobId, at = os.time() }
			return record
		end)
	end)

	profile.saving = false

	if not ok then
		warn("[DataService] Save failed:", err)
		return false
	end
	if lostLock then
		warn("[DataService] Session lock lost for", profile.key, "- not saving over the newer session.")
		return false
	end
	profile.dirty = false
	return true
end

function DataService.Get(player: Player): { [string]: any }?
	local profile = profiles[player]
	return if profile and not profile.released then profile.data else nil
end

-- Yields until the player's data is loaded or the timeout passes.
function DataService.WaitFor(player: Player, timeoutSeconds: number): { [string]: any }?
	local deadline = os.clock() + timeoutSeconds
	while os.clock() < deadline do
		local data = DataService.Get(player)
		if data then
			return data
		end
		if not player.Parent then
			return nil
		end
		task.wait(0.1)
	end
	return DataService.Get(player)
end

function DataService.MarkDirty(player: Player)
	local profile = profiles[player]
	if profile then
		profile.dirty = true
	end
end

-- Save immediately. Yields. Use after purchases; normal play relies on autosave.
function DataService.SaveNow(player: Player): boolean
	local profile = profiles[player]
	if not profile or profile.released then
		return false
	end
	return write(profile, false)
end

function DataService.IsMemoryOnly(): boolean
	return memoryOnly
end

function DataService._release(player: Player)
	local profile = profiles[player]
	if not profile or profile.released then
		return
	end
	profile.released = true
	for attempt = 1, 3 do
		if write(profile, true) then
			break
		end
		task.wait(attempt)
	end
	profiles[player] = nil
end

function DataService.Start()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.Data.StoreName)
	end)
	if ok then
		store = result
	elseif RunService:IsStudio() then
		enterMemoryMode(result)
	else
		error(`[DataService] Could not open DataStore: {result}`)
	end

	Players.PlayerAdded:Connect(loadProfile)
	-- Deferred so every service has connected to DataService.Loaded before the first fire.
	for _, player in Players:GetPlayers() do
		task.defer(loadProfile, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		DataService._release(player)
	end)

	-- Autosave also refreshes each session lock, so it runs even when nothing changed.
	task.spawn(function()
		while true do
			task.wait(GameConfig.Data.AutosaveSeconds)
			for _, profile in profiles do
				if not profile.released then
					task.spawn(write, profile, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				DataService._release(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
