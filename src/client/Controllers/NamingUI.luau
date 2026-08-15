--!strict
-- Doll naming: compact top-half picker, once per doll, on the local player's first completed step.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local DollNames = require(Shared:WaitForChild("Defs"):WaitForChild("DollNames")) :: any
local SoundKit = require(Shared:WaitForChild("SoundKit")) :: any
local Theme = require(script.Parent.Parent:WaitForChild("Theme")) :: any

local NamingUI = {}

local gui: ScreenGui? = nil
local panel: Frame? = nil
local offeredFor: { [string]: boolean } = {}
local currentDollId: string? = nil
local dollNames: { [string]: string } = {} -- dollId -> current display name, so the picker can exclude it (B10)

local function close()
	if panel then
		panel:Destroy()
		panel = nil
	end
	currentDollId = nil
end

local function offer(dollId: string)
	if panel then
		return
	end
	currentDollId = dollId
	local g = gui
	assert(g)
	local p = Theme.panel(g, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.new(0, 460, 0, 220),
		BackgroundTransparency = 0.06,
	})
	panel = p
	Theme.label(p, {
		Position = UDim2.new(0, 0, 0, 10),
		Size = UDim2.new(1, 0, 0, 28),
		Font = Theme.TitleFont,
		TextSize = 24,
		Text = "Name this doll?",
	})
	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.new(0, 14, 0, 46)
	grid.Size = UDim2.new(1, -28, 0, 118)
	grid.Parent = p
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.333, -8, 0, 52)
	layout.CellPadding = UDim2.new(0, 8, 0, 8)
	layout.Parent = grid

	local function fillNames()
		for _, child in grid:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		-- exclude the doll's own current/default name so tapping a choice always does something (B10)
		local currentName = dollNames[dollId]
		local picked: { [number]: boolean } = {}
		local pickedCount = 0
		local wanted = math.min(6, math.max(0, #DollNames - (if currentName then 1 else 0)))
		local attempts = 0
		local maxAttempts = #DollNames * 20 + 20 -- generous ceiling: a bad roll can never hang the UI (R2)
		while pickedCount < wanted and attempts < maxAttempts do
			attempts += 1
			local index = math.random(1, #DollNames)
			if not picked[index] and DollNames[index] ~= currentName then
				picked[index] = true
				pickedCount += 1
			end
		end
		for index in picked do
			local button = Theme.button(grid, {
				TextSize = 18,
				Text = DollNames[index],
			})
			button.Activated:Connect(function()
				local id = currentDollId
				if id then
					SoundKit.play("UiConfirm")
					Remotes.get(Remotes.Names.ChooseName):FireServer(id, index)
				end
				close()
			end)
		end
	end
	fillNames()

	local shuffle = Theme.button(p, {
		Position = UDim2.new(0, 14, 1, -46),
		Size = UDim2.new(0.5, -22, 0, 36),
		TextSize = 17,
		Text = "↻ other names",
	})
	shuffle.Activated:Connect(fillNames)
	local skip = Theme.button(p, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 1, -46),
		Size = UDim2.new(0.5, -22, 0, 36),
		TextSize = 17,
		Text = "keep current name",
	})
	skip.Activated:Connect(close)

	-- never block the loop: auto-dismiss (R2)
	task.delay(15, function()
		if currentDollId == dollId then
			close()
		end
	end)
end

function NamingUI.init()
	if not Config.Features.Naming then
		return
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local g = Theme.screenGui("PorcelainNaming", 11)
	g.Parent = playerGui
	gui = g

	-- track each doll's current name (default at spawn, then whatever ChooseName lands) so the
	-- picker can filter its own current name out of its option list (B10)
	Remotes.get(Remotes.Names.ShiftData).OnClientEvent:Connect(function(data: any)
		if typeof(data) ~= "table" or typeof(data.dolls) ~= "table" then
			return
		end
		for _, doll in data.dolls do
			if typeof(doll) == "table" and typeof(doll.id) == "string" and typeof(doll.name) == "string" then
				dollNames[doll.id] = doll.name
			end
		end
	end)

	-- offer naming when the local player finishes their first minigame on a doll:
	-- MinigameStart implies this player is working that doll; offer after the step completes (DollUpdate).
	local workingDoll: string? = nil
	Remotes.get(Remotes.Names.MinigameStart).OnClientEvent:Connect(function(dollId: any)
		if typeof(dollId) == "string" then
			workingDoll = dollId
		end
	end)
	Remotes.get(Remotes.Names.DollUpdate).OnClientEvent:Connect(function(dollId: any, update: any)
		if typeof(dollId) ~= "string" or typeof(update) ~= "table" then
			return
		end
		if typeof(update.name) == "string" then
			dollNames[dollId] = update.name
		end
		if update.careDone and dollId == workingDoll and not offeredFor[dollId] then
			offeredFor[dollId] = true
			offer(dollId)
		end
	end)
	Remotes.get(Remotes.Names.StateChanged).OnClientEvent:Connect(function(state: any)
		if state == "LobbyIdle" or state == "RunEnd" then
			offeredFor = {}
			dollNames = {}
			close()
		end
	end)
end

return NamingUI
