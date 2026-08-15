--!strict
-- All tunables for Project Porcelain live here. The team edits values; code never hardcodes them.

local Config = {
	Version = "0.1.0-beta",
	BuildStamp = "beta-2026-08-15", -- overwritten at build time by tools/stamp.sh

	-- Debug (R7). Turn DebugMode off before any public test.
	DebugMode = true,
	DebugAllowlist = {} :: { string }, -- empty = any player may use debug commands while DebugMode is true

	-- Feature kill switches (R3)
	Features = {
		DataStore = true, -- persistence layer probes availability itself; false = memory-only
		FakeTells = true,
		Detector = true,
		Naming = true, -- doll naming UI (default names still assigned when off)
		FreeTextNames = false, -- curated picker only for the beta; filtered free text post-review
		Taken = false, -- Taken haunt stub, off by default per plan review
		PanicEmote = true,
		Economy = true, -- coins/classes/shop master kill switch (R3)
		Quests = true, -- Journal/quest claim + easter-egg triggers + ribbon-tie counter kill switch (R3)
		TutorialGate = true, -- tutorialDone tracking kill switch (R3), independent of Quests
		InviteFallbackButton = false, -- off: the left-nav HUD owns the real Invite button; flip true
			-- only for standalone testing before that button exists / is tagged
		JoinSquares = true, -- R3 kill switch: false disables the whole subsystem; the old single
			-- ReadyPad (LobbyService + ShiftManager.requestStart) is untouched and keeps working
		PrivateShiftServers = true, -- R3 kill switch: false makes JoinSquareService ALWAYS resolve
			-- in-place via ShiftManager.beginShiftFor, even live -- the same flag MapBuilder reads
			-- (via ServerKind) to build both rooms again. Emergency escape hatch if live
			-- TeleportAsync/ReserveServer misbehaves. Always true in Studio regardless (ServerKind
			-- also checks RunService:IsStudio()).
	},

	Lobby = {
		ReadyCountdownSeconds = 10,
		BillboardMaxDistance = 60,
	},

	JoinSquares = {
		MaxGroupSize = 4, -- matches the existing up-to-4-player co-op cap; Escalation.forShift's
			-- math already assumes participant counts in this range
		CountdownSeconds = 30,
		AutoStartOnFull = true, -- collapses the countdown early once the square hits MaxGroupSize
		PollIntervalSeconds = 0.5, -- mirrors LobbyService's existing 2 Hz ready-pad poll rate
		DetectHeightPadding = 6, -- box height for GetPartBoundsInBox; XZ footprint is read from the
			-- tile part's own Size so this self-scales to whatever square geometry the map ships
		BillboardMaxDistance = 50, -- same order of magnitude as Lobby.BillboardMaxDistance
		ArrivalWatchdogSeconds = 15, -- R2: a reserved shift server starts with whoever has actually
			-- arrived after this long, even if short of the full group
		IdleColor = Color3.fromRGB(70, 160, 220), -- cyan-blue, matches the reference screenshots
		OccupiedColor = Color3.fromRGB(230, 210, 40), -- bright yellow, matches "turns yellow when occupied"
		LockingColor = Color3.fromRGB(212, 175, 96), -- gold; reads as "committing"
	},

	Shift = {
		BaseDollCount = 3,
		SoloDollCap = 3, -- solo never exceeds this regardless of escalation
		MaxDollCount = 5,
		DollCountShiftMilestones = { 4, 8 }, -- +1 doll at each of these shift numbers (multiplayer only)
		IntroSeconds = 8,
		ResultSeconds = 8,
		-- Watchdogs (R2): hard ceilings per state; on expiry the state force-advances with a warning
		Watchdog = {
			ShiftIntro = 20,
			-- 15 min ceiling on one shift. Deliberately NOT raised to chase Presence's own
			-- worst-case time-to-max: solo's unaccelerated baseline alone is ~22 minutes
			-- (100 / (BaseFillPerSecond * 0.75)), well past any reasonable watchdog ceiling.
			-- B9: instead of racing the watchdog against Presence, ShiftManager tags RunEnd with
			-- reason="watchdog" vs reason="presence" so a timeout never impersonates a possession
			-- scare. See ShiftManager.luau's armWatchdog/transition.
			ShiftActive = 900,
			BanishStaging = 30,
			ShiftResult = 25,
			RunEnd = 30,
		},
		StrikeLimit = 3,
	},

	Care = {
		MinigameSeconds = 12, -- watchdog per minigame; auto-release lock on expiry (R2)
		PromptDistance = 8,
		StepSeconds = { -- rough target duration per minigame type
			mash = 6,
			hold = 5,
			sequence = 10,
			timing = 8,
		},
	},

	Presence = {
		Max = 100,
		-- ~16.7 quiet minutes to max (100 / 0.10) with no acceleration, no surge, no escalation
		-- multiplier -- this is the deliberate "calm" baseline and playtest confirmed it's accurate.
		-- B9: the reported spikes were NOT from this constant; they were a surge-accounting bug in
		-- PresenceMath.step (fixed) plus LastDollAccelMultiplier/WrongBanishSurge being tuned for
		-- the old (over-amplified) surge math. See docs/PLAYTEST_REPORT_2026-08-15.md B9.
		BaseFillPerSecond = 0.10,
		LastDollAccelMultiplier = 1.5, -- (was 2.0) after every doll's care chain is done -- still a
			-- real hurry-up once care is finished, without erasing minutes of buffer in one shift
		RushSurge = { -- anti-rush rubber band: surge added when steps complete too fast
			WindowSeconds = 20,
			StepsInWindow = 4,
			SurgeAmount = 6,
			DecayPerSecond = 0.25,
		},
		-- NOTE: StrikeSurge is currently UNREFERENCED by any service -- every strike in this game
		-- originates from a wrong banish, and that path only calls
		-- PresenceService.surge(Config.Presence.WrongBanishSurge). Kept in Config (never
		-- remove/rename existing keys) and tuned in step with WrongBanishSurge in case a future
		-- strike source (e.g. a timed-out minigame) wires it in later.
		StrikeSurge = 10, -- (was 12)
		WrongBanishSurge = 10, -- (was 15) fires once per wrong banish via PresenceService.surge();
			-- PresenceMath.step now spends this pool at exactly RushSurge.DecayPerSecond pts/sec,
			-- so this number IS the total Presence contribution of one wrong banish (was ~4x this
			-- under the old, buggy surge math).
		Tiers = { 25, 55, 85 }, -- tier 0 below first threshold; tiers gate haunts + ambience
			-- (unchanged: these gate ambience/haunt tier, not pacing, and stay sensible under the
			-- corrected math)
	},

	Tells = {
		BaseIntervalSeconds = { min = 20, max = 40 }, -- marked doll fires a real tell within this window
		FakeTellChancePerWindow = 0.35, -- chance an innocent fires a framed tell in the same window; escalates
		WatchReportHz = 8, -- client camera stream rate
		WatchFovDegrees = 70,
		WatchMaxDistance = 60,
	},

	Glyphs = {
		PerShift = 3,
		CollectDistance = 10,
		DetectorMaxRange = 40, -- rattle starts inside this range
	},

	Ledger = {
		AutoCloseDistance = 12, -- studs; auto-close the ledger book once the player strays this far from LedgerDesk (B5)
	},

	Banish = {
		SoloConfirmSeconds = 10,
		MajorityTimerSeconds = 30,
	},

	Quests = {
		StillnessSeconds = 20, -- how long (seconds) to stand in the hidden spot for "Don't Move" --
			-- long enough to feel deliberate, short enough not to bore a kid
		StillnessPollHz = 2, -- matches LobbyService's existing ready-pad poll rate
	},

	Haunts = {
		Enabled = true,
		MinSecondsBetween = 25,
		-- per-event kill switches (R3); event ids must match Defs/Haunts
		Events = {
			SilhouetteDoorway = true,
			DoorCreakSlam = true,
			LightsOutBeat = true,
			DollHeadSnap = true,
			WhisperPass = true,
			WindowFigure = true,
			MusicBoxSwell = true,
			BenchRattle = true,
			Taken = false, -- mirrors Features.Taken
		},
	},

	Data = {
		StoreName = "PorcelainStatsV1",
		ReadRetries = 3,
		RetryBackoffSeconds = 2,
	},

	Economy = {
		CoinsPerDoll = 7, -- awarded to every current shift participant the instant a doll's 5
			-- listed care steps complete
		PerfectShiftBonus = 15, -- once per shift cleared with zero strikes that shift
		LateShiftBonusPerShift = 3, -- flat bonus per shift-number-above-1 cleared
		LateShiftBonusCapShifts = 5, -- bonus stops growing past shift 6 (5 * 3 = 15 max)
	},
}

return Config
