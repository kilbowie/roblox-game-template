--[[
	Client entry point: builds the placeholder UI and wires the controllers together.
]]

local Players = game:GetService("Players")

local Controllers = script.Parent:WaitForChild("Controllers")
local AdController = require(Controllers:WaitForChild("AdController"))
local HudController = require(Controllers:WaitForChild("HudController"))
local ShopController = require(Controllers:WaitForChild("ShopController"))

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GameHud"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local toggleShop = ShopController.Start(screenGui)
local hud = HudController.Start(screenGui, toggleShop)
AdController.Start(hud.adSlot)
