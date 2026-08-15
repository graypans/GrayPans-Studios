--!strict
-- Persistence per R5: probe once, memory fallback, UpdateAsync merge-only, never blocks gameplay.
--
-- Extended for the lobby/economy system: coins (sum-merge), owned classes + equipped class
-- (union-merge / last-write-wins), ribbon-tie counter (sum-merge), tutorialDone (a ONE-WAY flag --
-- OR-merge, not sum/max), and two claimed/discovered id sets (per-key OR/union-merge). R5 says
-- every merge is max() or sum() UNLESS explicitly flagged otherwise -- these new shapes are that
-- flagged exception. `dirty` replaces the old "did runs/bestShift change" flush gate so that a
-- session whose ONLY changes were coin/class/ribbon/tutorial/quest updates still gets flushed.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Util = require(Shared:WaitForChild("Util")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any

local DataService = {}

type Stats = {
	bestShift: number,
	dollsCleared: number,
	perfectShifts: number,
	runs: number,
	coins: number, -- sum-merge. Spendable balance; Shop/Economy purchases debit this via a negative addCoins() amount.
	ownedClasses: { [string]: boolean }, -- per-key OR/union-merge. Classes with price > 0 this player has bought.
	equippedClass: string, -- last-write-wins. "" / unrecognized / not-owned all fall back to the free starter class at read time (ClassService's job).
	ribbonsTiedTotal: number, -- sum-merge. Career ribbon-tie count (the "Silver Fingers" quest).
	tutorialDone: boolean, -- OR-merge (one-way -- once true, always true).
	claimedQuestIds: { [string]: boolean }, -- per-key OR/union-merge. Reward paid-out guard.
	questFlags: { [string]: boolean }, -- per-key OR/union-merge. Easter-egg discovery state.
	loaded: boolean,
}

local available = false
local store: any = nil
local cache: { [Player]: Stats } = {}
local sessionDelta: {
	[Player]: {
		dollsCleared: number,
		perfectShifts: number,
		runs: number,
		bestShift: number,
		coins: number, -- signed net delta (earn positive, spend negative) since last flush
		ribbonsTiedTotal: number,
		newlyOwnedClasses: { [string]: boolean }, -- classIds bought this session, not yet flushed
		equippedClassDirty: boolean,
		equippedClass: string,
	},
} = {}
local dirty: { [Player]: boolean } = {} -- true when cache has unflushed changes
local loadedCallbacks: { (Player, Stats) -> () } = {}

local function defaultStats(): Stats
	return {
		bestShift = 0,
		dollsCleared = 0,
		perfectShifts = 0,
		runs = 0,
		coins = 0,
		ownedClasses = {},
		equippedClass = "",
		ribbonsTiedTotal = 0,
		tutorialDone = false,
		claimedQuestIds = {},
		questFlags = {},
		loaded = false,
	}
end

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

local function loadPlayer(player: Player)
	cache[player] = defaultStats()
	sessionDelta[player] = {
		dollsCleared = 0,
		perfectShifts = 0,
		runs = 0,
		bestShift = 0,
		coins = 0,
		ribbonsTiedTotal = 0,
		newlyOwnedClasses = {},
		equippedClassDirty = false,
		equippedClass = "",
	}
	dirty[player] = false

	-- Best-effort immediate push + delayed resend for late-connecting client listeners (same
	-- pattern ShiftManager uses for late-joiner StateChanged) so the Shop/HUD have SOMETHING to
	-- show before the DataStore round-trip lands (R5: never block gameplay on persistence).
	Remotes.get(Remotes.Names.CoinsUpdate):FireClient(player, cache[player].coins)
	task.delay(3, function()
		if player.Parent and cache[player] then
			Remotes.get(Remotes.Names.CoinsUpdate):FireClient(player, cache[player].coins)
		end
	end)

	if not available then
		return
	end
	task.spawn(function()
		for attempt = 1, Config.Data.ReadRetries do
			local ok, result = pcall(function()
				return store:GetAsync(keyFor(player))
			end)
			if ok then
				local stats = cache[player]
				if stats and typeof(result) == "table" then
					stats.bestShift = tonumber(result.bestShift) or 0
					stats.dollsCleared = tonumber(result.dollsCleared) or 0
					stats.perfectShifts = tonumber(result.perfectShifts) or 0
					stats.runs = tonumber(result.runs) or 0
					stats.coins = tonumber(result.coins) or 0
					stats.ownedClasses = if typeof(result.ownedClasses) == "table" then result.ownedClasses else {}
					stats.equippedClass = if typeof(result.equippedClass) == "string" then result.equippedClass else ""
					stats.ribbonsTiedTotal = tonumber(result.ribbonsTiedTotal) or 0
					stats.tutorialDone = result.tutorialDone == true
					if typeof(result.claimedQuestIds) == "table" then
						for id, v in result.claimedQuestIds do
							if v and typeof(id) == "string" then
								stats.claimedQuestIds[id] = true
							end
						end
					end
					if typeof(result.questFlags) == "table" then
						for id, v in result.questFlags do
							if v and typeof(id) == "string" then
								stats.questFlags[id] = true
							end
						end
					end
				end
				if stats then
					stats.loaded = true
					Remotes.get(Remotes.Names.CoinsUpdate):FireClient(player, stats.coins) -- correct the pre-load guess
					for _, cb in loadedCallbacks do
						Util.safeCall("statsLoaded", cb, player, stats)
					end
				end
				return
			end
			task.wait(Config.Data.RetryBackoffSeconds * attempt)
		end
		Util.warn("DataService: load failed for " .. player.Name .. " (memory-only this session)")
	end)
end

-- Why flushPlayer needs care around ownedClasses/claimedQuestIds/questFlags: UpdateAsync's transform
-- function can yield internally (Roblox may retry it), and other coroutines on the same server (e.g.
-- a BuyClass handler, or an easter-egg trigger) run concurrently while it's yielded. The numeric
-- counters dodge this because their delta always resets to 0 after a flush -- a mid-flight change
-- just adds to the now-zeroed delta and gets picked up next time, no loss. A SET-valued delta
-- (newlyOwnedClasses) can't be blindly wiped the same way: snapshot-then-clear-the-whole-table would
-- silently drop anything that arrived mid-flight. So: snapshot only what's about to be sent, and
-- after a successful flush, clear only those specific keys.
local function flushPlayer(player: Player)
	if not available or not dirty[player] then
		return
	end
	local delta = sessionDelta[player]
	local stats = cache[player]
	if not delta or not stats then
		return
	end
	local ownedSnapshot = table.clone(delta.newlyOwnedClasses)
	local equipDirty = delta.equippedClassDirty
	local equipSnapshot = delta.equippedClass
	local snapshot = {
		bestShift = delta.bestShift,
		dollsCleared = delta.dollsCleared,
		perfectShifts = delta.perfectShifts,
		runs = delta.runs,
		coins = delta.coins,
		ribbonsTiedTotal = delta.ribbonsTiedTotal,
		tutorialDone = stats.tutorialDone, -- absolute value -- OR-merge is idempotent, no delta needed
		claimedQuestIds = table.clone(stats.claimedQuestIds), -- absolute
		questFlags = table.clone(stats.questFlags), -- absolute
	}
	local ok = pcall(function()
		store:UpdateAsync(keyFor(player), function(old: any)
			old = if typeof(old) == "table" then old else {}
			local mergedOwned = if typeof(old.ownedClasses) == "table" then table.clone(old.ownedClasses) else {}
			for classId in ownedSnapshot do
				mergedOwned[classId] = true
			end
			local mergedClaimed = if typeof(old.claimedQuestIds) == "table" then table.clone(old.claimedQuestIds) else {}
			for id, v in snapshot.claimedQuestIds do
				if v then
					mergedClaimed[id] = true
				end
			end
			local mergedFlags = if typeof(old.questFlags) == "table" then table.clone(old.questFlags) else {}
			for id, v in snapshot.questFlags do
				if v then
					mergedFlags[id] = true
				end
			end
			return {
				bestShift = math.max(tonumber(old.bestShift) or 0, snapshot.bestShift),
				dollsCleared = (tonumber(old.dollsCleared) or 0) + snapshot.dollsCleared,
				perfectShifts = (tonumber(old.perfectShifts) or 0) + snapshot.perfectShifts,
				runs = (tonumber(old.runs) or 0) + snapshot.runs,
				coins = (tonumber(old.coins) or 0) + snapshot.coins,
				ribbonsTiedTotal = (tonumber(old.ribbonsTiedTotal) or 0) + snapshot.ribbonsTiedTotal,
				ownedClasses = mergedOwned,
				equippedClass = if equipDirty then equipSnapshot else (old.equippedClass or ""),
				tutorialDone = (old.tutorialDone == true) or snapshot.tutorialDone,
				claimedQuestIds = mergedClaimed,
				questFlags = mergedFlags,
			}
		end)
	end)
	if ok then
		dirty[player] = false
		local d = sessionDelta[player]
		if d then
			d.dollsCleared = 0
			d.perfectShifts = 0
			d.runs = 0
			d.coins = 0
			d.ribbonsTiedTotal = 0
			-- bestShift / tutorialDone / claimedQuestIds / questFlags stay as-is: their merges are idempotent
			for classId in ownedSnapshot do
				d.newlyOwnedClasses[classId] = nil -- only clear what THIS flush actually sent
			end
			if equipDirty and d.equippedClass == equipSnapshot then
				d.equippedClassDirty = false -- only clear if nothing newer landed mid-flight
			end
		end
	else
		Util.warn("DataService: flush failed for " .. player.Name)
	end
end

function DataService.init(_ctx: any)
	-- availability probe, deferred (R5: never blocks init)
	if Config.Features.DataStore then
		task.spawn(function()
			local ok = pcall(function()
				store = DataStoreService:GetDataStore(Config.Data.StoreName)
				store:GetAsync("__probe")
			end)
			available = ok
			Util.log("DataService: " .. (if available then "DataStores ONLINE" else "DataStores unavailable — memory-only (publish + enable Studio API access to persist)"))
			if available then
				for _, player in Players:GetPlayers() do
					if cache[player] and not cache[player].loaded then
						loadPlayer(player)
					end
				end
			end
		end)
	end

	Players.PlayerAdded:Connect(loadPlayer)
	for _, player in Players:GetPlayers() do
		if not cache[player] then
			loadPlayer(player)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		flushPlayer(player)
		cache[player] = nil
		sessionDelta[player] = nil
		dirty[player] = nil
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			Util.safeCall("bindToCloseFlush", flushPlayer, player)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(120)
			for _, player in Players:GetPlayers() do
				Util.safeCall("autosave", flushPlayer, player)
			end
		end
	end)
end

function DataService.getStats(player: Player): Stats
	return cache[player] or defaultStats()
end

function DataService.recordRun(player: Player, result: { shiftReached: number, dollsCleared: number, perfect: number })
	local stats = cache[player]
	local delta = sessionDelta[player]
	if not stats or not delta then
		return
	end
	stats.bestShift = math.max(stats.bestShift, result.shiftReached)
	stats.dollsCleared += result.dollsCleared
	stats.perfectShifts += result.perfect
	stats.runs += 1
	delta.bestShift = math.max(delta.bestShift, result.shiftReached)
	delta.dollsCleared += result.dollsCleared
	delta.perfectShifts += result.perfect
	delta.runs += 1
	dirty[player] = true
	for _, cb in loadedCallbacks do
		Util.safeCall("statsChanged", cb, player, stats)
	end
end

-- ---------- economy / journal support ----------

-- Signed delta: positive = earn, negative = spend. Clamps so the balance never goes below 0.
-- Fires CoinsUpdate to the player so HUD/Shop stay live without polling.
function DataService.addCoins(player: Player, amount: number): number
	local stats = cache[player]
	local delta = sessionDelta[player]
	if not stats or not delta then
		return 0
	end
	local applied = math.max(amount, -stats.coins)
	stats.coins += applied
	delta.coins += applied
	dirty[player] = true
	Remotes.get(Remotes.Names.CoinsUpdate):FireClient(player, stats.coins)
	for _, cb in loadedCallbacks do
		Util.safeCall("statsChanged", cb, player, stats)
	end
	return stats.coins
end

-- Server-authoritative spend: fails closed (false) if the player can't afford it. Never trust a
-- client-sent balance -- this reads from cache, which only this service ever mutates.
function DataService.spendCoins(player: Player, amount: number): boolean
	local stats = cache[player]
	if not stats or amount <= 0 or stats.coins < amount then
		return false
	end
	DataService.addCoins(player, -amount)
	return true
end

function DataService.grantClassOwnership(player: Player, classId: string)
	local stats = cache[player]
	local delta = sessionDelta[player]
	if not stats or not delta or stats.ownedClasses[classId] then
		return
	end
	stats.ownedClasses[classId] = true
	delta.newlyOwnedClasses[classId] = true
	dirty[player] = true
end

function DataService.setEquippedClass(player: Player, classId: string)
	local stats = cache[player]
	local delta = sessionDelta[player]
	if not stats or not delta then
		return
	end
	stats.equippedClass = classId
	delta.equippedClassDirty = true
	delta.equippedClass = classId
	dirty[player] = true
end

function DataService.addRibbonTied(player: Player, amount: number)
	local stats = cache[player]
	local delta = sessionDelta[player]
	if not stats or not delta then
		return
	end
	stats.ribbonsTiedTotal += amount
	delta.ribbonsTiedTotal += amount
	dirty[player] = true
	for _, cb in loadedCallbacks do
		Util.safeCall("statsChanged", cb, player, stats)
	end
end

-- One-way flag. Idempotent: calling this after it's already true is a harmless no-op.
function DataService.setTutorialDone(player: Player)
	local stats = cache[player]
	if not stats or stats.tutorialDone then
		return
	end
	stats.tutorialDone = true
	dirty[player] = true
	for _, cb in loadedCallbacks do
		Util.safeCall("statsChanged", cb, player, stats)
	end
end

function DataService.setQuestFlag(player: Player, questId: string)
	local stats = cache[player]
	if not stats or stats.questFlags[questId] then
		return
	end
	stats.questFlags[questId] = true
	dirty[player] = true
	for _, cb in loadedCallbacks do
		Util.safeCall("statsChanged", cb, player, stats)
	end
end

-- Returns false if already claimed (caller should treat as "nothing to pay out" -- this is the
-- double-payout guard).
function DataService.markQuestClaimed(player: Player, questId: string): boolean
	local stats = cache[player]
	if not stats or stats.claimedQuestIds[questId] then
		return false
	end
	stats.claimedQuestIds[questId] = true
	dirty[player] = true
	for _, cb in loadedCallbacks do
		Util.safeCall("statsChanged", cb, player, stats)
	end
	return true
end

function DataService.onStatsChanged(fn: (Player, Stats) -> ())
	table.insert(loadedCallbacks, fn)
end

return DataService
