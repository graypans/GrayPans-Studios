--!strict
-- The staged banish-reveal beat + the end-of-run recap card.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local SoundKit = require(Shared:WaitForChild("SoundKit")) :: any
local Theme = require(script.Parent.Parent:WaitForChild("Theme")) :: any

local RecapUI = {}

local gui: ScreenGui? = nil

local function black(transparency: number): Frame
	local g = gui
	assert(g)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BackgroundTransparency = transparency
	frame.BorderSizePixel = 0
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.ZIndex = 2
	frame.Parent = g
	return frame
end

-- The reveal: black flash -> sting -> name-slam line
local function playReveal(data: any)
	local g = gui
	if not g then
		return
	end
	local flash = black(0)
	SoundKit.play(if data.correct then "StingReveal" else "StingWrong")
	local text
	if data.correct then
		text = ("%s WAS %s"):format(string.upper(data.dollName or "?"), string.upper(data.spiritName or "THE SPIRIT"))
	elseif data.incomplete then
		-- A4: this WAS the marked doll -- never tell players it was "innocent".
		text = ("THE BOX WOULD NOT CLOSE ON %s… SOMETHING IS MISSING."):format(string.upper(data.dollName or "?"))
	else
		text = ("%s WAS INNOCENT."):format(string.upper(data.dollName or "?"))
	end
	local line = Theme.label(g, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.45, 0),
		Size = UDim2.new(0.9, 0, 0, 120),
		Font = Theme.TitleFont,
		TextSize = 12,
		TextColor3 = if data.correct then Theme.Gold elseif data.incomplete then Theme.Accent else Theme.Sickly,
		TextStrokeTransparency = 0.3,
		ZIndex = 3,
		Text = text,
	})
	TweenService:Create(line, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextSize = 52 }):Play()
	task.delay(3, function()
		TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(line, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.delay(0.9, function()
			flash:Destroy()
			line:Destroy()
		end)
	end)
end

local function showRecap(data: any)
	local g = gui
	if not g then
		return
	end
	local dim = black(0.35)
	local card = Theme.panel(g, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 460, 0, 424),
		BackgroundTransparency = 0.02,
		ZIndex = 3,
	})
	Theme.label(card, {
		Position = UDim2.new(0, 0, 0, 14),
		Size = UDim2.new(1, 0, 0, 26),
		TextSize = 16,
		TextColor3 = Theme.Muted,
		Text = "THE NIGHT ENDS",
	})
	Theme.label(card, {
		Position = UDim2.new(0, 0, 0, 40),
		Size = UDim2.new(1, 0, 0, 110),
		Font = Theme.TitleFont,
		TextSize = 92,
		Text = ("SHIFT %d"):format(data.shiftReached or 0),
	})
	-- B9: the recap must not always imply "the Presence got you" -- say the real cause.
	Theme.label(card, {
		Position = UDim2.new(0, 0, 0, 150),
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 14,
		TextColor3 = Theme.Muted,
		Text = if data.reason == "watchdog"
			then "The night ran long. The shop had to close before the Presence ever caught you."
			else "The Presence caught up with you.",
	})
	local statLines = {
		("Dolls cared for: %d"):format(data.dollsCleared or 0),
		("The traitor was %s."):format(data.traitorName or "…unknown"),
		("Best shift: %d"):format(data.bestShift or 0),
	}
	for i, text in statLines do
		Theme.label(card, {
			Position = UDim2.new(0, 0, 0, 178 + (i - 1) * 30),
			Size = UDim2.new(1, 0, 0, 26),
			Font = Theme.TitleFont,
			TextSize = 21,
			Text = text,
		})
	end
	if data.isNewBest then
		Theme.label(card, {
			Position = UDim2.new(0, 0, 0, 270),
			Size = UDim2.new(1, 0, 0, 34),
			Font = Theme.TitleFont,
			TextSize = 30,
			TextColor3 = Theme.Gold,
			Text = "✦ NEW BEST ✦",
		})
	end
	if data.perfect then
		Theme.label(card, {
			Position = UDim2.new(0, 0, 0, 302),
			Size = UDim2.new(1, 0, 0, 26),
			TextSize = 16,
			TextColor3 = Theme.Gold,
			Text = "Perfect shifts, zero strikes. The Dollmaker approves.",
		})
	end
	local button = Theme.button(card, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(0, 220, 0, 56),
		TextSize = 22,
		Text = "RETURN",
	})
	button.Activated:Connect(function()
		dim:Destroy()
		card:Destroy()
	end)
	task.delay(20, function()
		if dim.Parent then
			dim:Destroy()
			card:Destroy()
		end
	end)
end

function RecapUI.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local g = Theme.screenGui("PorcelainRecap", 16)
	g.Parent = playerGui
	gui = g

	Remotes.get(Remotes.Names.BanishResult).OnClientEvent:Connect(function(data: any)
		if typeof(data) == "table" then
			playReveal(data)
		end
	end)
	Remotes.get(Remotes.Names.Recap).OnClientEvent:Connect(function(data: any)
		if typeof(data) == "table" then
			task.delay(1, function()
				showRecap(data)
			end)
		end
	end)
end

return RecapUI
