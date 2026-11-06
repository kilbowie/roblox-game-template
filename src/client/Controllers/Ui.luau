--[[
	Ui: small helpers for building placeholder UI in code.

	The template ships functional, plain UI so a game is playable on day one. Replace it with
	designed UI (built in Studio or in code) once a game passes its retention gate.
]]

local Ui = {}

Ui.Colours = {
	Background = Color3.fromRGB(18, 24, 44),
	Panel = Color3.fromRGB(28, 36, 64),
	Accent = Color3.fromRGB(232, 184, 74),
	AccentDark = Color3.fromRGB(176, 132, 40),
	Text = Color3.fromRGB(245, 245, 250),
	Muted = Color3.fromRGB(170, 176, 200),
	Good = Color3.fromRGB(86, 196, 120),
}

-- Create an instance, set properties, parent children. Ui.make("Frame", { Size = ... }, { child })
function Ui.make(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	if props then
		for key, value in props do
			if key ~= "Parent" then
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function Ui.corner(radius: number?): UICorner
	return Ui.make("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function Ui.padding(pixels: number): UIPadding
	local p = UDim.new(0, pixels)
	return Ui.make("UIPadding", { PaddingTop = p, PaddingBottom = p, PaddingLeft = p, PaddingRight = p })
end

function Ui.label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = Ui.Colours.Text,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in props do
		defaults[key] = value
	end
	return Ui.make("TextLabel", defaults)
end

function Ui.button(props: { [string]: any }): TextButton
	local defaults = {
		AutoButtonColor = true,
		BackgroundColor3 = Ui.Colours.Accent,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Ui.Colours.Background,
		TextScaled = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	local button = Ui.make("TextButton", defaults, { Ui.corner(12), Ui.padding(6) })
	return button
end

-- 1234 -> "1.2K", 5600000 -> "5.6M"
function Ui.abbreviate(value: number): string
	local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi" }
	local index = 1
	local n = math.floor(value)
	local display = n
	while display >= 1000 and index < #suffixes do
		display /= 1000
		index += 1
	end
	if index == 1 then
		return tostring(n)
	end
	return string.format("%.1f%s", display, suffixes[index])
end

function Ui.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Ui
