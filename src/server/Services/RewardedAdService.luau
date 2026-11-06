--[[
	RewardedAdService: shows a rewarded video ad when the client asks, with a per-player
	cooldown. The reward itself is a developer product (Products.DevProducts.AdBoost) and
	is granted through ProcessReceipt like any purchase, so it inherits the same
	idempotent, saved-before-confirmed handling.

	Roblox eligibility (check current docs before launch): creator 13+, ID-verified,
	public game with at least 2,000 unique visitors a month.
]]

local AdService = game:GetService("AdService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Products = require(Shared:WaitForChild("Config"):WaitForChild("Products"))
local Net = require(Shared:WaitForChild("Net"))

local MonetisationService = require(script.Parent:WaitForChild("MonetisationService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))

local RewardedAdService = {}

local lastShownAt: { [Player]: number } = {}

local function findAdRewardProduct(): Products.DevProductDef?
	for _, def in Products.DevProducts do
		if def.adReward then
			return def
		end
	end
	return nil
end

function RewardedAdService.Start()
	local rewardDef = findAdRewardProduct()

	Net.func("RequestRewardedAd").OnServerInvoke = function(player: Player): (boolean, string)
		if not rewardDef or not Products.isConfigured(rewardDef) then
			return false, "not-configured"
		end
		if GameConfig.Ads.HideForSpenders and MonetisationService.IsSpender(player) then
			return false, "spender"
		end

		local now = os.clock()
		local last = lastShownAt[player]
		if last and now - last < GameConfig.Ads.CooldownSeconds then
			return false, "cooldown"
		end
		lastShownAt[player] = now

		Telemetry.custom(player, "RewardedAdRequested")
		local ok, result = pcall(function()
			local reward = AdService:CreateAdRewardFromDevProductId(rewardDef.id)
			return AdService:ShowRewardedVideoAdAsync(player, reward)
		end)

		if not ok then
			lastShownAt[player] = nil -- don't punish the player for a failed ad
			return false, tostring(result)
		end
		return true, tostring(result)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastShownAt[player] = nil
	end)
end

return RewardedAdService
