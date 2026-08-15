--!strict
-- The state machine. Owns states, participants, shift number, strikes, spirit, correctness, recap.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Util = require(Shared:WaitForChild("Util")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local Spirits = require(Shared:WaitForChild("Defs"):WaitForChild("Spirits")) :: any
local Glyphs = require(Shared:WaitForChild("Defs"):WaitForChild("Glyphs")) :: any
local DollNames = require(Shared:WaitForChild("Defs"):WaitForChild("DollNames")) :: any
local GlyphMatch = require(Shared:WaitForChild("Logic"):WaitForChild("GlyphMatch")) :: any
local Escalation = require(Shared:WaitForChild("Logic"):WaitForChild("Escalation")) :: any
local Draw = require(Shared:WaitForChild("Logic"):WaitForChild("Draw")) :: any

local ShiftManager = {}

local ctx: any
local state = "LobbyIdle"
local stateGen = 0 -- bumped on every transition; kills stale watchdogs/timers
local participants: { Player } = {}
local shiftNumber = 1
local strikes = 0
local spirit: any = nil
local shiftParams: any = nil
local runStats = { dollsCleared = 0, perfect = 0, strikesThisShift = 0 }
local countdownActive = false

local escalationCfg = {
	BaseDollCount = Config.Shift.BaseDollCount,
	SoloDollCap = Config.Shift.SoloDollCap,
	MaxDollCount = Config.Shift.MaxDollCount,
	DollCountShiftMilestones = Config.Shift.DollCountShiftMilestones,
	BaseFakeTellChance = Config.Tells.FakeTellChancePerWindow,
	BaseTellIntervalMin = Config.Tells.BaseIntervalSeconds.min,
	BaseTellIntervalMax = Config.Tells.BaseIntervalSeconds.max,
	GlyphsPerShift = Config.Glyphs.PerShift,
}

-- ---------- helpers ----------

local function currentObjective(): string
	if state == "LobbyIdle" then
		return "Stand on the glowing pad to start the night shift."
	elseif state == "ShiftIntro" then
		return "The dolls are arriving…"
	elseif state ~= "ShiftActive" then
		return ""
	end
	local DollService = ctx.services.DollService
	local GlyphService = ctx.services.GlyphService
	local remaining = 0
	for _, id in DollService.getDollIds() do
		if DollService.nextStepFor(id) ~= nil then
			remaining += 1
		end
	end
	if remaining > 0 then
		return ("Care for the dolls — %d still need%s work."):format(remaining, if remaining == 1 then "s" else "")
	end
	local found = #GlyphService.getFound()
	local total = if spirit then #spirit.code else 3
	if found < total then
		return ("Find the glyphs — %d of %d found."):format(found, total)
	end
	local slots = GlyphService.getSlots()
	if not (spirit and GlyphMatch.matches(spirit.code, slots)) then
		return "Match the spirit in the ledger."
	end
	return "Bring the WRONG doll to the Banish Box."
end

local function broadcastState()
	Remotes.get(Remotes.Names.StateChanged):FireAllClients(state, {
		shift = shiftNumber,
		strikes = strikes,
		objective = currentObjective(),
	})
end

local function setDoorLocked(locked: boolean)
	local door = ctx.manifest.workshopDoor
	local slab = door and door:FindFirstChild("Slab")
	if slab and slab:IsA("BasePart") then
		slab.CanCollide = locked
		slab.Transparency = if locked then 0 else 0.85
	end
	local sign = ctx.manifest.workshopDoorSign
	local gui = sign and sign:FindFirstChildOfClass("SurfaceGui")
	local label = gui and gui:FindFirstChildOfClass("TextLabel")
	if label then
		label.Text = if locked then ("Shift %d in progress…"):format(shiftNumber) else "The workshop is open."
	end
end

local function teleportTo(spawnPart: BasePart?, players: { Player })
	if not spawnPart then
		return
	end
	for i, player in players do
		local char = player.Character
		if char then
			local angle = (i - 1) * (math.pi * 2 / math.max(#players, 1))
			char:PivotTo(spawnPart.CFrame * CFrame.new(math.cos(angle) * 3, 3, math.sin(angle) * 3))
		end
	end
end

local function pruneParticipants()
	for i = #participants, 1, -1 do
		if participants[i].Parent == nil then
			table.remove(participants, i)
		end
	end
end

local transition -- forward decl

local function armWatchdog(forState: string, gen: number)
	local seconds = Config.Shift.Watchdog[forState]
	if not seconds then
		return
	end
	task.delay(seconds, function()
		if state == forState and stateGen == gen then
			Util.warn(("WATCHDOG: state '%s' exceeded %ds — forcing transition"):format(forState, seconds))
			Remotes.get(Remotes.Names.Toast):FireAllClients(("watchdog: forcing past %s"):format(forState), 4)
			if forState == "ShiftIntro" then
				transition("ShiftActive")
			elseif forState == "ShiftActive" then
				transition("RunEnd")
			elseif forState == "ShiftResult" then
				transition("ShiftIntro")
			elseif forState == "RunEnd" then
				transition("LobbyIdle")
			end
		end
	end)
end

local function stopShiftSystems()
	Util.safeCall("stopTells", ctx.services.TellService.stopShift)
	Util.safeCall("stopHaunts", ctx.services.HauntService.stopShift)
	Util.safeCall("stopPresence", ctx.services.PresenceService.stop)
end

local function cleanupRun()
	stopShiftSystems()
	Util.safeCall("banishReset", ctx.services.BanishService.reset)
	Util.safeCall("clearDolls", ctx.services.DollService.clearShift)
	Util.safeCall("stopGlyphs", ctx.services.GlyphService.stopShift)
	Util.safeCall("spawnToggle", function()
		ctx.services.LobbyService.setShiftSpawnActive(false)
	end)
end

-- ---------- states ----------

transition = function(newState: string)
	stateGen += 1
	local gen = stateGen
	state = newState
	broadcastState()
	armWatchdog(newState, gen)

	if newState == "LobbyIdle" then
		shiftNumber = 1
		strikes = 0
		spirit = nil
		runStats = { dollsCleared = 0, perfect = 0, strikesThisShift = 0 }
		participants = {}
		setDoorLocked(false)
		cleanupRun()
	elseif newState == "ShiftIntro" then
		pruneParticipants()
		if #participants == 0 then
			transition("LobbyIdle")
			return
		end
		setDoorLocked(true)
		Util.safeCall("spawnToggle", function()
			ctx.services.LobbyService.setShiftSpawnActive(true)
		end)
		runStats.strikesThisShift = 0
		spirit = Draw.one(ctx.rng, Spirits.list)
		shiftParams = Escalation.forShift(escalationCfg, shiftNumber, #participants)
		local names = Draw.sample(ctx.rng, DollNames, shiftParams.dollCount)
		local markedIndex = ctx.rng:NextInteger(1, shiftParams.dollCount)
		local dollInfos = ctx.services.DollService.spawnShift(shiftParams, names, markedIndex, ctx.rng)
		ctx.services.GlyphService.startShift(spirit.code, ctx.rng)
		teleportTo(ctx.manifest.workshopSpawn, participants)
		Remotes.get(Remotes.Names.ShiftData):FireAllClients({
			shift = shiftNumber,
			dolls = dollInfos,
			glyphTotal = #spirit.code,
		})
		task.delay(Config.Shift.IntroSeconds, function()
			if state == "ShiftIntro" and stateGen == gen then
				transition("ShiftActive")
			end
		end)
	elseif newState == "ShiftActive" then
		ctx.services.PresenceService.startShift(shiftParams.presenceRateMultiplier)
		ctx.services.TellService.startShift(shiftParams, ctx.rng)
		ctx.services.HauntService.startShift(ctx.rng)
	elseif newState == "ShiftResult" then
		stopShiftSystems()
		task.delay(Config.Shift.ResultSeconds, function()
			if state == "ShiftResult" and stateGen == gen then
				-- merge lobby players standing on the pad into the next shift (plan review: joiner topology)
				transition("ShiftIntro")
			end
		end)
	elseif newState == "RunEnd" then
		stopShiftSystems()
		-- THE scare
		Remotes.get(Remotes.Names.HauntFired):FireAllClients("DollmakerReveal", {})
		for _, lamp in ctx.manifest.lamps do
			local light = lamp:FindFirstChildOfClass("PointLight")
			if light then
				light.Enabled = false
			end
		end
		local traitorId = ctx.services.DollService.getMarkedId()
		local traitorName = if traitorId then ctx.services.DollService.getDisplayName(traitorId) else "…someone"
		task.delay(4, function()
			if stateGen ~= gen then
				return
			end
			for _, lamp in ctx.manifest.lamps do
				local light = lamp:FindFirstChildOfClass("PointLight")
				if light then
					light.Enabled = true
				end
			end
			pruneParticipants()
			for _, player in participants do
				local stats = ctx.services.DataService.getStats(player)
				local isNewBest = shiftNumber - 1 > 0 and shiftNumber - 1 > stats.bestShift
				ctx.services.DataService.recordRun(player, {
					shiftReached = shiftNumber - 1,
					dollsCleared = runStats.dollsCleared,
					perfect = runStats.perfect,
				})
				Remotes.get(Remotes.Names.Recap):FireClient(player, {
					shiftReached = shiftNumber - 1,
					dollsCleared = runStats.dollsCleared,
					perfect = runStats.perfect > 0 and strikes == 0,
					traitorName = traitorName,
					bestShift = math.max(stats.bestShift, shiftNumber - 1),
					isNewBest = isNewBest,
				})
			end
			cleanupRun()
			teleportTo(ctx.manifest.lobbySpawn, participants)
			transition("LobbyIdle")
		end)
	end
end

-- ---------- public API ----------

function ShiftManager.init(context: any)
	ctx = context

	ctx.services.HauntService.setParticipantsGetter(function()
		pruneParticipants()
		return table.clone(participants)
	end)

	ctx.services.DollService.onStepCompleted(function(_player: Player, _dollId: string, _stepId: string)
		ctx.services.PresenceService.notifyStepCompleted()
		if state == "ShiftActive" and ctx.services.DollService.allListedCareDone() then
			ctx.services.PresenceService.setAllDollsDone(true)
			ctx.services.BanishService.setUnlocked(true)
		end
		broadcastState()
	end)

	ctx.services.PresenceService.onMaxed(function()
		if state == "ShiftActive" then
			transition("RunEnd")
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local idx = table.find(participants, player)
		if idx then
			table.remove(participants, idx)
		end
		if #participants == 0 and (state == "ShiftIntro" or state == "ShiftActive" or state == "ShiftResult") then
			transition("LobbyIdle")
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		-- late joiners get current state so their HUD isn't blank
		task.delay(3, function()
			if player.Parent then
				Remotes.get(Remotes.Names.StateChanged):FireClient(player, state, {
					shift = shiftNumber,
					strikes = strikes,
					objective = currentObjective(),
				})
			end
		end)
	end)

	broadcastState()
	setDoorLocked(false)
end

function ShiftManager.requestStart(standing: { Player })
	if state ~= "LobbyIdle" then
		return
	end
	if #standing == 0 then
		if countdownActive then
			countdownActive = false
			Remotes.get(Remotes.Names.ReadyCountdown):FireAllClients(nil)
		end
		return
	end
	participants = table.clone(standing)
	if countdownActive then
		return
	end
	countdownActive = true
	task.spawn(function()
		for remaining = Config.Lobby.ReadyCountdownSeconds, 1, -1 do
			if not countdownActive or state ~= "LobbyIdle" then
				return
			end
			pruneParticipants()
			if #participants == 0 then
				countdownActive = false
				Remotes.get(Remotes.Names.ReadyCountdown):FireAllClients(nil)
				return
			end
			Remotes.get(Remotes.Names.ReadyCountdown):FireAllClients(remaining)
			task.wait(1)
		end
		if countdownActive and state == "LobbyIdle" then
			countdownActive = false
			Remotes.get(Remotes.Names.ReadyCountdown):FireAllClients(nil)
			transition("ShiftIntro")
		end
	end)
end

function ShiftManager.onBanishResolved(dollId: string)
	if state ~= "ShiftActive" then
		return
	end
	local DollService = ctx.services.DollService
	local GlyphService = ctx.services.GlyphService
	local dollName = DollService.getDisplayName(dollId)
	local isMarked = DollService.isMarked(dollId)
	local slotsMatch = spirit ~= nil and GlyphMatch.matches(spirit.code, GlyphService.getSlots())
	local hasRibbon = DollService.hasRibbon(dollId)
	local correct = isMarked and slotsMatch and hasRibbon

	DollService.consume(dollId)

	if correct then
		Remotes.get(Remotes.Names.BanishResult):FireAllClients({
			correct = true,
			dollId = dollId,
			dollName = dollName,
			spiritName = spirit.name,
			strikes = strikes,
		})
		runStats.dollsCleared += shiftParams.dollCount
		if runStats.strikesThisShift == 0 then
			runStats.perfect += 1
		end
		shiftNumber += 1
		transition("ShiftResult")
	else
		strikes += 1
		runStats.strikesThisShift += 1
		ctx.services.PresenceService.surge(Config.Presence.WrongBanishSurge)
		Remotes.get(Remotes.Names.BanishResult):FireAllClients({
			correct = false,
			dollId = dollId,
			dollName = dollName,
			strikes = strikes,
		})
		if strikes >= Config.Shift.StrikeLimit then
			transition("RunEnd")
		else
			-- the box relocks? No: care is still done; allow retry. Re-enable deposit.
			ctx.services.BanishService.setUnlocked(true)
			broadcastState()
		end
	end
end

function ShiftManager.getParticipants(): { Player }
	pruneParticipants()
	return table.clone(participants)
end

function ShiftManager.getState(): string
	return state
end

function ShiftManager.getShiftNumber(): number
	return shiftNumber
end

function ShiftManager.getSpirit(): any
	return spirit
end

-- ---------- debug hooks (R7) ----------

function ShiftManager.debugForceState()
	if state == "LobbyIdle" then
		local players = Players:GetPlayers()
		participants = table.clone(players)
		transition("ShiftIntro")
	elseif state == "ShiftIntro" then
		transition("ShiftActive")
	elseif state == "ShiftActive" then
		transition("ShiftResult")
	elseif state == "ShiftResult" then
		transition("ShiftIntro")
	elseif state == "RunEnd" then
		transition("LobbyIdle")
	end
end

function ShiftManager.debugSetShift(n: number)
	shiftNumber = math.clamp(math.floor(n), 1, 99)
	broadcastState()
end

function ShiftManager.debugReveal(): (string?, any)
	local markedId = ctx.services.DollService.getMarkedId()
	local markedName = if markedId then ctx.services.DollService.getDisplayName(markedId) else nil
	local code = nil
	if spirit then
		local names = {}
		for _, glyphId in spirit.code do
			table.insert(names, Glyphs.byId[glyphId].name)
		end
		code = { name = spirit.name, code = table.concat(names, " → ") }
	end
	return markedName, code
end

function ShiftManager.debugStrike(delta: number)
	strikes = math.max(0, strikes + delta)
	broadcastState()
end

function ShiftManager.debugEndRun()
	if state == "ShiftActive" or state == "ShiftIntro" then
		transition("RunEnd")
	end
end

local _ = TweenService -- reserved for staged beats; keep import future-proof

return ShiftManager
