--[[
	Telemetry: thin, crash-proof wrapper over Roblox AnalyticsService.

	Everything the kill / scale gates need lands in Creator Hub analytics:
	- Onboarding funnel  -> day-1 retention diagnosis (where new players drop off)
	- Progression        -> how far players get
	- Economy            -> where Power comes from (play vs purchases)
	- Custom events      -> purchases, ad views, shop opens

	Every call is wrapped in pcall: analytics must never break gameplay.
]]

local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local Telemetry = {}

local function safely(label: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok and RunService:IsStudio() then
		warn(`[Telemetry] {label} failed:`, err)
	end
end

function Telemetry.onboarding(player: Player, step: number, stepName: string)
	safely("onboarding", function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
	end)
end

function Telemetry.stageReached(player: Player, stageIndex: number, stageName: string)
	safely("progression", function()
		AnalyticsService:LogProgressionEvent(
			player,
			"Stages",
			Enum.AnalyticsProgressionType.Complete,
			stageIndex,
			stageName
		)
	end)
end

-- Power granted by a purchase (an in-app purchase "source" in the economy view).
function Telemetry.powerFromPurchase(player: Player, amount: number, endingBalance: number, sku: string)
	safely("economy", function()
		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Power",
			amount,
			endingBalance,
			Enum.AnalyticsEconomyTransactionType.IAP.Name,
			sku
		)
	end)
end

function Telemetry.custom(player: Player, eventName: string, value: number?)
	safely("custom", function()
		AnalyticsService:LogCustomEvent(player, eventName, value or 1)
	end)
end

return Telemetry
