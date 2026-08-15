--!strict
-- Tell types. Real tells fire on the marked doll; fake tells fire on innocents (framing).
-- unwatchedOnly tells require the doll to be unseen by any validated camera (Weeping Angels rule).
-- Every audio-flavored tell has a visual co-cue (audio ships silent).

export type TellDef = {
	id: string,
	weight: number,
	unwatchedOnly: boolean,
	fakeable: boolean, -- can the Presence fake this on an innocent doll?
	description: string, -- shown in the debug overlay / ledger lore page
}

local Tells: { TellDef } = {
	{
		id = "HeadTurn",
		weight = 10,
		unwatchedOnly = false,
		fakeable = true,
		description = "Its head turns a little toward you.",
	},
	{
		id = "EyesFollow",
		weight = 9,
		unwatchedOnly = false,
		fakeable = true,
		description = "The eyes track the nearest player for a few seconds.",
	},
	{
		id = "Scoot",
		weight = 8,
		unwatchedOnly = true,
		fakeable = true,
		description = "It is not where it was. Nobody saw it move.",
	},
	{
		id = "MusicBoxTurn",
		weight = 6,
		unwatchedOnly = false,
		fakeable = true,
		description = "Its music box crank turns by itself (the crank visibly rotates).",
	},
	{
		id = "Slump",
		weight = 7,
		unwatchedOnly = true,
		fakeable = true,
		description = "Its posture changed — slumped, or sat up straighter.",
	},
	{
		id = "StitchMark",
		weight = 4,
		unwatchedOnly = true,
		fakeable = false, -- marks never lie, but they are slow to appear (strong evidence, late)
		description = "A new crooked stitch mark appears on its arm (real dolls only).",
	},
}

local byId: { [string]: TellDef } = {}
for _, t in Tells do
	byId[t.id] = t
end

return {
	list = Tells,
	byId = byId,
}
