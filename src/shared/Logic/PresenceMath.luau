--!strict
-- Pure logic: the Presence meter (no `game` references — unit-tested).
-- Constant fill + rush-surge rubber band + last-doll acceleration + event surges.

export type PresenceState = {
	value: number,
	surge: number, -- decaying extra fill from rushing
	stepTimestamps: { number }, -- recent care-step completion times (for rush detection)
	allDollsDone: boolean,
}

export type PresenceConfig = {
	Max: number,
	BaseFillPerSecond: number,
	LastDollAccelMultiplier: number,
	RushWindowSeconds: number,
	RushStepsInWindow: number,
	RushSurgeAmount: number,
	RushDecayPerSecond: number,
	Tiers: { number },
}

local PresenceMath = {}

function PresenceMath.new(): PresenceState
	return {
		value = 0,
		surge = 0,
		stepTimestamps = {},
		allDollsDone = false,
	}
end

-- Record a completed care step at time t; may trigger a rush surge.
function PresenceMath.onStepCompleted(state: PresenceState, cfg: PresenceConfig, t: number)
	table.insert(state.stepTimestamps, t)
	-- drop timestamps outside the window
	local cutoff = t - cfg.RushWindowSeconds
	while #state.stepTimestamps > 0 and state.stepTimestamps[1] < cutoff do
		table.remove(state.stepTimestamps, 1)
	end
	if #state.stepTimestamps >= cfg.RushStepsInWindow then
		state.surge += cfg.RushSurgeAmount
		table.clear(state.stepTimestamps) -- one surge per burst
	end
end

function PresenceMath.addSurge(state: PresenceState, amount: number)
	state.surge += amount
end

-- Advance the meter by dt seconds. rateMultiplier comes from Escalation.
function PresenceMath.step(state: PresenceState, cfg: PresenceConfig, dt: number, rateMultiplier: number)
	local fill = cfg.BaseFillPerSecond * rateMultiplier
	if state.allDollsDone then
		fill *= cfg.LastDollAccelMultiplier
	end
	-- surge contributes directly, then decays
	local surgeSpend = math.min(state.surge, cfg.RushDecayPerSecond * dt * 4)
	state.surge = math.max(0, state.surge - cfg.RushDecayPerSecond * dt)
	state.value = math.min(cfg.Max, state.value + fill * dt + surgeSpend)
end

function PresenceMath.tier(state: PresenceState, cfg: PresenceConfig): number
	local tier = 0
	for i, threshold in cfg.Tiers do
		if state.value >= threshold then
			tier = i
		end
	end
	return tier
end

function PresenceMath.isMaxed(state: PresenceState, cfg: PresenceConfig): boolean
	return state.value >= cfg.Max
end

return PresenceMath
