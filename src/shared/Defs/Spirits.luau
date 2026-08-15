--!strict
-- The six spirits of the beta (12 planned; content lever per MASTER.md 9.3).
-- Each spirit's code is an ORDERED sequence of 3 glyph ids (order matters, like the original's sigil matching).

export type Spirit = {
	id: string,
	name: string,
	code: { string }, -- ordered glyph ids, length 3
	flavor: string, -- one line in the ledger, readable by kids, adds lore
}

local Spirits: { Spirit } = {
	{
		id = "Hollow",
		name = "The Hollow One",
		code = { "SleepingEye", "MoonHook", "HollowStar" },
		flavor = "It wears what it empties. Check the eyes; the eyes are honest.",
	},
	{
		id = "Latch",
		name = "Old Latch",
		code = { "BentKey", "CrookedWindow", "TripleTear" },
		flavor = "It never uses doors. It IS doors.",
	},
	{
		id = "Thimble",
		name = "Little Thimble",
		code = { "StitchedHeart", "RibbonCoil", "SleepingEye" },
		flavor = "It sews itself in. Look for the extra stitch.",
	},
	{
		id = "Waltz",
		name = "The Midnight Waltz",
		code = { "MoonHook", "TripleTear", "SleepingEye" },
		flavor = "If the music box plays with no hand on the crank, count the dolls twice.",
	},
	{
		id = "Wick",
		name = "Sister Wick",
		code = { "HollowStar", "StitchedHeart", "BentKey" },
		flavor = "It drinks light. Lamps gutter where it sleeps.",
	},
	{
		id = "Patch",
		name = "Grandfather Patch",
		code = { "RibbonCoil", "CrookedWindow", "HollowStar" },
		flavor = "The oldest one. The ribbon remembers him, so tie it well.",
	},
}

local byId: { [string]: Spirit } = {}
for _, spirit in Spirits do
	byId[spirit.id] = spirit
end

return {
	list = Spirits,
	byId = byId,
}
