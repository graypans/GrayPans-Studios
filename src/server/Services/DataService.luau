--!strict
-- Persistence per R5: probe once, memory fallback, UpdateAsync merge-only, never blocks gameplay.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Util = require(Shared:WaitForChild("Util")) :: any

local DataService = {}

type Stats = { bestShift: number, dollsCleared: number, perfectShifts: number, runs: number, loaded: boolean }

local available = false
local store: any = nil
local cache: { [Player]: Stats } = {}
local sessionDelta: { [Player]: { dollsCleared: number, perfectShifts: number, runs: number, bestShift: number } } = {}
local loadedCallbacks: { (Player, Stats) -> () } = {}

local function defaultStats(): Stats
	return { bestShift = 0, dollsCleared = 0, perfectShifts = 0, runs = 0, loaded = false }
end

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

local function loadPlayer(player: Player)
	cache[player] = defaultStats()
	sessionDelta[player] = { dollsCleared = 0, perfectShifts = 0, runs = 0, bestShift = 0 }
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
				end
				if stats then
					stats.loaded = true
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

local function flushPlayer(player: Player)
	if not available then
		return
	end
	local delta = sessionDelta[player]
	if not delta or (delta.runs == 0 and delta.bestShift == 0) then
		return
	end
	local snapshot = table.clone(delta)
	local ok = pcall(function()
		store:UpdateAsync(keyFor(player), function(old: any)
			old = if typeof(old) == "table" then old else {}
			return {
				bestShift = math.max(tonumber(old.bestShift) or 0, snapshot.bestShift),
				dollsCleared = (tonumber(old.dollsCleared) or 0) + snapshot.dollsCleared,
				perfectShifts = (tonumber(old.perfectShifts) or 0) + snapshot.perfectShifts,
				runs = (tonumber(old.runs) or 0) + snapshot.runs,
			}
		end)
	end)
	if ok then
		local d = sessionDelta[player]
		if d then
			d.dollsCleared = 0
			d.perfectShifts = 0
			d.runs = 0
			-- bestShift delta stays (max-merge is idempotent)
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
	for _, cb in loadedCallbacks do
		Util.safeCall("statsChanged", cb, player, stats)
	end
end

function DataService.onStatsChanged(fn: (Player, Stats) -> ())
	table.insert(loadedCallbacks, fn)
end

return DataService
