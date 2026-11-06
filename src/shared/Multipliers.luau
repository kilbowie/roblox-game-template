--[[
	Multipliers: pure maths shared by server (authoritative) and client (display only).
]]

local GameConfig = require(script.Parent:WaitForChild("Config"):WaitForChild("GameConfig"))

export type GainInputs = {
	doubleGains: boolean,
	vip: boolean,
	boost2x: boolean,
}

local Multipliers = {}

function Multipliers.gain(inputs: GainInputs): number
	local multiplier = 1
	if inputs.doubleGains then
		multiplier *= GameConfig.Multipliers.DoubleGainsPass
	end
	if inputs.vip then
		multiplier *= GameConfig.Multipliers.VipPass
	end
	if inputs.boost2x then
		multiplier *= GameConfig.Multipliers.Gains2xBoost
	end
	return multiplier
end

-- Index of the highest stage unlocked at this Power (1-based).
function Multipliers.stageFor(power: number): number
	local index = 1
	for i, stage in GameConfig.Stages do
		if power >= stage.requiredPower then
			index = i
		end
	end
	return index
end

return Multipliers
