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
	},

	Lobby = {
		ReadyCountdownSeconds = 10,
		BillboardMaxDistance = 60,
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
			ShiftActive = 900, -- 15 min ceiling on one shift
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
		BaseFillPerSecond = 0.10, -- ~16 quiet minutes to max; escalation multiplies this
		LastDollAccelMultiplier = 2.0, -- after every doll's care chain is done
		RushSurge = { -- anti-rush rubber band: surge added when steps complete too fast
			WindowSeconds = 20,
			StepsInWindow = 4,
			SurgeAmount = 6,
			DecayPerSecond = 0.25,
		},
		StrikeSurge = 12,
		WrongBanishSurge = 15,
		Tiers = { 25, 55, 85 }, -- tier 0 below first threshold; tiers gate haunts + ambience
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

	Banish = {
		SoloConfirmSeconds = 10,
		MajorityTimerSeconds = 30,
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
}

return Config
