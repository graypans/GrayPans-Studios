--!strict
-- Bottom-of-screen action bar shown while the local player stands inside a Join Square:
-- Exit / Skip Tutorial (only once unlocked) / Start Now. Mirrors BanishConfirmUI's panel-with-
-- buttons construction, bottom-anchored instead of center-anchored (mobile-first).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local SoundKit = require(Shared:WaitForChild("SoundKit")) :: any
local Theme = require(script.Parent.Parent:WaitForChild("Theme")) :: any

local JoinSquareUI = {}

local localPlayer = Players.LocalPlayer

local gui: ScreenGui? = nil
local countdownLabel: TextLabel? = nil
local skipButton: TextButton? = nil
local currentSquareId: string? = nil
local lastLocalPhase: string? = nil -- tracks the local player's own square, so the lock-in chime fires once
-- fed by the PlayerStats remote (QuestService.broadcastStats); real value, not a stub -- the
-- Social track's tutorial-gate design suppresses first-shift hints once this flips true, and this
-- button intentionally stays available even then (see "READ THIS FIRST" §5's option (a)).
local tutorialDone = false

local function build()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local g = Theme.screenGui("PorcelainJoinSquare", 12)
	g.Enabled = false
	g.Parent = playerGui
	gui = g

	local panel = Theme.panel(g, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.new(0.94, 0, 0, 150),
		BackgroundTransparency = 0.06,
	})
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MaxSize = Vector2.new(560, 220)
	sizeConstraint.MinSize = Vector2.new(300, 150)
	sizeConstraint.Parent = panel

	countdownLabel = Theme.label(panel, {
		Position = UDim2.new(0, 16, 0, 10),
		Size = UDim2.new(1, -32, 0, 28),
		TextSize = 18,
		TextColor3 = Theme.Accent,
		Text = "",
	})

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.new(0, 16, 0, 46)
	row.Size = UDim2.new(1, -32, 0, 84)
	row.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = row

	-- Colors match the reference screenshots exactly: EXIT red, START NOW green, the middle
	-- (Skip Tutorial) button left at the theme's neutral default -- the reference shows it
	-- visibly blanked/disabled-looking whenever it's locked, which Theme.BgSoft + a disabled
	-- Active=false already achieves without a bespoke color (see tutorialDone gating below).
	local function actionButton(text: string, bg: Color3?): TextButton
		local button = Theme.button(row, {
			Size = UDim2.new(0.31, 0, 1, 0), -- relative width: scales down gracefully on narrow phones
			TextSize = 18,
			Text = text,
		})
		if bg then
			button.BackgroundColor3 = bg
		end
		return button
	end

	local exit = actionButton("EXIT", Theme.Danger) -- red, matches the reference
	local skip = actionButton("SKIP TUTORIAL")
	skip.Visible = false
	local start = actionButton("START NOW", Color3.fromRGB(70, 160, 80)) -- green, matches the reference
		-- (no confirmed Theme.* "success green" token exists yet in this codebase's Theme.luau --
		-- using an explicit literal here; if the team adds one, swap this for Theme.Success instead)

	exit.Activated:Connect(function()
		if not currentSquareId then
			return
		end
		SoundKit.play("UiClick")
		Remotes.get(Remotes.Names.JoinSquareAction):FireServer(currentSquareId, "Exit")
	end)
	start.Activated:Connect(function()
		if not currentSquareId then
			return
		end
		SoundKit.play("UiConfirm")
		Remotes.get(Remotes.Names.JoinSquareAction):FireServer(currentSquareId, "StartNow")
	end)
	skip.Activated:Connect(function()
		if not currentSquareId then
			return
		end
		SoundKit.play("UiClick")
		Remotes.get(Remotes.Names.JoinSquareAction):FireServer(currentSquareId, "SkipTutorial")
	end)

	skipButton = skip
end

local function setVisible(visible: boolean)
	local g = gui
	if not g then
		return
	end
	g.Enabled = visible
	if not visible then
		currentSquareId = nil
	end
end

function JoinSquareUI.init()
	build()

	Remotes.get(Remotes.Names.PlayerStats).OnClientEvent:Connect(function(stats: any)
		if typeof(stats) == "table" then
			tutorialDone = stats.tutorialDone == true
		end
	end)

	Remotes.get(Remotes.Names.JoinSquareUpdate).OnClientEvent:Connect(function(squareId: any, data: any)
		if typeof(squareId) ~= "string" or typeof(data) ~= "table" then
			return
		end
		local occupantIds = data.occupantUserIds
		local isLocalHere = typeof(occupantIds) == "table"
			and table.find(occupantIds, localPlayer.UserId) ~= nil
		if isLocalHere then
			currentSquareId = squareId
			setVisible(true)
			if skipButton then
				skipButton.Visible = tutorialDone
			end
			if data.phase == "Locking" and lastLocalPhase ~= "Locking" then
				SoundKit.play("SquareLockIn")
			end
			lastLocalPhase = data.phase
		elseif currentSquareId == squareId then
			-- we were in this square and just dropped out of its occupant list (Exit / walked away)
			setVisible(false)
			lastLocalPhase = nil
		end
	end)

	Remotes.get(Remotes.Names.JoinSquareCountdown).OnClientEvent:Connect(function(squareId: any, seconds: any)
		if squareId ~= currentSquareId or not countdownLabel then
			return
		end
		countdownLabel.Text = if typeof(seconds) == "number"
			then ("Shift starts in %d… (Exit to leave the group)"):format(seconds)
			else "Waiting for your group…"
	end)
end

return JoinSquareUI
