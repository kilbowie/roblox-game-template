--[[
	HudController: Power, Stage and boost timer, the big Train button, Auto Train toggle,
	Shop button, and a slot for the rewarded-ad button.

	Reads only player attributes set by the server. It never decides gameplay.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))

local Ui = require(script.Parent:WaitForChild("Ui"))

local player = Players.LocalPlayer

export type Hud = {
	adSlot: Frame,
}

local HudController = {}

function HudController.Start(screenGui: ScreenGui, onShop: () -> ()): Hud
	local trainRemote = Net.event("Train")
	local autoRemote = Net.event("SetAutoTrain")

	-- Stats panel, top left
	local powerLabel = Ui.label({ Size = UDim2.fromScale(1, 0.45), Text = "Power 0" })
	local stageLabel = Ui.label({
		Position = UDim2.fromScale(0, 0.47),
		Size = UDim2.fromScale(1, 0.25),
		Text = "Stage 1",
		TextColor3 = Ui.Colours.Muted,
		Font = Enum.Font.GothamMedium,
	})
	local boostLabel = Ui.label({
		Position = UDim2.fromScale(0, 0.74),
		Size = UDim2.fromScale(1, 0.24),
		Text = "",
		TextColor3 = Ui.Colours.Good,
	})
	Ui.make("Frame", {
		Name = "Stats",
		Parent = screenGui,
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(260, 110),
		BackgroundColor3 = Ui.Colours.Panel,
		BackgroundTransparency = 0.15,
	}, { Ui.corner(14), Ui.padding(12), powerLabel, stageLabel, boostLabel })

	-- Train button, bottom centre
	local trainButton = Ui.button({
		Name = "Train",
		Parent = screenGui,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(220, 72),
		Text = "TRAIN +1",
	})
	trainButton.Activated:Connect(function()
		trainRemote:FireServer()
	end)
	ContextActionService:BindAction("Train", function(_, state)
		if state == Enum.UserInputState.Begin then
			trainRemote:FireServer()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonR2)

	-- Side column, right
	local column = Ui.make("Frame", {
		Name = "SideColumn",
		Parent = screenGui,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(170, 260),
		BackgroundTransparency = 1,
	}, {
		Ui.make("UIListLayout", {
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})

	local shopButton = Ui.button({
		Name = "Shop",
		Parent = column,
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 52),
		Text = "SHOP",
	})
	shopButton.Activated:Connect(onShop)

	local autoButton = Ui.button({
		Name = "AutoTrain",
		Parent = column,
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = Ui.Colours.Panel,
		TextColor3 = Ui.Colours.Text,
		Text = "AUTO: OFF",
		Visible = false,
	})
	autoButton.Activated:Connect(function()
		autoRemote:FireServer(not player:GetAttribute("AutoTrain"))
	end)

	local adSlot = Ui.make("Frame", {
		Name = "AdSlot",
		Parent = column,
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundTransparency = 1,
	})

	-- Bind attributes to labels
	local function refresh()
		local power = player:GetAttribute("Power") or 0
		local stageIndex = player:GetAttribute("Stage") or 1
		local stage = GameConfig.Stages[stageIndex]
		local nextStage = GameConfig.Stages[stageIndex + 1]

		powerLabel.Text = `Power {Ui.abbreviate(power)}`
		stageLabel.Text = if nextStage
			then `{stage.name}  ·  next at {Ui.abbreviate(nextStage.requiredPower)}`
			else `{stage.name}  ·  max`

		local auto = player:GetAttribute("AutoTrain") == true
		autoButton.Visible = player:GetAttribute("Pass_AutoTrain") == true
		autoButton.Text = if auto then "AUTO: ON" else "AUTO: OFF"
		autoButton.BackgroundColor3 = if auto then Ui.Colours.Good else Ui.Colours.Panel
	end

	for _, name in { "Power", "Stage", "AutoTrain", "Pass_AutoTrain" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()

	-- Boost countdown
	task.spawn(function()
		while screenGui.Parent do
			local untilTime = player:GetAttribute("Gains2xUntil") or 0
			local remaining = untilTime - workspace:GetServerTimeNow()
			boostLabel.Text = if remaining > 0 then `2x BOOST  {Ui.clock(remaining)}` else ""
			task.wait(1)
		end
	end)

	return { adSlot = adSlot }
end

return HudController
