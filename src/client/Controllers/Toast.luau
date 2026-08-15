--!strict
-- Bottom-center transient message queue. Other controllers may require this for local toasts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local Theme = require(script.Parent.Parent:WaitForChild("Theme")) :: any

local Toast = {}

local gui: ScreenGui? = nil
local container: Frame? = nil

local function ensureGui()
	if gui and gui.Parent then
		return
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local g = Theme.screenGui("PorcelainToast", 20)
	g.Parent = playerGui
	local c = Instance.new("Frame")
	c.BackgroundTransparency = 1
	c.AnchorPoint = Vector2.new(0.5, 1)
	c.Position = UDim2.new(0.5, 0, 1, -110)
	c.Size = UDim2.new(0.7, 0, 0, 200)
	c.Parent = g
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, 6)
	layout.Parent = c
	gui = g
	container = c
end

function Toast.show(message: string, seconds: number?)
	ensureGui()
	local c = container
	if not c then
		return
	end
	local panel = Theme.panel(c, {
		Size = UDim2.new(1, 0, 0, 44),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.25,
	})
	local label = Theme.label(panel, {
		Size = UDim2.new(1, -24, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0, 12, 0, 10),
		Font = Theme.TitleFont,
		TextSize = 22,
		Text = message,
	})
	local pad = Instance.new("UIPadding")
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = panel
	local _ = label
	task.delay(seconds or 4, function()
		TweenService:Create(panel, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		for _, child in panel:GetDescendants() do
			if child:IsA("TextLabel") then
				TweenService:Create(child, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			end
		end
		task.delay(0.6, function()
			panel:Destroy()
		end)
	end)
end

function Toast.init()
	ensureGui()
	Remotes.get(Remotes.Names.Toast).OnClientEvent:Connect(function(message: any, seconds: any)
		if typeof(message) == "string" then
			Toast.show(message, if typeof(seconds) == "number" then seconds else nil)
		end
	end)
end

return Toast
