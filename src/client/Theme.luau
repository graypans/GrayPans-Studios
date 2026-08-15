--!strict
-- Client UI theme: horror-storybook. One place for colors/fonts + small constructors.

local Theme = {}

Theme.Bg = Color3.fromRGB(18, 14, 20)
Theme.BgSoft = Color3.fromRGB(28, 22, 32)
Theme.Parchment = Color3.fromRGB(230, 220, 200)
Theme.Muted = Color3.fromRGB(170, 155, 175)
Theme.Gold = Color3.fromRGB(212, 175, 96)
Theme.Sickly = Color3.fromRGB(120, 160, 90)
Theme.Danger = Color3.fromRGB(180, 70, 70)
Theme.Accent = Color3.fromRGB(150, 120, 220)

Theme.TitleFont = Enum.Font.Garamond
Theme.BodyFont = Enum.Font.Gotham

function Theme.screenGui(name: string, displayOrder: number?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = displayOrder or 5
	return gui
end

function Theme.panel(parent: Instance, props: { [string]: any }): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Theme.Bg
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	for k, v in props do
		(frame :: any)[k] = v
	end
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Muted
	stroke.Transparency = 0.65
	stroke.Thickness = 1
	stroke.Parent = frame
	frame.Parent = parent
	return frame
end

function Theme.label(parent: Instance, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Theme.BodyFont
	label.TextColor3 = Theme.Parchment
	label.TextWrapped = true
	for k, v in props do
		(label :: any)[k] = v
	end
	label.Parent = parent
	return label
end

function Theme.button(parent: Instance, props: { [string]: any }): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = Theme.BgSoft
	button.BorderSizePixel = 0
	button.Font = Theme.TitleFont
	button.TextColor3 = Theme.Parchment
	button.AutoButtonColor = true
	for k, v in props do
		(button :: any)[k] = v
	end
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Gold
	stroke.Transparency = 0.7
	stroke.Thickness = 1
	stroke.Parent = button
	button.Parent = parent
	return button
end

return Theme
