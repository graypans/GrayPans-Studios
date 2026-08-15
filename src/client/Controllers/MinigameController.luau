--!strict
-- The four care minigames. Touch-first, bottom-anchored, driven by MinigameStart/Done/Cancel.
-- Failure inside the lock window just retries — TIME is the cost (Presence keeps filling).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local CareSteps = require(Shared:WaitForChild("Defs"):WaitForChild("CareSteps")) :: any
local SoundKit = require(Shared:WaitForChild("SoundKit")) :: any
local Theme = require(script.Parent.Parent:WaitForChild("Theme")) :: any

local MinigameController = {}

local gui: ScreenGui? = nil
local activePanel: Frame? = nil
local activeKey: string? = nil -- dollId..stepId
local heartbeat: RBXScriptConnection? = nil

local function closePanel()
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	if activePanel then
		activePanel:Destroy()
		activePanel = nil
	end
	activeKey = nil
end

local function finish(dollId: string, stepId: string, success: boolean)
	if activeKey ~= dollId .. stepId then
		return
	end
	if success then
		SoundKit.play("StepDone")
	end
	Remotes.get(Remotes.Names.MinigameDone):FireServer(dollId, stepId, success)
	closePanel()
end

local function makePanel(title: string, subtitle: string): (Frame, Frame)
	local g = gui
	assert(g, "gui missing")
	local panel = Theme.panel(g, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.new(0, 480, 0, 300),
		BackgroundTransparency = 0.06,
	})
	Theme.label(panel, {
		Position = UDim2.new(0, 0, 0, 10),
		Size = UDim2.new(1, 0, 0, 34),
		Font = Theme.TitleFont,
		TextSize = 28,
		Text = title,
	})
	Theme.label(panel, {
		Position = UDim2.new(0, 0, 0, 44),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 15,
		TextColor3 = Theme.Muted,
		Text = subtitle,
	})
	local arena = Instance.new("Frame")
	arena.BackgroundTransparency = 1
	arena.Position = UDim2.new(0, 16, 0, 70)
	arena.Size = UDim2.new(1, -32, 1, -86)
	arena.Parent = panel
	activePanel = panel
	return panel, arena
end

local function progressBar(panel: Frame): (Frame, (n: number) -> ())
	local barBg = Instance.new("Frame")
	barBg.AnchorPoint = Vector2.new(0.5, 1)
	barBg.Position = UDim2.new(0.5, 0, 1, -8)
	barBg.Size = UDim2.new(1, -32, 0, 10)
	barBg.BackgroundColor3 = Theme.BgSoft
	barBg.BorderSizePixel = 0
	barBg.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = barBg
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Theme.Gold
	fill.BorderSizePixel = 0
	fill.Parent = barBg
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(1, 0)
	fc.Parent = fill
	return barBg, function(n: number)
		fill.Size = UDim2.new(math.clamp(n, 0, 1), 0, 1, 0)
	end
end

-- ---------- minigames ----------

-- Procedural hairbrush icon (paddle head + bristles + handle), built from Frame/UICorner
-- instances -- same zero-asset technique as GlyphRender.luau -- so it never depends on Roblox's
-- emoji-glyph font coverage (B6: 🪮 rendered as a tofu box on some clients).
local function drawBrushIcon(parent: GuiObject)
	local canvas = Instance.new("Frame")
	canvas.BackgroundTransparency = 1
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.Parent = parent

	local head = Instance.new("Frame")
	head.AnchorPoint = Vector2.new(0.5, 0.5)
	head.Position = UDim2.fromScale(0.5, 0.36)
	head.Size = UDim2.fromScale(0.62, 0.36)
	head.BackgroundColor3 = Theme.Parchment
	head.BorderSizePixel = 0
	head.Parent = canvas
	local headCorner = Instance.new("UICorner")
	headCorner.CornerRadius = UDim.new(1, 0)
	headCorner.Parent = head

	for i = 1, 5 do
		local bristle = Instance.new("Frame")
		bristle.AnchorPoint = Vector2.new(0.5, 1)
		bristle.Position = UDim2.fromScale(0.19 + (i - 1) * 0.155, 0.2)
		bristle.Size = UDim2.fromScale(0.05, 0.2)
		bristle.BackgroundColor3 = Theme.Bg
		bristle.BorderSizePixel = 0
		bristle.Parent = canvas
		local bristleCorner = Instance.new("UICorner")
		bristleCorner.CornerRadius = UDim.new(1, 0)
		bristleCorner.Parent = bristle
	end

	local handle = Instance.new("Frame")
	handle.AnchorPoint = Vector2.new(0.5, 0.5)
	handle.Position = UDim2.fromScale(0.5, 0.78)
	handle.Size = UDim2.fromScale(0.16, 0.42)
	handle.BackgroundColor3 = Theme.Gold
	handle.BorderSizePixel = 0
	handle.Parent = canvas
	local handleCorner = Instance.new("UICorner")
	handleCorner.CornerRadius = UDim.new(1, 0)
	handleCorner.Parent = handle
end

local function mashGame(dollId: string, stepId: string, speedMultiplier: number)
	local panel, arena = makePanel("Brush the Hair", "Tap the brush — smooth every tangle!")
	local _, setProgress = progressBar(panel)
	local progress = 0
	local button = Theme.button(arena, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 160, 0, 120),
		Text = "",
	})
	drawBrushIcon(button)
	button.Activated:Connect(function()
		SoundKit.play("BrushStroke")
		-- SwiftHands class buff: speedMultiplier < 1 = faster, so divide (a smaller multiplier
		-- means a bigger per-tap increment, fewer taps needed to fill the bar).
		progress += 0.09 / speedMultiplier
		setProgress(progress)
		button.Rotation = (math.random() - 0.5) * 20
		if progress >= 1 then
			finish(dollId, stepId, true)
		end
	end)
end

local function holdGame(dollId: string, stepId: string, title: string, subtitle: string, speedMultiplier: number)
	local panel, arena = makePanel(title, subtitle)
	local _, setProgress = progressBar(panel)
	local progress = 0
	local holding = false
	local circle = Theme.button(arena, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 130, 0, 130),
		TextSize = 20,
		Text = "HOLD",
	})
	local corner = circle:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(1, 0)
	end
	circle.MouseButton1Down:Connect(function()
		holding = true
	end)
	circle.MouseButton1Up:Connect(function()
		holding = false
	end)
	local t = 0
	heartbeat = RunService.Heartbeat:Connect(function(dt: number)
		t += dt
		-- circle drifts slowly; player must keep the press
		circle.Position = UDim2.new(0.5 + math.sin(t * 0.7) * 0.22, 0, 0.5 + math.cos(t * 0.9) * 0.14, 0)
		if holding then
			-- SwiftHands class buff: speedMultiplier < 1 = faster fill.
			progress += dt / (4 * speedMultiplier)
			setProgress(progress)
			if progress >= 1 then
				finish(dollId, stepId, true)
			end
		end
	end)
end

local function sequenceGame(dollId: string, stepId: string, seed: number)
	local panel, arena = makePanel("Paint the Face", "Tap the paint dots IN ORDER — 1, 2, 3, 4, 5.")
	local _, setProgress = progressBar(panel)
	local rng = Random.new(seed)
	local expected = 1
	for i = 1, 5 do
		local dot = Theme.button(arena, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.12 + rng:NextNumber() * 0.76, 0, 0.15 + rng:NextNumber() * 0.7, 0),
			Size = UDim2.new(0, 64, 0, 64),
			TextSize = 26,
			Text = tostring(i),
		})
		local corner = dot:FindFirstChildOfClass("UICorner")
		if corner then
			corner.CornerRadius = UDim.new(1, 0)
		end
		dot.Activated:Connect(function()
			if i == expected then
				expected += 1
				dot.Visible = false
				setProgress((expected - 1) / 5)
				SoundKit.play("UiClick")
				if expected > 5 then
					finish(dollId, stepId, true)
				end
			else
				-- wrong tap: reset order (retry within the lock window)
				expected = 1
				setProgress(0)
				for _, child in arena:GetChildren() do
					if child:IsA("TextButton") then
						child.Visible = true
					end
				end
			end
		end)
	end
	local _ = panel
end

local function timingGame(dollId: string, stepId: string)
	local panel, arena = makePanel("Button the Coat", "Tap when the needle is in the GOLD zone. 3 buttons.")
	local _, setProgress = progressBar(panel)
	local hits = 0
	local zoneWidth = 0.3
	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0.5, 0.5)
	track.Position = UDim2.new(0.5, 0, 0.35, 0)
	track.Size = UDim2.new(0.9, 0, 0, 22)
	track.BackgroundColor3 = Theme.BgSoft
	track.BorderSizePixel = 0
	track.Parent = arena
	local zone = Instance.new("Frame")
	zone.BackgroundColor3 = Theme.Gold
	zone.BackgroundTransparency = 0.4
	zone.BorderSizePixel = 0
	zone.Parent = track
	local needle = Instance.new("Frame")
	needle.Size = UDim2.new(0, 4, 1.6, 0)
	needle.AnchorPoint = Vector2.new(0.5, 0.2)
	needle.BackgroundColor3 = Theme.Parchment
	needle.BorderSizePixel = 0
	needle.Parent = track
	local function rollZone()
		zone.Size = UDim2.new(zoneWidth, 0, 1, 0)
		zone.Position = UDim2.new(math.random() * (1 - zoneWidth), 0, 0, 0)
	end
	rollZone()
	local t = 0
	heartbeat = RunService.Heartbeat:Connect(function(dt: number)
		t += dt
		local x = (math.sin(t * 2.2) + 1) / 2
		needle.Position = UDim2.new(x, 0, 0, 0)
	end)
	local tapButton = Theme.button(arena, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.75, 0),
		Size = UDim2.new(0, 180, 0, 70),
		TextSize = 24,
		Text = "BUTTON IT",
	})
	tapButton.Activated:Connect(function()
		local x = needle.Position.X.Scale
		local z0 = zone.Position.X.Scale
		if x >= z0 and x <= z0 + zoneWidth then
			hits += 1
			setProgress(hits / 3)
			SoundKit.play("UiConfirm")
			zoneWidth = math.max(0.12, zoneWidth - 0.08)
			rollZone()
			if hits >= 3 then
				finish(dollId, stepId, true)
			end
		end
	end)
end

-- ---------- wiring ----------

function MinigameController.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local g = Theme.screenGui("PorcelainMinigames", 10)
	g.Parent = playerGui
	gui = g

	Remotes.get(Remotes.Names.MinigameStart).OnClientEvent:Connect(function(dollId: any, stepId: any, seed: any, speedMultiplierArg: any)
		if typeof(dollId) ~= "string" or typeof(stepId) ~= "string" then
			return
		end
		local speedMultiplier = if typeof(speedMultiplierArg) == "number" and speedMultiplierArg > 0
			then speedMultiplierArg
			else 1
		closePanel()
		activeKey = dollId .. stepId
		local step = CareSteps.byId[stepId]
		local kind = step and step.minigame or "mash"
		if kind == "mash" then
			mashGame(dollId, stepId, speedMultiplier)
		elseif kind == "hold" then
			if stepId == "Eyes" then
				holdGame(dollId, stepId, "Polish the Eyes", "Hold the cloth steady — follow it as it drifts.", speedMultiplier)
			else
				holdGame(dollId, stepId, "Wind the Music Box", "Hold the crank — don't let go until it sings.", speedMultiplier)
			end
		elseif kind == "sequence" then
			sequenceGame(dollId, stepId, if typeof(seed) == "number" then seed else 1)
		elseif kind == "timing" then
			timingGame(dollId, stepId)
		end
		-- client-side watchdog mirror (R2): close a bit after the server lock expires
		task.delay(Config.Care.MinigameSeconds + 2, function()
			if activeKey == dollId .. stepId then
				closePanel()
			end
		end)
	end)

	Remotes.get(Remotes.Names.MinigameCancel).OnClientEvent:Connect(function(dollId: any, stepId: any)
		if typeof(dollId) == "string" and typeof(stepId) == "string" and activeKey == dollId .. stepId then
			closePanel()
		end
	end)
end

return MinigameController
