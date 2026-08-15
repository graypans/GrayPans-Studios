--!strict
-- Unit tests for the pure-logic core + definition cross-reference validation.
-- Runs in plain Luau CLI (no Roblox): `luau tests/logic.spec.luau`
-- Exits nonzero on failure so CI/scripts can gate on it.

local GlyphMatch = require("../src/shared/Logic/GlyphMatch")
local Escalation = require("../src/shared/Logic/Escalation")
local PresenceMath = require("../src/shared/Logic/PresenceMath")
local Draw = require("../src/shared/Logic/Draw")

local Glyphs = require("../src/shared/Defs/Glyphs")
local Spirits = require("../src/shared/Defs/Spirits")
local CareSteps = require("../src/shared/Defs/CareSteps")
local Tells = require("../src/shared/Defs/Tells")
local Haunts = require("../src/shared/Defs/Haunts")
local DollNames = require("../src/shared/Defs/DollNames")

local failures = 0
local total = 0

local function check(name: string, cond: boolean, detail: string?)
	total += 1
	if cond then
		print("  ok:", name)
	else
		failures += 1
		print("  FAIL:", name, detail or "")
	end
end

-- Deterministic mock rng (LCG) satisfying RngLike
local function mockRng(seed: number): Draw.RngLike
	local state = seed
	local function next(): number
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	return {
		NextNumber = function(_self)
			return next()
		end,
		NextInteger = function(_self, min: number, max: number)
			return min + math.floor(next() * (max - min + 1))
		end,
	} :: any
end

print("== Defs cross-reference validation ==")
do
	local ok, err = GlyphMatch.validateDefs(Spirits.list, Glyphs.byId)
	check("spirit codes reference real glyphs, unique, length 3", ok, err)
	check("at least 6 spirits", #Spirits.list >= 6)
	check("at least 8 glyphs", #Glyphs.list >= 8)
	check("5 listed care steps", #CareSteps.list == 5)
	local ordersSeen = {}
	local ordersOk = true
	for _, step in CareSteps.list do
		if ordersSeen[step.order] then
			ordersOk = false
		end
		ordersSeen[step.order] = true
	end
	check("care step orders unique", ordersOk)
	check("ribbon is not a listed step", CareSteps.byId[CareSteps.Ribbon.id] == nil)
	check("tells exist", #Tells.list >= 5)
	local hasUnfakeable = false
	for _, t in Tells.list do
		if not t.fakeable then
			hasUnfakeable = true
		end
	end
	check("at least one unfakeable tell (evidence that never lies)", hasUnfakeable)
	check("haunts exist", #Haunts.list >= 8)
	local tiersOk = true
	for _, h in Haunts.list do
		if h.tier < 1 or h.tier > 3 then
			tiersOk = false
		end
	end
	check("haunt tiers in 1..3", tiersOk)
	check("20 curated doll names", #DollNames >= 20)
end

print("== GlyphMatch ==")
do
	local code = { "A", "B", "C" }
	check("exact match", GlyphMatch.matches(code, { "A", "B", "C" }))
	check("wrong order rejected", not GlyphMatch.matches(code, { "B", "A", "C" }))
	check("partial rejected", not GlyphMatch.matches(code, { "A", "B" }))
	check("empty rejected", not GlyphMatch.matches(code, {}))
	check("extra glyph rejected", not GlyphMatch.matches(code, { "A", "B", "C", "D" }))
	local spirits = { { id = "x", code = { "A", "B", "C" } }, { id = "y", code = { "C", "B", "A" } } }
	check("identify finds the right spirit", GlyphMatch.identify(spirits, { "C", "B", "A" }) == "y")
	check("identify returns nil on no match", GlyphMatch.identify(spirits, { "A", "A", "A" }) == nil)
end

print("== Escalation ==")
do
	local cfg: Escalation.EscalationConfig = {
		BaseDollCount = 3,
		SoloDollCap = 3,
		MaxDollCount = 5,
		DollCountShiftMilestones = { 4, 8 },
		BaseFakeTellChance = 0.35,
		BaseTellIntervalMin = 20,
		BaseTellIntervalMax = 40,
		GlyphsPerShift = 3,
	}
	local s1 = Escalation.forShift(cfg, 1, 4)
	check("shift 1: base dolls", s1.dollCount == 3)
	local s4 = Escalation.forShift(cfg, 4, 4)
	check("shift 4 multiplayer: +1 doll", s4.dollCount == 4)
	local s9 = Escalation.forShift(cfg, 9, 4)
	check("shift 9 multiplayer: +2 dolls", s9.dollCount == 5)
	local s20 = Escalation.forShift(cfg, 20, 4)
	check("doll count capped", s20.dollCount == 5)
	local solo9 = Escalation.forShift(cfg, 9, 1)
	check("solo doll cap holds at shift 9", solo9.dollCount == 3)
	check("fake tells escalate", Escalation.forShift(cfg, 5, 2).fakeTellChance > s1.fakeTellChance)
	check("fake tells capped at 0.75", Escalation.forShift(cfg, 99, 2).fakeTellChance <= 0.75)
	check("solo meter slower", Escalation.forShift(cfg, 1, 1).presenceRateMultiplier < s1.presenceRateMultiplier)
	check("tell intervals stretch", Escalation.forShift(cfg, 11, 2).tellIntervalMin > s1.tellIntervalMin)
end

print("== PresenceMath ==")
do
	local cfg: PresenceMath.PresenceConfig = {
		Max = 100,
		BaseFillPerSecond = 0.1,
		LastDollAccelMultiplier = 2,
		RushWindowSeconds = 20,
		RushStepsInWindow = 4,
		RushSurgeAmount = 6,
		RushDecayPerSecond = 0.25,
		Tiers = { 25, 55, 85 },
	}
	local st = PresenceMath.new()
	PresenceMath.step(st, cfg, 10, 1)
	check("10s quiet fill = 1.0", math.abs(st.value - 1.0) < 0.01, tostring(st.value))
	check("tier 0 early", PresenceMath.tier(st, cfg) == 0)

	-- rush: 4 steps inside the window triggers a surge
	local before = st.value
	for i = 1, 4 do
		PresenceMath.onStepCompleted(st, cfg, 100 + i)
	end
	check("rush surge armed", st.surge > 0)
	PresenceMath.step(st, cfg, 1, 1)
	check("surge raises value faster than base", (st.value - before) > 0.1 * 1 + 0.05)

	-- steps far apart never surge
	local st2 = PresenceMath.new()
	for i = 1, 6 do
		PresenceMath.onStepCompleted(st2, cfg, i * 60)
	end
	check("spaced steps no surge", st2.surge == 0)

	-- last-doll acceleration
	local st3 = PresenceMath.new()
	st3.allDollsDone = true
	PresenceMath.step(st3, cfg, 10, 1)
	check("all-dolls-done doubles fill", math.abs(st3.value - 2.0) < 0.01, tostring(st3.value))

	-- tiers + max
	local st4 = PresenceMath.new()
	st4.value = 56
	check("tier 2 at 56", PresenceMath.tier(st4, cfg) == 2)
	st4.value = 100
	check("maxed at 100", PresenceMath.isMaxed(st4, cfg))

	-- strike surges
	local st5 = PresenceMath.new()
	PresenceMath.addSurge(st5, 12)
	PresenceMath.step(st5, cfg, 1, 1)
	check("event surge raises value", st5.value > 0.1)

	-- surge integral: a surge event contributes exactly its nominal amount, never amplified (B9 fix)
	local st6 = PresenceMath.new()
	PresenceMath.addSurge(st6, 20)
	local dt = 0.1
	local ticks = 0
	while st6.surge > 0 and ticks < 10000 do
		PresenceMath.step(st6, cfg, dt, 0) -- rateMultiplier=0 isolates the surge-only contribution
		ticks += 1
	end
	local elapsed = ticks * dt
	check("surge fully drains", st6.surge == 0, tostring(st6.surge))
	check("surge contributes exactly its nominal amount, not amplified", math.abs(st6.value - 20) < 0.01, tostring(st6.value))
	check(
		"surge drains in amount/DecayPerSecond seconds",
		math.abs(elapsed - (20 / cfg.RushDecayPerSecond)) < 0.15,
		tostring(elapsed)
	)
end

print("== Draw ==")
do
	local rng = mockRng(42)
	local picks: { [string]: number } = { a = 0, b = 0 }
	for _ = 1, 1000 do
		local id = Draw.weighted(rng, { { id = "a", weight = 9 }, { id = "b", weight = 1 } })
		assert(id)
		picks[id] += 1
	end
	check("weighted respects weights (~9:1)", picks.a > 800 and picks.b > 20, ("a=%d b=%d"):format(picks.a, picks.b))
	check("zero-weight pool -> nil", Draw.weighted(rng, { { id = "a", weight = 0 } }) == nil)
	check("empty pool -> nil", Draw.weighted(rng, {}) == nil)

	local sampled = Draw.sample(rng, { 1, 2, 3, 4, 5 }, 3)
	check("sample size", #sampled == 3)
	local distinct = {}
	local allDistinct = true
	for _, v in sampled do
		if distinct[v] then
			allDistinct = false
		end
		distinct[v] = true
	end
	check("sample distinct", allDistinct)
	check("sample clamps to list size", #Draw.sample(rng, { 1, 2 }, 10) == 2)
	check("one from empty -> nil", Draw.one(rng, {} :: { number }) == nil)
end

print(("\n%d/%d checks passed"):format(total - failures, total))
if failures > 0 then
	error(("%d test failure(s)"):format(failures))
end
