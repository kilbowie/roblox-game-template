--[[
	ShopController: lists every configured pass and developer product from Products.luau,
	shows live Robux prices, and opens Roblox's purchase prompt.

	Prompting happens on the client; granting happens only on the server.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Products = require(Shared:WaitForChild("Config"):WaitForChild("Products"))
local Net = require(Shared:WaitForChild("Net"))

local Ui = require(script.Parent:WaitForChild("Ui"))

local player = Players.LocalPlayer

local ShopController = {}

local function sortedKeys(map: { [string]: any }): { string }
	local keys = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

local function fetchPrice(id: number, infoType: Enum.InfoType, label: TextLabel)
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, infoType)
		end)
		if ok and info and info.PriceInRobux then
			label.Text = `R$ {info.PriceInRobux}`
		end
	end)
end

local function makeRow(
	list: Instance,
	order: number,
	title: string,
	description: string
): (TextLabel, TextButton)
	local priceLabel = Ui.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -120, 0, 6),
		Size = UDim2.fromOffset(90, 26),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Ui.Colours.Accent,
	})
	local buyButton = Ui.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(104, 44),
		Text = "BUY",
	})
	Ui.make("Frame", {
		Parent = list,
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 72),
		BackgroundColor3 = Ui.Colours.Panel,
	}, {
		Ui.corner(10),
		Ui.padding(10),
		Ui.label({ Size = UDim2.new(1, -230, 0, 28), Text = title }),
		Ui.label({
			Position = UDim2.fromOffset(0, 30),
			Size = UDim2.new(1, -120, 0, 20),
			Text = description,
			Font = Enum.Font.GothamMedium,
			TextColor3 = Ui.Colours.Muted,
		}),
		priceLabel,
		buyButton,
	})
	return priceLabel, buyButton
end

function ShopController.Start(screenGui: ScreenGui): () -> ()
	local clientSignal = Net.event("ClientSignal")
	local showUnconfigured = RunService:IsStudio()

	local list = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 1, -56),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromOffset(0, 0),
	}, {
		Ui.make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local closeButton = Ui.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(44, 44),
		Text = "X",
	})

	local panel = Ui.make("Frame", {
		Name = "Shop",
		Parent = screenGui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.65),
		BackgroundColor3 = Ui.Colours.Background,
		Visible = false,
	}, {
		Ui.corner(16),
		Ui.padding(16),
		Ui.make("UISizeConstraint", { MinSize = Vector2.new(320, 300), MaxSize = Vector2.new(640, 560) }),
		Ui.label({ Size = UDim2.new(1, -60, 0, 44), Text = "SHOP" }),
		closeButton,
		list,
	})

	local order = 0

	-- Game passes
	for _, key in sortedKeys(Products.Passes) do
		local def = Products.Passes[key]
		local configured = Products.isConfigured(def)
		if not configured and not showUnconfigured then
			continue
		end
		order += 1
		local priceLabel, buyButton = makeRow(list, order, def.name, def.description)

		local function refreshOwned()
			local owned = player:GetAttribute(`Pass_{key}`) == true
			buyButton.Text = if owned then "OWNED" else "BUY"
			buyButton.Active = not owned
			buyButton.AutoButtonColor = not owned
		end
		player:GetAttributeChangedSignal(`Pass_{key}`):Connect(refreshOwned)
		refreshOwned()

		if configured then
			fetchPrice(def.id, Enum.InfoType.GamePass, priceLabel)
			buyButton.Activated:Connect(function()
				if player:GetAttribute(`Pass_{key}`) ~= true then
					MarketplaceService:PromptGamePassPurchase(player, def.id)
				end
			end)
		else
			priceLabel.Text = "id = 0"
		end
	end

	-- Developer products (ad rewards are never sold)
	for _, key in sortedKeys(Products.DevProducts) do
		local def = Products.DevProducts[key]
		local configured = Products.isConfigured(def)
		if def.adReward or (not configured and not showUnconfigured) then
			continue
		end
		order += 1
		local priceLabel, buyButton = makeRow(list, order, def.name, def.description)
		if configured then
			fetchPrice(def.id, Enum.InfoType.Product, priceLabel)
			buyButton.Activated:Connect(function()
				MarketplaceService:PromptProductPurchase(player, def.id)
			end)
		else
			priceLabel.Text = "id = 0"
		end
	end

	local function toggle()
		panel.Visible = not panel.Visible
		if panel.Visible then
			clientSignal:FireServer("ShopOpened")
		end
	end
	closeButton.Activated:Connect(toggle)

	return toggle
end

return ShopController
