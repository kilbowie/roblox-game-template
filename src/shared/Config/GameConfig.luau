--[[
	GameConfig: every tunable number for this game lives here.

	When you start a new game from the template, this file and Products.luau are the
	first two files you edit. Services read from here and never hard-code values.
]]

local GameConfig = {}

GameConfig.GameName = "Untitled +1 Game"

GameConfig.Data = {
	-- DataStore name. Bump the suffix freely during development to start everyone fresh.
	-- NEVER change it after launch: players would lose their progress.
	StoreName = "PlayerData_v1",
	AutosaveSeconds = 60,
	-- A server that has not refreshed its session lock for this long is treated as crashed.
	SessionLockSeconds = 180,
	-- How many purchase IDs to remember per player for duplicate-receipt protection.
	ReceiptHistorySize = 100,
}

-- Default save data for a brand-new player. New keys added here are back-filled
-- into existing saves automatically when they next join.
GameConfig.DataTemplate = {
	version = 1,
	power = 0,
	stage = 1,
	totalTrains = 0,
	autoTrainEnabled = false,
	onboardingStep = 0,
	robuxSpent = 0,
	boosts = {}, -- [boostName] = unix time the boost expires
	receipts = {}, -- [purchaseId] = unix time it was granted
	firstJoin = 0,
	lastJoin = 0,
}

GameConfig.Train = {
	BaseGain = 1,
	-- Server-side cap on manual trains per second (stops auto-clickers and exploits).
	MaxPerSecond = 8,
	AutoTrainIntervalSeconds = 1,
}

-- Stages unlock as Power grows. Map doors or teleports read the player's "Stage" attribute.
GameConfig.Stages = {
	{ name = "Stage 1", requiredPower = 0 },
	{ name = "Stage 2", requiredPower = 100 },
	{ name = "Stage 3", requiredPower = 500 },
	{ name = "Stage 4", requiredPower = 2000 },
	{ name = "Stage 5", requiredPower = 7500 },
	{ name = "Stage 6", requiredPower = 25000 },
	{ name = "Stage 7", requiredPower = 80000 },
	{ name = "Stage 8", requiredPower = 250000 },
}

GameConfig.Multipliers = {
	DoubleGainsPass = 2,
	VipPass = 1.25,
	Gains2xBoost = 2,
}

GameConfig.Ads = {
	-- Minimum time between rewarded video ads for one player.
	CooldownSeconds = 300,
	-- Hide the ad button for players who have paid Robux, so ads never cannibalise sales.
	HideForSpenders = true,
	-- How often the client re-checks whether an ad is available to show.
	AvailabilityPollSeconds = 30,
}

-- Onboarding funnel steps, logged once each per player in this order.
GameConfig.OnboardingSteps = {
	"Joined",
	"FirstTrain",
	"Trained25",
	"FirstStageUnlocked",
}

return GameConfig
