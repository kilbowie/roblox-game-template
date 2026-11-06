--[[
	TrainingService: the G1 "+1" core loop.

	Train -> gain Power (x multipliers) -> unlock Stages -> repeat.
	This is the game-specific layer: copy the template for a new game and replace this
	folder, keeping the Services folder (data, monetisation, ads, telemetry) as it is.

	Exposes to the map / other scripts:
	- Player attributes: Power, Stage, Gains2xUntil, AutoTrain
	- TrainingService.StageUnlocked signal: (player, stageIndex)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Multipliers = require(Shared:WaitForChild("Multipliers"))
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))

local Services = script.Parent.Parent:WaitForChild("Services")
local DataService = require(Services:WaitForChild("DataService"))
local MonetisationService = require(Services:WaitForChild("MonetisationService"))
local Telemetry = require(Services:WaitForChild("Telemetry"))

local TrainingService = {}

-- (player, stageIndex)
TrainingService.StageUnlocked = Signal.new()

local CLIENT_SIGNALS = { ShopOpened = true, AdButtonShown = true }

type RateWindow = { second: number, count: number }
local rateWindows: { [Player]: RateWindow } = {}

local function advanceOnboarding(player: Player, data: { [string]: any }, step: number)
	if data.onboardingStep >= step then
		return
	end
	-- Log any skipped steps too, so the funnel stays in order.
	for s = data.onboardingStep + 1, step do
		Telemetry.onboarding(player, s, GameConfig.OnboardingSteps[s])
	end
	data.onboardingStep = step
end

local function ensureLeaderstats(player: Player): Folder
	local folder = player:FindFirstChild("leaderstats") :: Folder?
	if folder then
		return folder
	end
	local created = Instance.new("Folder")
	created.Name = "leaderstats"

	local power = Instance.new("IntValue")
	power.Name = "Power"
	power.Parent = created

	local stage = Instance.new("IntValue")
	stage.Name = "Stage"
	stage.Parent = created

	created.Parent = player
	return created
end

-- Mirror save data into leaderstats + attributes for the client UI and map scripts.
local function sync(player: Player, data: { [string]: any })
	local leaderstats = ensureLeaderstats(player)
	local powerValue = leaderstats:FindFirstChild("Power") :: IntValue
	local stageValue = leaderstats:FindFirstChild("Stage") :: IntValue
	powerValue.Value = math.floor(data.power)
	stageValue.Value = data.stage

	player:SetAttribute("Power", data.power)
	player:SetAttribute("Stage", data.stage)
	player:SetAttribute("Gains2xUntil", data.boosts.Gains2x or 0)
	player:SetAttribute("AutoTrain", data.autoTrainEnabled)
end

local function gainMultiplier(player: Player, data: { [string]: any }): number
	return Multipliers.gain({
		doubleGains = MonetisationService.HasPass(player, "DoubleGains"),
		vip = MonetisationService.HasPass(player, "VIP"),
		boost2x = (data.boosts.Gains2x or 0) > os.time(),
	})
end

local function addPower(player: Player, data: { [string]: any }, amount: number)
	data.power += amount

	local newStage = Multipliers.stageFor(data.power)
	if newStage > data.stage then
		for stageIndex = data.stage + 1, newStage do
			Telemetry.stageReached(player, stageIndex, GameConfig.Stages[stageIndex].name)
			TrainingService.StageUnlocked:Fire(player, stageIndex)
		end
		data.stage = newStage
		advanceOnboarding(player, data, 4)
	end

	DataService.MarkDirty(player)
	sync(player, data)
end

local function train(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end

	data.totalTrains += 1
	addPower(player, data, GameConfig.Train.BaseGain * gainMultiplier(player, data))

	if data.totalTrains >= 25 then
		advanceOnboarding(player, data, 3)
	else
		advanceOnboarding(player, data, 2)
	end
end

local function withinRateLimit(player: Player): boolean
	local second = math.floor(os.clock())
	local window = rateWindows[player]
	if not window or window.second ~= second then
		rateWindows[player] = { second = second, count = 1 }
		return true
	end
	window.count += 1
	return window.count <= GameConfig.Train.MaxPerSecond
end

function TrainingService.GetStage(player: Player): number
	local data = DataService.Get(player)
	return if data then data.stage else 1
end

function TrainingService.Start()
	-- Developer products of kind "power": instant Power, scaled by current stage
	-- so packs stay worth buying as players progress.
	MonetisationService.RegisterGrant("power", function(player, data, def)
		assert(def.amount, "power products need `amount`")
		local amount = def.amount * data.stage
		addPower(player, data, amount)
		Telemetry.powerFromPurchase(player, amount, data.power, def.name)
	end)

	-- Refresh UI attributes after any purchase (boost timers, Power packs).
	MonetisationService.ProductGranted:Connect(function(player)
		local data = DataService.Get(player)
		if data then
			sync(player, data)
		end
	end)

	DataService.Loaded:Connect(function(player, data)
		advanceOnboarding(player, data, 1)
		sync(player, data)
	end)

	Net.event("Train").OnServerEvent:Connect(function(player)
		if withinRateLimit(player) then
			train(player)
		end
	end)

	Net.event("SetAutoTrain").OnServerEvent:Connect(function(player, enabled)
		if type(enabled) ~= "boolean" then
			return
		end
		local data = DataService.Get(player)
		if not data then
			return
		end
		data.autoTrainEnabled = enabled and MonetisationService.HasPass(player, "AutoTrain")
		DataService.MarkDirty(player)
		sync(player, data)
	end)

	Net.event("ClientSignal").OnServerEvent:Connect(function(player, name)
		if type(name) == "string" and CLIENT_SIGNALS[name] then
			Telemetry.custom(player, name)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		rateWindows[player] = nil
	end)

	-- Auto Train loop for pass owners who switched it on.
	task.spawn(function()
		while true do
			task.wait(GameConfig.Train.AutoTrainIntervalSeconds)
			for _, player in Players:GetPlayers() do
				local data = DataService.Get(player)
				if data and data.autoTrainEnabled and MonetisationService.HasPass(player, "AutoTrain") then
					train(player)
				end
			end
		end
	end)
end

return TrainingService
