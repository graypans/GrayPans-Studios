--!strict
-- The Dollmaker's Journal: quest/checklist list with coin rewards. Opened via the left-side HUD
-- Nav bar firing ReplicatedStorage's "PorcelainOpenPanel" bindable with "Journal" (see
-- PACKET_1_LOBBY_SYSTEMS.md's integration notes), or directly via Journal.open()/.close()/.toggle()
-- (mirrors Toast's cross-controller export pattern, Toast.show).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local Quests = require(Shared:WaitForChild("Defs"):WaitForChild("Quests")) :: any
local QuestProgress = require(Shared:WaitForChild("Logic"):WaitForChild("QuestProgress")) :: any
local SoundKit = require(Shared:WaitForChild("SoundKit")) :: any
local Theme = require(script.Parent.Parent:WaitForChild("Theme")) :: any

local Journal = {}

local gui: ScreenGui? = nil
local listFrame: ScrollingFrame? = nil
local latestStats: any = nil
local previousClaimed: { [string]: boolean } = {}

local HIDDEN_TITLE = "???"
local HIDDEN_DESC = "Something in the workshop is waiting to be found."

local function fillBar(parent: Instance, fraction: number)
	local track = Instance.new("Frame")
	track.BackgroundColor3 = Theme.BgSoft
	track.BorderSizePixel = 0
	track.Size = UDim2.new(1, 0, 0, 14)
	track.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = track
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Theme.Gold
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 7)
	fillCorner.Parent = fill
end

local function buildCard(parent: Instance, quest: any, stats: any)
	local discovered = not quest.hidden or (stats.questFlags and stats.questFlags[quest.id] == true)
	local claimed = stats.claimedQuestIds and stats.claimedQuestIds[quest.id] == true
	local progress = QuestProgress.compute(stats, quest)
	local complete = progress >= quest.target

	local card = Theme.panel(parent, {
		Size = UDim2.new(1, -8, 0, 118),
		BackgroundTransparency = 0.15,
	})

	Theme.label(card, {
		Position = UDim2.new(0, 14, 0, 8),
		Size = UDim2.new(1, -28, 0, 24),
		Font = Theme.TitleFont,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = if discovered then quest.title else HIDDEN_TITLE,
	})

	Theme.label(card, {
		Position = UDim2.new(0, 14, 0, 32),
		Size = UDim2.new(1, -28, 0, 32),
		TextSize = 14,
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = if discovered then quest.description else HIDDEN_DESC,
	})

	local barHolder = Instance.new("Frame")
	barHolder.BackgroundTransparency = 1
	barHolder.Position = UDim2.new(0, 14, 0, 68)
	barHolder.Size = UDim2.new(1, -160, 0, 14)
	barHolder.Parent = card
	fillBar(barHolder, if quest.target > 0 then progress / quest.target else 0)

	Theme.label(card, {
		Position = UDim2.new(0, 14, 0, 86),
		Size = UDim2.new(1, -160, 0, 18),
		TextSize = 13,
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = if discovered
			then ("%d / %d  ·  +%d coins"):format(math.min(progress, quest.target), quest.target, quest.coinReward)
			else "? / ?",
	})

	local claimButton = Theme.button(card, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0, 120, 0, 64), -- mobile touch target (>=64px)
		TextSize = 16,
		Text = if claimed then "Claimed" elseif complete then "Claim" else "Locked",
	})
	claimButton.AutoButtonColor = complete and not claimed
	if claimed or not complete then
		claimButton.BackgroundColor3 = Theme.BgSoft
		claimButton.TextColor3 = Theme.Muted
	end
	claimButton.Activated:Connect(function()
		if claimed or not complete then
			return
		end
		SoundKit.play("UiClick")
		Remotes.get(Remotes.Names.ClaimQuest):FireServer(quest.id)
	end)
end

local function refreshList()
	local list = listFrame
	if not list or not latestStats then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for _, quest in Quests.list do
		buildCard(list, quest, latestStats)
	end

	-- celebration beat: diff claimed sets, flash+chime any id that just newly appeared
	local newlyClaimed = false
	for id in latestStats.claimedQuestIds do
		if not previousClaimed[id] then
			newlyClaimed = true
			break
		end
	end
	if newlyClaimed then
		SoundKit.play("UiConfirm")
		if gui then
			local flash = Instance.new("Frame")
			flash.BackgroundColor3 = Theme.Gold
			flash.BackgroundTransparency = 0.55
			flash.BorderSizePixel = 0
			flash.Size = UDim2.fromScale(1, 1)
			flash.ZIndex = 50
			flash.Parent = gui
			TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
			task.delay(0.65, function()
				flash:Destroy()
			end)
		end
	end
	previousClaimed = {}
	for id in latestStats.claimedQuestIds do
		previousClaimed[id] = true
	end
end

local function buildUI()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local g = Theme.screenGui("PorcelainJournal", 12)
	g.Enabled = false
	g.Parent = playerGui
	gui = g

	local backdrop = Instance.new("Frame")
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.4
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Parent = g

	local panel = Theme.panel(g, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 560, 0, 560),
		BackgroundTransparency = 0.03,
	})

	Theme.label(panel, {
		Position = UDim2.new(0, 0, 0, 10),
		Size = UDim2.new(1, 0, 0, 32),
		Font = Theme.TitleFont,
		TextSize = 26,
		Text = "— The Dollmaker's Journal —",
	})

	local close = Theme.button(panel, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.new(0, 40, 0, 34),
		TextSize = 20,
		Text = "✕",
	})
	close.Activated:Connect(function()
		Journal.close()
	end)

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.new(0, 14, 0, 52)
	list.Size = UDim2.new(1, -28, 1, -66)
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 6
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = list
	listFrame = list
end

function Journal.open()
	if gui then
		gui.Enabled = true
		SoundKit.play("UiClick")
	end
end

function Journal.close()
	if gui then
		gui.Enabled = false
	end
end

function Journal.toggle()
	if gui then
		if gui.Enabled then
			Journal.close()
		else
			Journal.open()
		end
	end
end

function Journal.init()
	buildUI()

	Remotes.get(Remotes.Names.PlayerStats).OnClientEvent:Connect(function(stats: any)
		if typeof(stats) ~= "table" then
			return
		end
		latestStats = stats
		refreshList()
	end)

	Remotes.get(Remotes.Names.StateChanged).OnClientEvent:Connect(function(state: any)
		if state ~= "LobbyIdle" and gui then
			gui.Enabled = false
		end
	end)

	-- panel-open interop: see PACKET_1_LOBBY_SYSTEMS.md "READ THIS FIRST" §3
	local openBindable: BindableEvent
	local existing = ReplicatedStorage:FindFirstChild("PorcelainOpenPanel")
	if existing and existing:IsA("BindableEvent") then
		openBindable = existing
	else
		openBindable = Instance.new("BindableEvent")
		openBindable.Name = "PorcelainOpenPanel"
		openBindable.Parent = ReplicatedStorage
	end
	openBindable.Event:Connect(function(panelName: string?)
		if panelName == "Journal" then
			Journal.open()
		end
	end)

	-- desktop convenience shortcut; mirrors PanicEmote's "+ E key on PC" precedent alongside its touch button
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.J then
			Journal.toggle()
		end
	end)
end

return Journal
