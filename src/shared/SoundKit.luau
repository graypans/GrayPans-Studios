--!strict
-- Sound helper honoring the ship-silent rule: cue ids of 0 no-op cleanly (no error spam).
-- Works on server (world sounds parented to parts) and client (SoundService-parented UI/ambience).

local SoundService = game:GetService("SoundService")

local SoundConfig = require(script.Parent.SoundConfig)
local Util = require(script.Parent.Util)

local SoundKit = {}

local function resolveId(id: number | string): string?
	if typeof(id) == "string" then
		return id -- rbxasset:// built-in
	end
	if typeof(id) == "number" and id > 0 then
		return ("rbxassetid://%d"):format(id)
	end
	return nil -- unset (0): silent no-op
end

-- Create a Sound for a cue, parented where you need it (a part for 3D, SoundService for 2D).
-- Returns nil when the cue is unset — callers must tolerate nil.
function SoundKit.attach(cueName: string, parent: Instance): Sound?
	local cue = SoundConfig[cueName]
	if not cue then
		Util.warn(("SoundKit: unknown cue '%s'"):format(cueName))
		return nil
	end
	local id = resolveId(cue.soundId)
	if not id then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "Cue_" .. cueName
	sound.SoundId = id
	sound.Volume = cue.volume
	sound.Looped = cue.looped == true
	if cue.speed then
		sound.PlaybackSpeed = cue.speed
	end
	sound.Parent = parent
	return sound
end

-- Fire-and-forget one-shot. Safe with unset cues. 2D when part is nil.
function SoundKit.play(cueName: string, part: Instance?)
	local parent: Instance = part or SoundService
	local sound = SoundKit.attach(cueName, parent)
	if not sound then
		return
	end
	sound.PlayOnRemove = false
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

return SoundKit
