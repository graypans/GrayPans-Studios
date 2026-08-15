--!strict
-- The Dollmaker's ledger: spirits + codes on the left, shared slots + found tray on the right.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local Glyphs = require(Shared:WaitForChild("Defs"):WaitForChild("Glyphs")) :: any
local Spirits = require(Shared:WaitForChild("Defs"):WaitForChild("Spirits")) :: any
local GlyphMatch = require(Shared:WaitForChild("Logic"):WaitForChild("GlyphMatch")) :: any
local GlyphRender = require(Shared:WaitForChild("GlyphRender")) :: any
local SoundKit = require(Shared:WaitForChild("SoundKit")) :: any
local Theme = require(script.Parent.Parent:WaitForChild("Theme")) :: any

local LedgerUI = {}

local gui: ScreenGui? = nil
local slotFrames: { Frame } = {}
local trayFrame: Frame? = nil
local matchBanner: TextLabel? = nil
local found: { string } = {}
local slots: { [number]: string? } = {}
local selectedGlyph: string? = nil
local deskPart: BasePart? = nil
local distanceConn: RBXScriptConnection? = nil

-- ---------- open / close + walk-away auto-close (B5) ----------

local function stopDistanceWatch()
	if distanceConn then
		distanceConn:Disconnect()
		distanceConn = nil
	end
end

local function closeBook()
	if gui then
		gui.Enabled = false
	end
	stopDistanceWatch()
end

local function getLedgerDesk(): BasePart?
	if deskPart and deskPart.Parent then
		return deskPart
	end
	local tagged = CollectionService:GetTagged("LedgerDesk")
	local part = tagged[1]
	if part and part:IsA("BasePart") then
		deskPart = part
		return deskPart
	end
	return nil
end

local function startDistanceWatch()
	stopDistanceWatch()
	local desk = getLedgerDesk()
	if not desk then
		-- desk not found (shouldn't happen once MapBuilder has run) -- fail open rather than
		-- trap the player with an unclosable book (R2)
		return
	end
	distanceConn = RunService.Heartbeat:Connect(function()
		local g = gui
		if not g or not g.Enabled then
			stopDistanceWatch()
			return
		end
		local char = Players.LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		if (root.Position - desk.Position).Magnitude > Config.Ledger.AutoCloseDistance then
			closeBook()
		end
	end)
end

local function openBook()
	if not gui then
		return
	end
	gui.Enabled = true
	startDistanceWatch()
end

local function glyphButton(parent: Instance, glyphId: string, size: number, onTap: (() -> ())?): TextButton
	local button = Theme.button(parent, {
		Size = UDim2.new(0, size, 0, size),
		Text = "",
	})
	local canvas = Instance.new("Frame")
	canvas.BackgroundTransparency = 1
	canvas.Size = UDim2.new(1, -10, 1, -10)
	canvas.Position = UDim2.new(0, 5, 0, 5)
	canvas.Parent = button
	GlyphRender.render(glyphId, canvas)
	if onTap then
		button.Activated:Connect(onTap)
	end
	return button
end

local function refreshSlots()
	for i, frame in slotFrames do
		for _, child in frame:GetChildren() do
			if child:IsA("Frame") or child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		local glyphId = slots[i]
		if glyphId then
			local canvas = Instance.new("Frame")
			canvas.BackgroundTransparency = 1
			canvas.Size = UDim2.new(1, -10, 1, -10)
			canvas.Position = UDim2.new(0, 5, 0, 5)
			canvas.Parent = frame
			GlyphRender.render(glyphId, canvas, Theme.Gold)
		else
			Theme.label(frame, {
				Size = UDim2.new(1, 0, 1, 0),
				Font = Theme.TitleFont,
				TextSize = 30,
				TextColor3 = Theme.Muted,
				TextTransparency = 0.5,
				Text = tostring(i),
			})
		end
	end
	-- client-side match feedback (server stays authoritative)
	if matchBanner then
		local spiritId = GlyphMatch.identify(Spirits.list, slots)
		if spiritId then
			local spirit = Spirits.byId[spiritId]
			matchBanner.Text = ("MATCHED: %s"):format(spirit.name)
			matchBanner.TextColor3 = Theme.Gold
		else
			matchBanner.Text = "no match yet…"
			matchBanner.TextColor3 = Theme.Muted
		end
	end
end

local function refreshTray()
	local tray = trayFrame
	if not tray then
		return
	end
	for _, child in tray:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for _, glyphId in found do
		local button = glyphButton(tray, glyphId, 62, function()
			selectedGlyph = glyphId
			SoundKit.play("UiClick")
		end)
		local _ = button
	end
end

local function buildBook()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local g = Theme.screenGui("PorcelainLedger", 12)
	g.Enabled = false
	g.Parent = playerGui
	gui = g

	local b = Theme.panel(g, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 760, 0, 460),
		BackgroundTransparency = 0.03,
	})

	Theme.label(b, {
		Position = UDim2.new(0, 0, 0, 8),
		Size = UDim2.new(1, 0, 0, 34),
		Font = Theme.TitleFont,
		TextSize = 28,
		Text = "— The Spirit Ledger —",
	})

	local close = Theme.button(b, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.new(0, 40, 0, 34),
		TextSize = 20,
		Text = "✕",
	})
	close.Activated:Connect(closeBook)

	-- left page: spirits
	local left = Instance.new("ScrollingFrame")
	left.BackgroundTransparency = 1
	left.Position = UDim2.new(0, 14, 0, 50)
	left.Size = UDim2.new(0.5, -20, 1, -64)
	left.CanvasSize = UDim2.new(0, 0, 0, 0)
	left.AutomaticCanvasSize = Enum.AutomaticSize.Y
	left.ScrollBarThickness = 4
	left.Parent = b
	local leftLayout = Instance.new("UIListLayout")
	leftLayout.Padding = UDim.new(0, 8)
	leftLayout.Parent = left
	for _, spirit in Spirits.list do
		local entry = Instance.new("Frame")
		entry.BackgroundTransparency = 1
		entry.Size = UDim2.new(1, -8, 0, 88)
		entry.Parent = left
		Theme.label(entry, {
			Size = UDim2.new(1, 0, 0, 22),
			Font = Theme.TitleFont,
			TextSize = 21,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = spirit.name,
		})
		local codeRow = Instance.new("Frame")
		codeRow.BackgroundTransparency = 1
		codeRow.Position = UDim2.new(0, 0, 0, 24)
		codeRow.Size = UDim2.new(1, 0, 0, 34)
		codeRow.Parent = entry
		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.Padding = UDim.new(0, 8)
		rowLayout.Parent = codeRow
		for _, glyphId in spirit.code do
			local cell = Instance.new("Frame")
			cell.Size = UDim2.new(0, 32, 0, 32)
			cell.BackgroundColor3 = Theme.BgSoft
			cell.BorderSizePixel = 0
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = cell
			cell.Parent = codeRow
			local canvas = Instance.new("Frame")
			canvas.BackgroundTransparency = 1
			canvas.Size = UDim2.new(1, -6, 1, -6)
			canvas.Position = UDim2.new(0, 3, 0, 3)
			canvas.Parent = cell
			GlyphRender.render(glyphId, canvas)
		end
		Theme.label(entry, {
			Position = UDim2.new(0, 0, 0, 60),
			Size = UDim2.new(1, 0, 0, 26),
			TextSize = 13,
			TextColor3 = Theme.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = spirit.flavor,
		})
	end

	-- right page: slots + tray
	local right = Instance.new("Frame")
	right.BackgroundTransparency = 1
	right.Position = UDim2.new(0.5, 8, 0, 50)
	right.Size = UDim2.new(0.5, -22, 1, -64)
	right.Parent = b
	Theme.label(right, {
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 15,
		TextColor3 = Theme.Muted,
		Text = "Tap a found glyph, then tap a slot. Order matters.",
	})
	local slotRow = Instance.new("Frame")
	slotRow.BackgroundTransparency = 1
	slotRow.Position = UDim2.new(0, 0, 0, 30)
	slotRow.Size = UDim2.new(1, 0, 0, 92)
	slotRow.Parent = right
	local slotLayout = Instance.new("UIListLayout")
	slotLayout.FillDirection = Enum.FillDirection.Horizontal
	slotLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	slotLayout.Padding = UDim.new(0, 12)
	slotLayout.Parent = slotRow
	for i = 1, 3 do
		local slot = Instance.new("Frame")
		slot.Size = UDim2.new(0, 84, 0, 84)
		slot.BackgroundColor3 = Theme.BgSoft
		slot.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = slot
		local stroke = Instance.new("UIStroke")
		stroke.Color = Theme.Accent
		stroke.Transparency = 0.5
		stroke.Parent = slot
		slot.Parent = slotRow
		table.insert(slotFrames, slot)
		local button = Instance.new("TextButton")
		button.BackgroundTransparency = 1
		button.Size = UDim2.new(1, 0, 1, 0)
		button.Text = ""
		button.ZIndex = 5
		button.Parent = slot
		button.Activated:Connect(function()
			if selectedGlyph then
				Remotes.get(Remotes.Names.SlotGlyph):FireServer(i, selectedGlyph)
				selectedGlyph = nil
			elseif slots[i] then
				Remotes.get(Remotes.Names.SlotGlyph):FireServer(i, nil)
			end
		end)
	end

	matchBanner = Theme.label(right, {
		Position = UDim2.new(0, 0, 0, 128),
		Size = UDim2.new(1, 0, 0, 26),
		Font = Theme.TitleFont,
		TextSize = 22,
		Text = "no match yet…",
		TextColor3 = Theme.Muted,
	})

	Theme.label(right, {
		Position = UDim2.new(0, 0, 0, 160),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 14,
		TextColor3 = Theme.Muted,
		Text = "Found glyphs:",
	})
	local tray = Instance.new("Frame")
	tray.BackgroundTransparency = 1
	tray.Position = UDim2.new(0, 0, 0, 184)
	tray.Size = UDim2.new(1, 0, 1, -184)
	tray.Parent = right
	local trayLayout = Instance.new("UIGridLayout")
	trayLayout.CellSize = UDim2.new(0, 62, 0, 62)
	trayLayout.CellPadding = UDim2.new(0, 8, 0, 8)
	trayLayout.Parent = tray
	trayFrame = tray

	refreshSlots()
end

function LedgerUI.init()
	buildBook()

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		if player ~= Players.LocalPlayer then
			return
		end
		if prompt.ObjectText == "Spirit Ledger" then
			openBook()
		end
	end)

	Remotes.get(Remotes.Names.GlyphFound).OnClientEvent:Connect(function(_glyphId: any, data: any)
		if typeof(data) ~= "table" then
			return
		end
		if typeof(data.found) == "table" then
			found = data.found
		end
		if typeof(data.slots) == "table" then
			slots = {}
			for i = 1, 3 do
				local v = data.slots[i]
				slots[i] = if typeof(v) == "string" then v else nil
			end
		end
		refreshTray()
		refreshSlots()
	end)

	-- close the book automatically: end of run, AND the shift->shift transition (B5).
	Remotes.get(Remotes.Names.StateChanged).OnClientEvent:Connect(function(state: any)
		if state == "LobbyIdle" or state == "RunEnd" or state == "ShiftResult" or state == "ShiftIntro" then
			closeBook()
		end
	end)
end

local _ = Glyphs -- glyph defs consumed via GlyphRender

return LedgerUI
