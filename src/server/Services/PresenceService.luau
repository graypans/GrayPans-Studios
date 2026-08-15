--!strict
-- The Presence meter: wraps Logic/PresenceMath in a heartbeat loop; broadcasts tier changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Util = require(Shared:WaitForChild("Util")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local PresenceMath = require(Shared:WaitForChild("Logic"):WaitForChild("PresenceMath")) :: any

local PresenceService = {}

local ctx: any
local state: any = nil
local rateMultiplier = 1
local running = false
local maxedFired = false
local lastTier = -1
local maxedCallbacks: { () -> () } = {}
local connection: RBXScriptConnection? = nil

local mathCfg = {
	Max = Config.Presence.Max,
	BaseFillPerSecond = Config.Presence.BaseFillPerSecond,
	LastDollAccelMultiplier = Config.Presence.LastDollAccelMultiplier,
	RushWindowSeconds = Config.Presence.RushSurge.WindowSeconds,
	RushStepsInWindow = Config.Presence.RushSurge.StepsInWindow,
	RushSurgeAmount = Config.Presence.RushSurge.SurgeAmount,
	RushDecayPerSecond = Config.Presence.RushSurge.DecayPerSecond,
	Tiers = Config.Presence.Tiers,
}

local function pushTier()
	local tier = if state then PresenceMath.tier(state, mathCfg) else 0
	if tier ~= lastTier then
		lastTier = tier
		Remotes.get(Remotes.Names.PresenceTier):FireAllClients(tier)
		Util.safeCall("hauntSetTier", function()
			ctx.services.HauntService.setTier(tier)
		end)
	end
end

function PresenceService.init(context: any)
	ctx = context
end

function PresenceService.startShift(multiplier: number)
	rateMultiplier = multiplier
	state = PresenceMath.new()
	maxedFired = false
	running = true
	lastTier = -1
	pushTier()
	if connection then
		connection:Disconnect()
	end
	local acc = 0
	connection = RunService.Heartbeat:Connect(function(dt: number)
		if not running or not state then
			return
		end
		acc += dt
		if acc < 0.1 then
			return
		end
		PresenceMath.step(state, mathCfg, acc, rateMultiplier)
		acc = 0
		pushTier()
		if not maxedFired and PresenceMath.isMaxed(state, mathCfg) then
			maxedFired = true
			for _, cb in maxedCallbacks do
				Util.safeCall("presenceMaxed", cb)
			end
		end
	end)
end

function PresenceService.stop()
	running = false
	if connection then
		connection:Disconnect()
		connection = nil
	end
	state = nil
	lastTier = -1
	Remotes.get(Remotes.Names.PresenceTier):FireAllClients(0)
end

function PresenceService.surge(amount: number)
	if state then
		PresenceMath.addSurge(state, amount)
	end
end

function PresenceService.notifyStepCompleted()
	if state then
		PresenceMath.onStepCompleted(state, mathCfg, os.clock())
	end
end

function PresenceService.setAllDollsDone(done: boolean)
	if state then
		state.allDollsDone = done
	end
end

function PresenceService.getTier(): number
	return if state then PresenceMath.tier(state, mathCfg) else 0
end

function PresenceService.getValue(): number
	return if state then state.value else 0
end

function PresenceService.setValue(v: number)
	if state then
		state.value = math.clamp(v, 0, mathCfg.Max)
		pushTier()
	end
end

function PresenceService.onMaxed(fn: () -> ())
	table.insert(maxedCallbacks, fn)
end

return PresenceService
