--!strict
-- Every audio cue in the game, one line each. ALL catalog ids ship as 0 (silent no-op) —
-- the team fills these from the Creator Store in Studio (PLAYTEST.md has the guide).
-- Only built-in rbxasset:// files are prefilled (safe: they ship with the client).
-- soundId = 0 means SoundClient skips the cue without erroring.

export type Cue = {
	soundId: number | string, -- 0 = unset; number = catalog id; string = rbxasset:// path
	volume: number,
	looped: boolean?,
	speed: number?, -- PlaybackSpeed
}

local SoundConfig: { [string]: Cue } = {
	-- Ambience (looped beds; tier layers fade in client-side)
	AmbienceBase = { soundId = 0, volume = 0.4, looped = true }, -- TODO(team): quiet workshop room tone
	AmbienceTier2 = { soundId = 0, volume = 0.3, looped = true }, -- TODO(team): low unease drone
	AmbienceTier3 = { soundId = 0, volume = 0.35, looped = true }, -- TODO(team): close, wrong, breathing

	-- The music box (the game's musical signature; also a tell)
	MusicBoxLoop = { soundId = 0, volume = 0.5, looped = true }, -- TODO(team): music box lullaby
	MusicBoxDetuned = { soundId = 0, volume = 0.5, looped = true, speed = 0.82 }, -- TODO(team): same lullaby (client detunes)

	-- UI / feedback (built-ins prefilled — these always work)
	UiClick = { soundId = "rbxasset://sounds/button.wav", volume = 0.6 },
	UiConfirm = { soundId = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6 },
	DetectorTick = { soundId = "rbxasset://sounds/snap.mp3", volume = 0.7 },

	-- Care minigames
	BrushStroke = { soundId = 0, volume = 0.5 }, -- TODO(team): soft brush swish
	StepDone = { soundId = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5 },
	RibbonTie = { soundId = 0, volume = 0.6 }, -- TODO(team): delicate chime

	-- Scares (every one has a visual co-cue; silence does not break the game)
	StingReveal = { soundId = 0, volume = 0.9 }, -- TODO(team): short orchestral sting (banish reveal)
	StingWrong = { soundId = 0, volume = 0.9 }, -- TODO(team): sour, descending sting (wrong banish)
	DollmakerScream = { soundId = 0, volume = 1 }, -- TODO(team): THE scream (run-end scare; our Deer)
	WhisperPass = { soundId = 0, volume = 0.6 }, -- TODO(team): passing whisper L->R
	DoorSlam = { soundId = 0, volume = 0.8 }, -- TODO(team): heavy door slam
	BenchRattle = { soundId = 0, volume = 0.7 }, -- TODO(team): wood rattle
	LightsOut = { soundId = 0, volume = 0.8 }, -- TODO(team): breaker thunk

	-- Emotes
	PanicBark = { soundId = 0, volume = 0.8 }, -- TODO(team): character yelp ("the characters scream so players don't have to")
}

return SoundConfig
