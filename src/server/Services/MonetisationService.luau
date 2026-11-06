--[[
	MonetisationService: game passes and developer products, done safely.

	Developer products (ProcessReceipt):
	  1. Unknown player or unloaded data  -> NotProcessedYet (Roblox retries later).
	  2. Receipt already recorded         -> confirm it is saved, then PurchaseGranted.
	  3. Run the grant handler, record the PurchaseId in the SAME save data, save now.
	  4. Only return PurchaseGranted once that save succeeded.
	This makes grants idempotent: a retry can never grant twice, and a crash before the
	save means Roblox retries and the player still gets the item.

	Game passes: ownership is checked on join and on purchase, cached per player, and
	mirrored to a "Pass_<Key>" attribute so client UI can react.

	Game code adds new product kinds with:
		MonetisationService.RegisterGrant("power", function(player, data, def) ... end)
	Handlers must not yield and must either fully succeed or error without side effects.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Products = require(Shared:WaitForChild("Config"):WaitForChild("Products"))
local Signal = require(Shared:WaitForChild("Signal"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))

type GrantHandler = (player: Player, data: { [string]: any }, def: Products.DevProductDef) -> ()

local MonetisationService = {}

-- (player, passKey)
MonetisationService.PassOwned = Signal.new()
-- (player, productKey, def) fired after a developer product is granted AND saved
MonetisationService.ProductGranted = Signal.new()

local DATA_WAIT_SECONDS = 15

local grantHandlers: { [string]: GrantHandler } = {}
local ownedPasses: { [Player]: { [string]: boolean } } = {}

function MonetisationService.RegisterGrant(kind: string, handler: GrantHandler)
	assert(grantHandlers[kind] == nil, `Grant kind "{kind}" is already registered`)
	grantHandlers[kind] = handler
end

function MonetisationService.HasPass(player: Player, passKey: string): boolean
	local owned = ownedPasses[player]
	return owned ~= nil and owned[passKey] == true
end

-- True if the player has ever paid Robux in this game (used to hide ads from spenders).
function MonetisationService.IsSpender(player: Player): boolean
	local owned = ownedPasses[player]
	if owned and next(owned) ~= nil then
		return true
	end
	local data = DataService.Get(player)
	return data ~= nil and (data.robuxSpent or 0) > 0
end

local function refreshSpenderAttribute(player: Player)
	player:SetAttribute("IsSpender", MonetisationService.IsSpender(player))
end

local function setPassOwned(player: Player, passKey: string)
	local owned = ownedPasses[player]
	if not owned then
		owned = {}
		ownedPasses[player] = owned
	end
	if owned[passKey] then
		return
	end
	owned[passKey] = true
	player:SetAttribute(`Pass_{passKey}`, true)
	refreshSpenderAttribute(player)
	MonetisationService.PassOwned:Fire(player, passKey)
end

local function loadPassOwnership(player: Player)
	for passKey, def in Products.Passes do
		if not Products.isConfigured(def) then
			continue
		end
		task.spawn(function()
			for attempt = 1, 3 do
				local ok, owns = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, def.id)
				end)
				if ok then
					if owns then
						setPassOwned(player, passKey)
					end
					return
				end
				task.wait(attempt * 2)
			end
			warn(`[Monetisation] Could not check pass {passKey} for {player.Name}`)
		end)
	end
end

local function rememberReceipt(data: { [string]: any }, purchaseId: string)
	local receipts = data.receipts
	receipts[purchaseId] = os.time()

	-- Keep only the most recent N receipts so save data stays small.
	local limit = GameConfig.Data.ReceiptHistorySize
	local count = 0
	for _ in receipts do
		count += 1
	end
	while count > limit do
		local oldestId, oldestAt = nil, math.huge
		for id, at in receipts do
			if at < oldestAt then
				oldestId, oldestAt = id, at
			end
		end
		if oldestId == nil then
			break
		end
		receipts[oldestId] = nil
		count -= 1
	end
end

local function processReceipt(receipt): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local data = DataService.WaitFor(player, DATA_WAIT_SECONDS)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receipt.PurchaseId)

	if data.receipts[purchaseId] then
		-- Granted earlier (possibly on this server before a failed save).
		-- Confirm only once it is durably saved.
		return if DataService.SaveNow(player)
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productKey, def = Products.findDevProductById(receipt.ProductId)
	if not productKey or not def then
		warn(`[Monetisation] Receipt for unknown product {receipt.ProductId}. Add it to Products.luau.`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local handler = grantHandlers[def.grant]
	if not handler then
		warn(`[Monetisation] No grant handler for kind "{def.grant}" ({productKey}).`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, err = pcall(handler, player, data, def)
	if not ok then
		warn(`[Monetisation] Grant for {productKey} failed:`, err)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	rememberReceipt(data, purchaseId)
	data.robuxSpent = (data.robuxSpent or 0) + (receipt.CurrencySpent or 0)
	DataService.MarkDirty(player)

	if not DataService.SaveNow(player) then
		-- The grant and its receipt are in memory; Roblox will retry and the
		-- "already recorded" branch above confirms once a save succeeds.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	refreshSpenderAttribute(player)
	Telemetry.custom(player, `Purchase_{productKey}`, receipt.CurrencySpent or 0)
	MonetisationService.ProductGranted:Fire(player, productKey, def)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function warnAboutUnconfigured()
	local missing = {}
	for key, def in Products.Passes do
		if not Products.isConfigured(def) then
			table.insert(missing, `pass {key}`)
		end
	end
	for key, def in Products.DevProducts do
		if not Products.isConfigured(def) then
			table.insert(missing, `product {key}`)
		end
	end
	if #missing > 0 then
		warn(
			`[Monetisation] Not configured yet (id = 0): {table.concat(missing, ", ")}. See docs/MONETISATION.md.`
		)
	end
end

function MonetisationService.Start()
	-- Built-in grant kind: timed boosts that stack.
	MonetisationService.RegisterGrant("boost", function(_player, data, def)
		assert(def.boost and def.seconds, "boost products need `boost` and `seconds`")
		local now = os.time()
		local current = data.boosts[def.boost] or 0
		data.boosts[def.boost] = math.max(current, now) + def.seconds
	end)

	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		if not wasPurchased then
			return
		end
		local passKey = Products.findPassById(passId)
		if passKey then
			setPassOwned(player, passKey)
			Telemetry.custom(player, `PassPurchase_{passKey}`)
		end
	end)

	DataService.Loaded:Connect(function(player)
		refreshSpenderAttribute(player)
	end)
	Players.PlayerAdded:Connect(loadPassOwnership)
	for _, player in Players:GetPlayers() do
		loadPassOwnership(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		ownedPasses[player] = nil
	end)

	if RunService:IsStudio() then
		warnAboutUnconfigured()
	end
end

return MonetisationService
