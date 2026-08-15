--!strict
-- Pure logic: per-shift difficulty derivation (no `game` references — unit-tested).

export type ShiftParams = {
	dollCount: number,
	fakeTellChance: number, -- 0..1 per tell window
	presenceRateMultiplier: number,
	tellIntervalMin: number,
	tellIntervalMax: number,
	glyphCount: number,
}

export type EscalationConfig = {
	BaseDollCount: number,
	SoloDollCap: number,
	MaxDollCount: number,
	DollCountShiftMilestones: { number },
	BaseFakeTellChance: number,
	BaseTellIntervalMin: number,
	BaseTellIntervalMax: number,
	GlyphsPerShift: number,
}

local Escalation = {}

function Escalation.forShift(cfg: EscalationConfig, shiftNumber: number, playerCount: number): ShiftParams
	assert(shiftNumber >= 1, "shiftNumber must be >= 1")
	assert(playerCount >= 1, "playerCount must be >= 1")

	local dollCount = cfg.BaseDollCount
	for _, milestone in cfg.DollCountShiftMilestones do
		if shiftNumber >= milestone then
			dollCount += 1
		end
	end
	dollCount = math.min(dollCount, cfg.MaxDollCount)
	if playerCount == 1 then
		-- R1/solo cap: escalation continues through tells + meter only (plan review fix)
		dollCount = math.min(dollCount, cfg.SoloDollCap)
	end

	-- Fake tells ramp: +6% per shift, capped at 75%
	local fakeTellChance = math.min(cfg.BaseFakeTellChance + 0.06 * (shiftNumber - 1), 0.75)

	-- Presence fills faster each shift: +8% per shift, capped at 3x; solo gets a 25% slower meter
	local presenceMultiplier = math.min(1 + 0.08 * (shiftNumber - 1), 3)
	if playerCount == 1 then
		presenceMultiplier *= 0.75
	end

	-- Real tells get subtler (less frequent) as shifts climb: interval stretches up to +50%
	local stretch = math.min(1 + 0.05 * (shiftNumber - 1), 1.5)

	return {
		dollCount = dollCount,
		fakeTellChance = fakeTellChance,
		presenceRateMultiplier = presenceMultiplier,
		tellIntervalMin = cfg.BaseTellIntervalMin * stretch,
		tellIntervalMax = cfg.BaseTellIntervalMax * stretch,
		glyphCount = cfg.GlyphsPerShift,
	}
end

return Escalation
