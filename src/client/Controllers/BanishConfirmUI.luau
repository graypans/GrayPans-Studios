--!strict
-- The group-confirm modal: "Banish <NAME>?" with live countdown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local SoundKit = require(Shared:WaitForChild("SoundKit")) :: any
local Theme = require(script.Parent.Parent:WaitForChild("Theme")) :: any

local BanishConfirmUI = {}

local gui: ScreenGui? = nil
local modal: Frame? = nil
local titleLabel: TextLabel? = nil
local countdownLabel: TextLabel? = nil
local confirmed = false

local function build()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local g = Theme.screenGui("PorcelainBanishConfirm", 14)
	g.Enabled = false
	g.Parent = playerGui
	gui = g

	local m = Theme.panel(g, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.42, 0),
		Size = UDim2.new(0, 440, 0, 230),
		BackgroundTransparency = 0.04,
	})
	modal = m
	titleLabel = Theme.label(m, {
		Position = UDim2.new(0, 16, 0, 16),
		Size = UDim2.new(1, -32, 0, 70),
		Font = Theme.TitleFont,
		TextSize = 30,
		Text = "",
	})
	countdownLabel = Theme.label(m, {
		Position = UDim2.new(0, 16, 0, 88),
		Size = UDim2.new(1, -32, 0, 24),
		TextSize = 16,
		TextColor3 = Theme.Muted,
		Text = "",
	})
	local confirm = Theme.button(m, {
		Position = UDim2.new(0, 24, 1, -84),
		Size = UDim2.new(0.5, -36, 0, 64),
		TextSize = 24,
		Text = "BANISH",
	})
	local refuse = Theme.button(m, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 1, -84),
		Size = UDim2.new(0.5, -36, 0, 64),
		TextSize = 24,
		Text = "WAIT, NO",
	})
	confirm.Activated:Connect(function()
		if not confirmed then
			confirmed = true
			SoundKit.play("UiConfirm")
			Remotes.get(Remotes.Names.ConfirmBanish):FireServer(true)
			confirm.Text = "WAITING…"
		end
	end)
	refuse.Activated:Connect(function()
		SoundKit.play("UiClick")
		Remotes.get(Remotes.Names.ConfirmBanish):FireServer(false)
	end)
end

function BanishConfirmUI.init()
	build()

	Remotes.get(Remotes.Names.BanishPrompt).OnClientEvent:Connect(function(dollId: any, dollName: any, extra: any)
		local g = gui
		if not g then
			return
		end
		if typeof(extra) == "table" and extra.cancelled then
			g.Enabled = false
			confirmed = false
			return
		end
		if typeof(dollId) == "string" and typeof(dollName) == "string" then
			if not g.Enabled then
				confirmed = false
				local confirmButton = modal and modal:FindFirstChildOfClass("TextButton")
				if confirmButton then
					confirmButton.Text = "BANISH"
				end
			end
			g.Enabled = true
			if titleLabel then
				titleLabel.Text = ("Banish %s?"):format(dollName)
			end
		end
		if typeof(extra) == "table" and typeof(extra.countdown) == "number" and countdownLabel then
			countdownLabel.Text = ("Banishing in %d… (refuse to stop it)"):format(extra.countdown)
		end
	end)

	Remotes.get(Remotes.Names.BanishResult).OnClientEvent:Connect(function()
		local g = gui
		if g then
			g.Enabled = false
		end
		confirmed = false
	end)
end

return BanishConfirmUI
