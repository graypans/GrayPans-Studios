--!strict
-- Debug commands + overlay feed (R7). Active only when Config.DebugMode.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Util = require(Shared:WaitForChild("Util")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any

local DebugService = {}

local ctx: any

local function allowed(player: Player): boolean
	if not Config.DebugMode then
		return false
	end
	if #Config.DebugAllowlist == 0 then
		return true
	end
	return table.find(Config.DebugAllowlist, player.Name) ~= nil
end

local function toast(player: Player, msg: string)
	Remotes.get(Remotes.Names.Toast):FireClient(player, msg, 5)
end

local function handleCommand(player: Player, message: string)
	if not allowed(player) or message:sub(1, 1) ~= "/" then
		return
	end
	local args = message:split(" ")
	local cmd = args[1]:lower()
	local S = ctx.services

	if cmd == "/skipstate" then
		S.ShiftManager.debugForceState()
		toast(player, "state forced")
	elseif cmd == "/shift" then
		local n = tonumber(args[2])
		if n then
			S.ShiftManager.debugSetShift(n)
			toast(player, "shift set to " .. n)
		end
	elseif cmd == "/reveal" then
		local markedName, code = S.ShiftManager.debugReveal()
		toast(player, ("marked: %s | spirit: %s (%s)"):format(
			tostring(markedName),
			code and code.name or "?",
			code and code.code or "?"
		))
	elseif cmd == "/completedoll" then
		local CareSteps = require(Shared:WaitForChild("Defs"):WaitForChild("CareSteps")) :: any
		for _, dollId in S.DollService.getDollIds() do
			for _, step in CareSteps.list do
				S.DollService.completeStep(player, dollId, step.id)
			end
		end
		toast(player, "all care steps completed")
	elseif cmd == "/strike" then
		local delta = tonumber(args[2]) or 1
		S.ShiftManager.debugStrike(delta)
		toast(player, "strike " .. delta)
	elseif cmd == "/presence" then
		local n = tonumber(args[2])
		if n then
			S.PresenceService.setValue(n)
			toast(player, "presence = " .. n)
		end
	elseif cmd == "/haunt" then
		local id = args[2]
		if id then
			S.HauntService.force(id, ctx.rng)
			toast(player, "haunt " .. id)
		end
	elseif cmd == "/ribbon" then
		-- direct-grant path for testing
		local manifest = ctx.manifest
		if manifest.ribbonPrompt then
			toast(player, "walk to the spool; or use prompt — granting via spool trigger not simulated")
		end
	elseif cmd == "/sound" then
		-- audio test: /sound <CueName> plays it for everyone (fills the audio-test-board role)
		local SoundKit = require(Shared:WaitForChild("SoundKit")) :: any
		local cue = args[2]
		if cue then
			SoundKit.play(cue)
			toast(player, "played cue " .. cue .. " (silence = id still 0 in SoundConfig)")
		end
	elseif cmd == "/endrun" then
		S.ShiftManager.debugEndRun()
		toast(player, "run ended")
	elseif cmd == "/resetrun" then
		S.ShiftManager.debugEndRun()
		toast(player, "run reset")
	end
end

function DebugService.init(context: any)
	ctx = context
	if not Config.DebugMode then
		return
	end
	Util.log("DebugService ACTIVE — /skipstate /shift N /reveal /completedoll /strike N /presence N /haunt <id> /endrun")

	local function hook(player: Player)
		player.Chatted:Connect(function(message)
			Util.safeCall("debugCommand", handleCommand, player, message)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end

	-- overlay feed at 2 Hz
	task.spawn(function()
		while true do
			task.wait(0.5)
			local S = ctx.services
			local payload = {
				presence = math.floor(S.PresenceService.getValue() * 10) / 10,
				tier = S.PresenceService.getTier(),
				state = S.ShiftManager.getState(),
				shift = S.ShiftManager.getShiftNumber(),
				watched = S.WatchService.watchedMap(),
				marked = S.DollService.getMarkedId(),
			}
			for _, player in Players:GetPlayers() do
				if allowed(player) then
					Remotes.get(Remotes.Names.DebugInfo):FireClient(player, payload)
				end
			end
		end
	end)
end

return DebugService
