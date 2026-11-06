--[[
	Net: one place that owns every RemoteEvent and RemoteFunction.

	The server creates them on first use; clients wait for them. Add a name to the lists
	below rather than creating remotes ad hoc, so every network entry point is visible here.

	Rule: the server never trusts arguments from a remote. Validate type, range and rate.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local EVENTS = {
	"Train", -- client -> server: one manual train action
	"SetAutoTrain", -- client -> server: (enabled: boolean)
	"ClientSignal", -- client -> server: (name: string) whitelisted UI events for analytics
}

local FUNCTIONS = {
	"RequestRewardedAd", -- client -> server: returns (ok: boolean, detail: string)
}

local Net = {}

local folder: Folder? = nil

local function getFolder(): Folder
	if folder then
		return folder
	end

	if RunService:IsServer() then
		local created = ReplicatedStorage:FindFirstChild(FOLDER_NAME) :: Folder?
		if not created then
			created = Instance.new("Folder")
			created.Name = FOLDER_NAME
			created.Parent = ReplicatedStorage
		end
		local resolved = created :: Folder

		for _, name in EVENTS do
			if not resolved:FindFirstChild(name) then
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = resolved
			end
		end
		for _, name in FUNCTIONS do
			if not resolved:FindFirstChild(name) then
				local remote = Instance.new("RemoteFunction")
				remote.Name = name
				remote.Parent = resolved
			end
		end
		folder = resolved
	else
		folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
	end

	return folder :: Folder
end

function Net.event(name: string): RemoteEvent
	assert(table.find(EVENTS, name), `Unknown RemoteEvent "{name}". Add it to Net.EVENTS.`)
	return getFolder():WaitForChild(name) :: RemoteEvent
end

function Net.func(name: string): RemoteFunction
	assert(table.find(FUNCTIONS, name), `Unknown RemoteFunction "{name}". Add it to Net.FUNCTIONS.`)
	return getFolder():WaitForChild(name) :: RemoteFunction
end

return Net
