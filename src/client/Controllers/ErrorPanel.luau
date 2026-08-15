--!strict
-- Error panel (R7): last 10 client errors, screenshot-friendly, toggled by a small bug button.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptContext = game:GetService("ScriptContext")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Theme = require(script.Parent.Parent:WaitForChild("Theme")) :: any

local ErrorPanel = {}

local errors: { string } = {}

function ErrorPanel.init()
	if not Config.DebugMode then
		return
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Theme.screenGui("PorcelainErrors", 26)
	gui.Parent = playerGui

	local panel = Theme.panel(gui, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -90),
		Size = UDim2.new(0, 420, 0, 200),
		BackgroundTransparency = 0.15,
		Visible = false,
	})
	local text = Theme.label(panel, {
		Position = UDim2.new(0, 8, 0, 26),
		Size = UDim2.new(1, -16, 1, -34),
		Font = Enum.Font.Code,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Theme.Danger,
		Text = "no client errors 🎉  (server errors: check Studio Output)",
	})
	Theme.label(panel, {
		Position = UDim2.new(0, 8, 0, 4),
		Size = UDim2.new(1, -16, 0, 20),
		TextSize = 13,
		TextColor3 = Theme.Muted,
		Text = "last 10 client errors — screenshot this for bug reports",
	})

	local toggle = Theme.button(gui, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -14),
		Size = UDim2.new(0, 64, 0, 64),
		TextSize = 26,
		Text = "🐞",
	})
	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)

	ScriptContext.Error:Connect(function(message: string, _trace: string, _source: Instance?)
		table.insert(errors, 1, ("[%s] %s"):format(os.date("%H:%M:%S"), message))
		while #errors > 10 do
			table.remove(errors)
		end
		text.Text = table.concat(errors, "\n")
	end)
end

return ErrorPanel
