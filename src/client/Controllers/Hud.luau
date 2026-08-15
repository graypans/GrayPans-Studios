--!strict
-- HUD: shift banner, objective, strikes, doll checklist (5 listed steps only), countdown, version stamp.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local CareSteps = require(Shared:WaitForChild("Defs"):WaitForChild("CareSteps")) :: any
local Theme = require(script.Parent.Parent:WaitForChild("Theme")) :: any

local Hud = {}

local shiftLabel: TextLabel? = nil
local objectiveLabel: TextLabel? = nil
local strikePips: { Frame } = {}
local dollList: Frame? = nil
local countdownLabel: TextLabel? = nil
local dollRows: { [string]: { row: Frame, ticks: { Frame }, nameLabel: TextLabel } } = {}

local function build()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Theme.screenGui("PorcelainHud", 5)
	gui.Parent = playerGui

	-- top center: shift + objective
	local top = Instance.new("Frame")
	top.BackgroundTransparency = 1
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, 12)
	top.Size = UDim2.new(0.6, 0, 0, 100)
	top.Parent = gui
	shiftLabel = Theme.label(top, {
		Size = UDim2.new(1, 0, 0, 52),
		Font = Theme.TitleFont,
		TextSize = 46,
		Text = "",
		TextStrokeTransparency = 0.5,
	})
	objectiveLabel = Theme.label(top, {
		Position = UDim2.new(0, 0, 0, 52),
		Size = UDim2.new(1, 0, 0, 30),
		Font = Theme.BodyFont,
		TextSize = 18,
		TextColor3 = Theme.Muted,
		Text = "",
		TextStrokeTransparency = 0.6,
	})

	-- strikes under objective
	local strikeRow = Instance.new("Frame")
	strikeRow.BackgroundTransparency = 1
	strikeRow.AnchorPoint = Vector2.new(0.5, 0)
	strikeRow.Position = UDim2.new(0.5, 0, 0, 86)
	strikeRow.Size = UDim2.new(0, 120, 0, 18)
	strikeRow.Parent = top
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = strikeRow
	for _ = 1, Config.Shift.StrikeLimit do
		local pip = Instance.new("Frame")
		pip.Size = UDim2.new(0, 14, 0, 14)
		pip.BackgroundColor3 = Theme.BgSoft
		pip.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = pip
		local stroke = Instance.new("UIStroke")
		stroke.Color = Theme.Danger
		stroke.Transparency = 0.4
		stroke.Parent = pip
		pip.Parent = strikeRow
		table.insert(strikePips, pip)
	end

	-- right side: doll checklist
	dollList = Theme.panel(gui, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 210, 0, 10),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.35,
		Visible = false,
	})
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.Parent = dollList
	local listPad = Instance.new("UIPadding")
	listPad.PaddingTop = UDim.new(0, 8)
	listPad.PaddingBottom = UDim.new(0, 8)
	listPad.PaddingLeft = UDim.new(0, 8)
	listPad.PaddingRight = UDim.new(0, 8)
	listPad.Parent = dollList

	-- lobby countdown overlay
	countdownLabel = Theme.label(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 130),
		Size = UDim2.new(0, 400, 0, 60),
		Font = Theme.TitleFont,
		TextSize = 40,
		TextColor3 = Theme.Accent,
		Text = "",
		TextStrokeTransparency = 0.4,
	})

	-- version stamp
	Theme.label(gui, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -6),
		Size = UDim2.new(0, 300, 0, 16),
		Font = Enum.Font.Code,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.Muted,
		TextTransparency = 0.4,
		Text = ("%s %s"):format(Config.Version, Config.BuildStamp),
	})
end

local function addDollRow(dollId: string, name: string)
	local list = dollList
	if not list then
		return
	end
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 40)
	row.Parent = list
	local nameLabel = Theme.label(row, {
		Size = UDim2.new(1, 0, 0, 20),
		Font = Theme.TitleFont,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = name,
	})
	local ticksRow = Instance.new("Frame")
	ticksRow.BackgroundTransparency = 1
	ticksRow.Position = UDim2.new(0, 0, 0, 22)
	ticksRow.Size = UDim2.new(1, 0, 0, 14)
	ticksRow.Parent = row
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.Parent = ticksRow
	local ticks = {}
	for _ in CareSteps.list do
		local tick = Instance.new("Frame")
		tick.Size = UDim2.new(0, 22, 0, 10)
		tick.BackgroundColor3 = Theme.BgSoft
		tick.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 3)
		corner.Parent = tick
		tick.Parent = ticksRow
		table.insert(ticks, tick)
	end
	dollRows[dollId] = { row = row, ticks = ticks, nameLabel = nameLabel }
end

function Hud.init()
	build()

	Remotes.get(Remotes.Names.StateChanged).OnClientEvent:Connect(function(state: any, data: any)
		if typeof(data) ~= "table" then
			return
		end
		if shiftLabel then
			shiftLabel.Text = if state == "LobbyIdle" then "THE DOLLMAKER'S" else ("SHIFT %d"):format(data.shift or 1)
		end
		if objectiveLabel then
			objectiveLabel.Text = data.objective or ""
		end
		for i, pip in strikePips do
			pip.BackgroundColor3 = if i <= (data.strikes or 0) then Theme.Danger else Theme.BgSoft
		end
		if dollList and (state == "LobbyIdle" or state == "RunEnd") then
			dollList.Visible = false
			for _, entry in dollRows do
				entry.row:Destroy()
			end
			dollRows = {}
		end
	end)

	Remotes.get(Remotes.Names.ShiftData).OnClientEvent:Connect(function(data: any)
		if typeof(data) ~= "table" or typeof(data.dolls) ~= "table" then
			return
		end
		for _, entry in dollRows do
			entry.row:Destroy()
		end
		dollRows = {}
		if dollList then
			dollList.Visible = true
		end
		for _, doll in data.dolls do
			addDollRow(doll.id, doll.name)
		end
	end)

	Remotes.get(Remotes.Names.DollUpdate).OnClientEvent:Connect(function(dollId: any, update: any)
		local entry = dollRows[dollId]
		if not entry or typeof(update) ~= "table" then
			return
		end
		if typeof(update.name) == "string" then
			entry.nameLabel.Text = update.name
		end
		if typeof(update.careDone) == "table" then
			local doneSet: { [string]: boolean } = {}
			for _, stepId in update.careDone do
				doneSet[stepId] = true
			end
			for i, step in CareSteps.list do
				if doneSet[step.id] and entry.ticks[i] then
					entry.ticks[i].BackgroundColor3 = Theme.Gold
				end
			end
		end
		if update.done == true then
			entry.nameLabel.TextColor3 = Theme.Gold
		end
	end)

	Remotes.get(Remotes.Names.ReadyCountdown).OnClientEvent:Connect(function(seconds: any)
		if countdownLabel then
			countdownLabel.Text = if typeof(seconds) == "number" then ("The shift begins in %d…"):format(seconds) else ""
		end
	end)
end

return Hud
