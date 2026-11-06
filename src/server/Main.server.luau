--[[
	Server entry point. Start order matters:
	1. DataService       - everything else reads save data
	2. Game services     - register their grant kinds before receipts can arrive
	3. MonetisationService - installs ProcessReceipt
	4. RewardedAdService
]]

local Services = script.Parent:WaitForChild("Services")
local Game = script.Parent:WaitForChild("Game")

local DataService = require(Services:WaitForChild("DataService"))
local MonetisationService = require(Services:WaitForChild("MonetisationService"))
local RewardedAdService = require(Services:WaitForChild("RewardedAdService"))
local TrainingService = require(Game:WaitForChild("TrainingService"))

DataService.Start()
TrainingService.Start()
MonetisationService.Start()
RewardedAdService.Start()
