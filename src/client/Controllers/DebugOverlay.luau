--!strict
-- Debug overlay (R7): presence, tier, state, watched map, marked doll. DebugMode only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local Theme = require(script.Parent.Parent:WaitForChild("Theme")) :: any

local DebugOverlay = {}

function DebugOverlay.init()
	if not Config.DebugMode then
		return
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Theme.screenGui("PorcelainDebug", 25)
	gui.Parent = playerGui
	local panel = Theme.panel(gui, {
		Position = UDim2.new(0, 8, 0.35, 0),
		Size = UDim2.new(0, 240, 0, 10),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.35,
	})
	local text = Theme.label(panel, {
		Position = UDim2.new(0, 8, 0, 6),
		Size = UDim2.new(1, -16, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.Code,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "debug: waiting…",
	})
	local pad = Instance.new("UIPadding")
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = panel

	Remotes.get(Remotes.Names.DebugInfo).OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end
		local lines = {
			("state: %s   shift: %s"):format(tostring(payload.state), tostring(payload.shift)),
			("presence: %s  tier: %s"):format(tostring(payload.presence), tostring(payload.tier)),
			("marked: %s"):format(tostring(payload.marked)),
			"watched:",
		}
		if typeof(payload.watched) == "table" then
			for dollId, watched in payload.watched do
				table.insert(lines, ("  %s %s"):format(if watched then "👁" else "·", tostring(dollId)))
			end
		end
		text.Text = table.concat(lines, "\n")
	end)
end

return DebugOverlay
