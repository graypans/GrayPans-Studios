--!strict
-- JoinSquareService: lobby floor-tile "join squares" (Animal-Hospital-style party assembly).
-- Each tagged part fills with 1..MaxGroupSize players, runs a countdown once the first player
-- steps on, then hands the group off to a shift -- either a fresh private reserved server (live)
-- or the existing in-place ShiftIntro flow (Studio / Config.Features.PrivateShiftServers=false).
-- Also owns the RECEIVING side of that handoff: in a live reserved shift server (no lobby, no
-- squares exist there) it waits for the expected arrivals and starts the shift the same way.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Util = require(Shared:WaitForChild("Util")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local ServerKind = require(Shared:WaitForChild("ServerKind")) :: any

local JOIN_SQUARE_TAG = "JoinSquare"

local JoinSquareService = {}

local ctx: any

type Phase = "Idle" | "Waiting" | "Locking"

type SquareState = {
	id: string,
	part: BasePart,
	occupants: { Player },
	phase: Phase,
	countdownGen: number,
	countdownActive: boolean,
}

local squares: { [BasePart]: SquareState } = {}

-- ---------- visuals ----------

local function colorFor(phase: Phase): Color3
	if phase == "Idle" then
		return Config.JoinSquares.IdleColor
	elseif phase == "Waiting" then
		return Config.JoinSquares.OccupiedColor
	else
		return Config.JoinSquares.LockingColor
	end
end

local function ensureLabel(square: SquareState): TextLabel
	local part = square.part
	local billboard = part:FindFirstChild("JoinSquareGui")
	if not billboard then
		local b = Instance.new("BillboardGui")
		b.Name = "JoinSquareGui"
		b.Adornee = part
		b.Size = UDim2.new(0, 160, 0, 60)
		b.StudsOffset = Vector3.new(0, 4, 0)
		b.MaxDistance = Config.JoinSquares.BillboardMaxDistance
		b.AlwaysOnTop = true
		b.Parent = part
		local label = Instance.new("TextLabel")
		label.Name = "Count"
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 1, 0)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(235, 228, 210)
		label.TextStrokeTransparency = 0.3
		label.Parent = b
		billboard = b
	end
	return (billboard :: BillboardGui):FindFirstChild("Count") :: TextLabel
end

local function refreshVisual(square: SquareState)
	square.part.Color = colorFor(square.phase)
	local label = ensureLabel(square)
	label.Text = ("%d/%d"):format(#square.occupants, Config.JoinSquares.MaxGroupSize)
end

-- ---------- broadcasts ----------

local function broadcastOccupancy(square: SquareState)
	local ids: { number } = {}
	for _, plr in square.occupants do
		table.insert(ids, plr.UserId)
	end
	Remotes.get(Remotes.Names.JoinSquareUpdate):FireAllClients(square.id, {
		count = #square.occupants,
		max = Config.JoinSquares.MaxGroupSize,
		occupantUserIds = ids,
		phase = square.phase,
	})
end

local function cancelCountdown(square: SquareState)
	local wasActive = square.countdownActive
	square.countdownActive = false
	square.countdownGen += 1 -- invalidates any in-flight countdown loop (see startCountdown)
	if wasActive then
		Remotes.get(Remotes.Names.JoinSquareCountdown):FireAllClients(square.id, nil)
	end
end

local function resetSquare(square: SquareState)
	square.occupants = {}
	square.phase = "Idle"
	cancelCountdown(square)
	broadcastOccupancy(square)
	refreshVisual(square)
end

-- ---------- resolve: Start Now, countdown hits zero, or auto-full ----------

local function resolveSquare(square: SquareState)
	if #square.occupants == 0 then
		return
	end
	cancelCountdown(square)
	square.phase = "Locking"
	broadcastOccupancy(square)
	refreshVisual(square)

	local occupants = table.clone(square.occupants)

	local function revertToWaiting(message: string)
		for _, plr in occupants do
			if plr.Parent then
				Remotes.get(Remotes.Names.Toast):FireClient(plr, message, 4)
			end
		end
		square.phase = "Waiting"
		broadcastOccupancy(square)
		refreshVisual(square)
	end

	if ServerKind.isSameServerMode() then
		-- Studio, or the live emergency kill switch: reuse ShiftManager's existing flow in-place.
		local ok = Util.safeCall("joinSquareBeginInPlace:" .. square.id, function()
			local started = ctx.services.ShiftManager.beginShiftFor(occupants)
			if not started then
				error("beginShiftFor declined -- ShiftManager state was not LobbyIdle")
			end
		end)
		if ok then
			resetSquare(square)
		else
			revertToWaiting("A shift is already starting elsewhere -- try again in a moment.")
		end
		return
	end

	-- Live: real cross-server private teleport.
	local userIds: { number } = {}
	for _, plr in occupants do
		table.insert(userIds, plr.UserId)
	end
	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions.ShouldReserveServer = true
	teleportOptions:SetTeleportData({
		kind = "Shift",
		squareId = square.id,
		expectedUserIds = userIds,
	})
	local ok = Util.safeCall("joinSquareTeleport:" .. square.id, function()
		TeleportService:TeleportAsync(game.PlaceId, occupants, teleportOptions)
	end)
	if ok then
		-- Occupants are leaving this server. Reset now rather than waiting for the next poll tick
		-- / PlayerRemoving to notice, so the tile doesn't sit "full" for stragglers mid-loading-screen.
		resetSquare(square)
	else
		revertToWaiting("Couldn't start the shift -- try again.")
	end
end

-- ---------- countdown ----------

local function startCountdown(square: SquareState)
	if square.countdownActive then
		return
	end
	square.countdownActive = true
	square.countdownGen += 1
	local gen = square.countdownGen
	task.spawn(function()
		for remaining = Config.JoinSquares.CountdownSeconds, 1, -1 do
			if square.countdownGen ~= gen then
				return -- cancelled (square emptied) or resolved (Start Now / auto-full) elsewhere
			end
			Remotes.get(Remotes.Names.JoinSquareCountdown):FireAllClients(square.id, remaining)
			task.wait(1)
		end
		if square.countdownGen == gen then
			resolveSquare(square)
		end
	end)
end

-- ---------- occupancy polling (LobbyService's ready-pad idiom, generalized to N squares) ----------

local function standingOn(part: BasePart): { Player }
	local size = Vector3.new(part.Size.X, Config.JoinSquares.DetectHeightPadding, part.Size.Z)
	local center = part.Position + Vector3.new(0, size.Y / 2, 0)
	local hits = workspace:GetPartBoundsInBox(CFrame.new(center), size)
	local seen: { [Player]: boolean } = {}
	local standing: { Player } = {}
	for _, hit in hits do
		local char = hit:FindFirstAncestorOfClass("Model")
		if char then
			local player = Players:GetPlayerFromCharacter(char)
			if player and not seen[player] then
				seen[player] = true
				table.insert(standing, player)
			end
		end
	end
	return standing
end

local function sameOccupants(a: { Player }, b: { Player }): boolean
	if #a ~= #b then
		return false
	end
	for i, plr in a do
		if b[i] ~= plr then
			return false
		end
	end
	return true
end

local function refreshSquare(square: SquareState)
	local newOccupants = standingOn(square.part)
	local wasEmpty = #square.occupants == 0
	local nowEmpty = #newOccupants == 0
	local changed = not sameOccupants(square.occupants, newOccupants)

	square.occupants = newOccupants

	if wasEmpty and not nowEmpty then
		square.phase = "Waiting"
		startCountdown(square) -- starts ONLY on first entrant into an empty square, per spec
	elseif not wasEmpty and nowEmpty then
		resetSquare(square) -- last occupant left (Exit button OR walked off) -- full reset
		return
	end

	if changed then
		broadcastOccupancy(square)
		refreshVisual(square)
	end

	if not nowEmpty
		and Config.JoinSquares.AutoStartOnFull
		and square.countdownActive
		and #square.occupants >= Config.JoinSquares.MaxGroupSize
	then
		resolveSquare(square)
	end
end

local function pollLoop()
	while true do
		task.wait(Config.JoinSquares.PollIntervalSeconds)
		for _, square in squares do
			Util.safeCall("joinSquarePoll:" .. square.id, refreshSquare, square)
		end
	end
end

-- ---------- square lifecycle ----------

local function registerSquare(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	if squares[inst] then
		return
	end
	local id = if inst.Name ~= "" then inst.Name else inst:GetDebugId()
	local square: SquareState = {
		id = id,
		part = inst,
		occupants = {},
		phase = "Idle",
		countdownGen = 0,
		countdownActive = false,
	}
	squares[inst] = square
	refreshVisual(square)
end

local function unregisterSquare(inst: Instance)
	local square = squares[inst :: BasePart]
	if square then
		cancelCountdown(square)
		squares[inst :: BasePart] = nil
	end
end

local function findSquareById(id: string): SquareState?
	for _, square in squares do
		if square.id == id then
			return square
		end
	end
	return nil
end

local function handleExit(player: Player, square: SquareState)
	local idx = table.find(square.occupants, player)
	if not idx then
		return
	end
	table.remove(square.occupants, idx)
	if #square.occupants == 0 then
		resetSquare(square)
	else
		broadcastOccupancy(square)
		refreshVisual(square)
	end
end

local function onJoinSquareAction(player: Player, squareId: any, action: any)
	if typeof(squareId) ~= "string" or typeof(action) ~= "string" then
		return
	end
	local square = findSquareById(squareId)
	if not square then
		return
	end
	if not table.find(square.occupants, player) then
		return -- server-authoritative: reject actions from players not actually standing here
	end
	if action == "Exit" then
		handleExit(player, square)
	elseif action == "StartNow" then
		resolveSquare(square)
	elseif action == "SkipTutorial" then
		Util.safeCall("joinSquareSkipTutorial", function()
			-- TODO(integration): see PACKET_1_LOBBY_SYSTEMS.md "READ THIS FIRST" §5 -- there is no
			-- TutorialService in this packet; the Social track's tutorial-gate design deliberately
			-- has no separate skippable flow. Resolve per the team's decision there before wiring
			-- this to a real function.
			if ctx.services.TutorialService and ctx.services.TutorialService.setSkipped then
				ctx.services.TutorialService.setSkipped(player)
			end
		end)
	end
end

-- ---------- receiving side: bootstrap a fresh reserved shift server ----------

local function bootstrapReservedServer()
	local expectedUserIds: { number }? = nil
	local started = false

	local function tryStart()
		if started or expectedUserIds == nil then
			return
		end
		local current = Players:GetPlayers()
		if #current >= #(expectedUserIds :: { number }) then
			started = true
			Util.safeCall("joinSquareBootstrapBegin", function()
				ctx.services.ShiftManager.beginShiftFor(current)
			end)
		end
	end

	local function captureTeleportData(player: Player)
		if expectedUserIds ~= nil then
			return
		end
		local ok, joinData = pcall(function()
			return player:GetJoinData()
		end)
		local data = (ok and joinData and joinData.TeleportData) :: any
		if typeof(data) == "table" and typeof(data.expectedUserIds) == "table" then
			expectedUserIds = data.expectedUserIds :: { number }
			-- R2 watchdog: start with whoever actually made it, even if the group arrives short.
			task.delay(Config.JoinSquares.ArrivalWatchdogSeconds, tryStart)
		end
	end

	for _, player in Players:GetPlayers() do
		captureTeleportData(player)
	end
	Players.PlayerAdded:Connect(function(player)
		captureTeleportData(player)
		task.defer(tryStart)
	end)
	task.defer(tryStart)
end

-- ---------- public API ----------

function JoinSquareService.init(context: any)
	ctx = context
	if not Config.Features.JoinSquares then
		return
	end

	if ServerKind.isReservedShiftServer() then
		bootstrapReservedServer()
		return -- no JoinSquare-tagged parts exist in a workshop-only server; nothing else to do
	end

	for _, inst in CollectionService:GetTagged(JOIN_SQUARE_TAG) do
		registerSquare(inst)
	end
	CollectionService:GetInstanceAddedSignal(JOIN_SQUARE_TAG):Connect(registerSquare)
	CollectionService:GetInstanceRemovedSignal(JOIN_SQUARE_TAG):Connect(unregisterSquare)

	Players.PlayerRemoving:Connect(function(player)
		for _, square in squares do
			if table.find(square.occupants, player) then
				handleExit(player, square)
			end
		end
	end)

	Remotes.get(Remotes.Names.JoinSquareAction).OnServerEvent:Connect(onJoinSquareAction)

	task.spawn(pollLoop)
end

-- Called by ShiftManager's RunEnd branch when a live reserved shift server's run ends, to hand
-- the group back to the public lobby. No-op in same-server mode -- ShiftManager's own existing
-- in-place teleport-to-lobbySpawn already covers that case.
function JoinSquareService.sendGroupHome(players: { Player })
	if #players == 0 or ServerKind.isSameServerMode() then
		return
	end
	local ok = Util.safeCall("joinSquareSendHome", function()
		TeleportService:TeleportAsync(game.PlaceId, players)
	end)
	if not ok then
		for _, plr in players do
			if plr.Parent then
				Remotes.get(Remotes.Names.Toast):FireClient(
					plr,
					"Couldn't return to the lobby automatically -- try rejoining.",
					6
				)
			end
		end
	end
end

return JoinSquareService
