--!strict
-- Lobby: head billboards (social proof), leaderboard board, ready pad polling, spawn toggling.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Util = require(Shared:WaitForChild("Util")) :: any
local Classes = require(Shared:WaitForChild("Defs"):WaitForChild("Classes")) :: any

local LobbyService = {}

local ctx: any

local function attachBillboard(player: Player, char: Model)
	local head = char:WaitForChild("Head", 10)
	if not (head and head:IsA("BasePart")) then
		return
	end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "StatsTag"
	billboard.Adornee = head
	billboard.Size = UDim2.new(0, 170, 0, 56)
	billboard.StudsOffset = Vector3.new(0, 2.4, 0)
	billboard.MaxDistance = Config.Lobby.BillboardMaxDistance
	billboard.AlwaysOnTop = false
	billboard.Parent = head
	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.fromRGB(235, 228, 210)
	nameLabel.TextStrokeTransparency = 0.5
	nameLabel.Text = player.DisplayName
	nameLabel.Parent = billboard
	local statsLabel = Instance.new("TextLabel")
	statsLabel.Name = "Stats"
	statsLabel.BackgroundTransparency = 1
	statsLabel.Position = UDim2.new(0, 0, 0.4, 0)
	statsLabel.Size = UDim2.new(1, 0, 0.6, 0)
	statsLabel.Font = Enum.Font.Garamond
	statsLabel.TextScaled = true
	statsLabel.TextColor3 = Color3.fromRGB(190, 170, 210)
	statsLabel.TextStrokeTransparency = 0.6
	statsLabel.Parent = billboard
	LobbyService.refreshBillboard(player)
end

function LobbyService.refreshBillboard(player: Player)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	local billboard = head and head:FindFirstChild("StatsTag")
	local label = billboard and billboard:FindFirstChild("Stats")
	if label and label:IsA("TextLabel") then
		local stats = ctx.services.DataService.getStats(player)
		-- Reference screenshots: "Top Shift: N" plus the equipped class name underneath, in place
		-- of a second numeric stat.
		local equippedId = ctx.services.ClassService.getEquippedId(player)
		local className = (Classes.byId[equippedId] and Classes.byId[equippedId].name) or "Apprentice"
		label.Text = ("Top Shift: %d\n%s"):format(stats.bestShift, className)
	end
end

-- Reference screenshots show TWO separate boards flanking the Shop, not one combined board:
-- "Highest Shift" (bestShift) and "Patients Treated" (dollsCleared). B1's facing fix is baked in
-- here too -- both boards sit at HUB Z=29.4 with no rotation, and every player position in the Plaza
-- is south of that (Z < 30.5, sealed by the guard wall in MapBuilder's Plaza segment), so the
-- readable SurfaceGui face must point toward -Z, which is Enum.NormalId.Front for an unrotated part.
local function buildBoard(board: BasePart, title: string, rows: { { name: string, value: number } })
	local existing = board:FindFirstChild("BoardGui")
	local gui: SurfaceGui
	if existing and existing:IsA("SurfaceGui") then
		gui = existing
	else
		gui = Instance.new("SurfaceGui")
		gui.Name = "BoardGui"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.Parent = board
		local layout = Instance.new("UIListLayout")
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Top
		layout.Padding = UDim.new(0, 4)
		layout.Parent = gui
	end
	for _, child in gui:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local function addRow(text: string, size: number, color: Color3)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(0.9, 0, 0, size + 6)
		label.Font = Enum.Font.Garamond
		label.TextSize = size
		label.TextColor3 = color
		label.Text = text
		label.Parent = gui
	end
	addRow(title, 36, Color3.fromRGB(226, 216, 196))
	for i = 1, math.min(#rows, 8) do
		addRow(("%d.  %s — %d"):format(i, rows[i].name, rows[i].value), 26, Color3.fromRGB(190, 170, 210))
	end
end

local function refreshLeaderboard()
	local shiftBoard = ctx.manifest.leaderboardBoard
	local patientsBoard = ctx.manifest.patientsBoard
	if not shiftBoard and not patientsBoard then
		return
	end
	local shiftRows: { { name: string, value: number } } = {}
	local dollRows: { { name: string, value: number } } = {}
	for _, player in Players:GetPlayers() do
		local stats = ctx.services.DataService.getStats(player)
		table.insert(shiftRows, { name = player.DisplayName, value = stats.bestShift })
		table.insert(dollRows, { name = player.DisplayName, value = stats.dollsCleared })
	end
	table.sort(shiftRows, function(a, b)
		return a.value > b.value
	end)
	table.sort(dollRows, function(a, b)
		return a.value > b.value
	end)
	if shiftBoard then
		buildBoard(shiftBoard, "HIGHEST SHIFT", shiftRows)
	end
	if patientsBoard then
		buildBoard(patientsBoard, "PATIENTS TREATED", dollRows)
	end
end

function LobbyService.init(context: any)
	ctx = context

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			task.defer(attachBillboard, player, char)
		end)
		task.defer(refreshLeaderboard)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(char)
			task.defer(attachBillboard, player, char)
		end)
		if player.Character then
			task.defer(attachBillboard, player, player.Character)
		end
	end
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshLeaderboard)
	end)

	ctx.services.DataService.onStatsChanged(function(player: Player)
		LobbyService.refreshBillboard(player)
		refreshLeaderboard()
	end)

	-- ready pad polling at 2 Hz
	task.spawn(function()
		while true do
			task.wait(0.5)
			local pad = ctx.manifest.readyPad
			if not pad then
				continue
			end
			local standing: { Player } = {}
			local parts = workspace:GetPartBoundsInBox(
				CFrame.new(pad.Position + Vector3.new(0, 3, 0)),
				Vector3.new(12, 7, 12)
			)
			local seen: { [Player]: boolean } = {}
			for _, part in parts do
				local char = part:FindFirstAncestorOfClass("Model")
				if char then
					local player = Players:GetPlayerFromCharacter(char)
					if player and not seen[player] then
						seen[player] = true
						table.insert(standing, player)
					end
				end
			end
			Util.safeCall("requestStart", function()
				ctx.services.ShiftManager.requestStart(standing)
			end)
		end
	end)
end

function LobbyService.setShiftSpawnActive(active: boolean)
	local manifest = ctx.manifest
	if manifest.workshopSpawn then
		manifest.workshopSpawn.Enabled = active
	end
	if manifest.lobbySpawn then
		manifest.lobbySpawn.Enabled = not active
	end
end

return LobbyService
