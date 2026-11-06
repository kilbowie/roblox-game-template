--[[
	Products: the single source of truth for every game pass and developer product.

	IDs start at 0 (= not configured). After the first publish, create each item in
	Creator Hub > your game > Monetization, then paste its ID here. Unconfigured items
	are hidden in the shop and skipped by the server.

	Developer products carry a `grant` kind. The server looks up a handler for that kind
	(MonetisationService.RegisterGrant) and runs it when a purchase receipt arrives.
]]

export type PassDef = {
	id: number,
	name: string,
	description: string,
}

export type DevProductDef = {
	id: number,
	name: string,
	description: string,
	grant: string,
	-- Optional fields used by specific grant kinds:
	boost: string?,
	seconds: number?,
	amount: number?,
	-- True for the product that rewarded video ads grant. It is never sold in the shop.
	adReward: boolean?,
}

local Products = {}

-- Game passes: bought once, owned forever.
Products.Passes = {
	DoubleGains = {
		id = 2075703049,
		name = "2x Gains",
		description = "Double every gain, forever.",
	},
	AutoTrain = {
		id = 2075043029,
		name = "Auto Train",
		description = "Trains for you while you explore.",
	},
	VIP = {
		id = 2075019009,
		name = "VIP",
		description = "+25% gains on everything.",
	},
} :: { [string]: PassDef }

-- Developer products: can be bought again and again.
Products.DevProducts = {
	Boost2x15m = {
		id = 3729047303,
		name = "2x Boost (15 min)",
		description = "Double gains for 15 minutes. Stacks.",
		grant = "boost",
		boost = "Gains2x",
		seconds = 900,
	},
	PowerPackSmall = {
		id = 3729047488,
		name = "Power Pack",
		description = "Instant Power, scaled to your stage.",
		grant = "power",
		amount = 250,
	},
	PowerPackLarge = {
		id = 3729047633,
		name = "Mega Power Pack",
		description = "A big instant Power jump, scaled to your stage.",
		grant = "power",
		amount = 2000,
	},
	AdBoost = {
		id = 3729048111,
		name = "Free 2x Boost",
		description = "Granted for watching a rewarded video ad.",
		grant = "boost",
		boost = "Gains2x",
		seconds = 300,
		adReward = true,
	},
} :: { [string]: DevProductDef }

function Products.isConfigured(def: PassDef | DevProductDef): boolean
	return def.id ~= 0
end

function Products.findPassById(passId: number): (string?, PassDef?)
	for key, def in Products.Passes do
		if def.id == passId then
			return key, def
		end
	end
	return nil, nil
end

function Products.findDevProductById(productId: number): (string?, DevProductDef?)
	for key, def in Products.DevProducts do
		if def.id == productId then
			return key, def
		end
	end
	return nil, nil
end

return Products
