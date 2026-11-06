--[[
	AdController: shows a "free boost" rewarded-ad button only when an ad is actually
	available and the player is not a spender. The server shows the ad and grants the
	reward through ProcessReceipt.
]]

local AdService = game:GetService("AdService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))

local Ui = require(script.Parent:WaitForChild("Ui"))

local player = Players.LocalPlayer

local AdController = {}

local function adAvailable(): boolean
	local ok, result = pcall(function()
		return AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)
	end)
	return ok and result ~= nil and result.AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable
end

function AdController.Start(slot: Frame)
	local requestAd = Net.func("RequestRewardedAd")
	local clientSignal = Net.event("ClientSignal")

	local button = Ui.button({
		Name = "FreeBoost",
		Parent = slot,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Ui.Colours.Good,
		Text = "FREE 2x BOOST",
		Visible = false,
	})

	local available = false
	local busy = false
	local reportedShown = false

	local function refresh()
		local hideForSpender = GameConfig.Ads.HideForSpenders and player:GetAttribute("IsSpender") == true
		button.Visible = available and not hideForSpender and not busy
		if button.Visible and not reportedShown then
			reportedShown = true
			clientSignal:FireServer("AdButtonShown")
		end
	end

	button.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		refresh()
		local invoked, ok = pcall(function()
			return requestAd:InvokeServer()
		end)
		if invoked and ok then
			available = false -- re-poll before offering another
		end
		busy = false
		refresh()
	end)

	player:GetAttributeChangedSignal("IsSpender"):Connect(refresh)

	task.spawn(function()
		while slot.Parent do
			available = adAvailable()
			refresh()
			task.wait(GameConfig.Ads.AvailabilityPollSeconds)
		end
	end)
end

return AdController
