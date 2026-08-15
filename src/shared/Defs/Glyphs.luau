--!strict
-- Original cartoon glyph set (NO real occult symbols — policy-safe by design, MASTER.md 9.3).
-- Each glyph is drawn from primitive strokes so it can be rendered as SurfaceGui/ScreenGui Frames
-- with zero image assets. Coordinates are fractions of a square canvas (0..1), rotation in degrees.

export type Stroke = {
	x: number, -- center x (0..1)
	y: number, -- center y (0..1)
	w: number, -- width  (0..1)
	h: number, -- height (0..1)
	rot: number?, -- degrees
	round: boolean?, -- fully rounded corners (dot / ring segment look)
}

export type Glyph = {
	id: string,
	name: string,
	strokes: { Stroke },
}

local Glyphs: { Glyph } = {
	{
		id = "MoonHook",
		name = "Moon Hook",
		strokes = {
			{ x = 0.5, y = 0.25, w = 0.5, h = 0.1, rot = 0, round = true },
			{ x = 0.3, y = 0.5, w = 0.1, h = 0.5, rot = 15, round = true },
			{ x = 0.62, y = 0.72, w = 0.28, h = 0.1, rot = -30, round = true },
		},
	},
	{
		id = "TripleTear",
		name = "Triple Tear",
		strokes = {
			{ x = 0.3, y = 0.35, w = 0.12, h = 0.12, round = true },
			{ x = 0.55, y = 0.5, w = 0.12, h = 0.12, round = true },
			{ x = 0.4, y = 0.7, w = 0.12, h = 0.12, round = true },
			{ x = 0.5, y = 0.5, w = 0.66, h = 0.06, rot = 45, round = true },
		},
	},
	{
		id = "CrookedWindow",
		name = "Crooked Window",
		strokes = {
			{ x = 0.5, y = 0.28, w = 0.5, h = 0.08, rot = 8 },
			{ x = 0.5, y = 0.72, w = 0.5, h = 0.08, rot = -8 },
			{ x = 0.28, y = 0.5, w = 0.08, h = 0.5, rot = -8 },
			{ x = 0.72, y = 0.5, w = 0.08, h = 0.5, rot = 8 },
			{ x = 0.5, y = 0.5, w = 0.08, h = 0.4, rot = 20 },
		},
	},
	{
		id = "StitchedHeart",
		name = "Stitched Heart",
		strokes = {
			{ x = 0.38, y = 0.36, w = 0.22, h = 0.22, round = true },
			{ x = 0.62, y = 0.36, w = 0.22, h = 0.22, round = true },
			{ x = 0.5, y = 0.6, w = 0.36, h = 0.3, rot = 45 },
			{ x = 0.5, y = 0.48, w = 0.5, h = 0.05, rot = 12, round = true },
		},
	},
	{
		id = "BentKey",
		name = "Bent Key",
		strokes = {
			{ x = 0.35, y = 0.32, w = 0.2, h = 0.2, round = true },
			{ x = 0.35, y = 0.34, w = 0.09, h = 0.09, round = true },
			{ x = 0.5, y = 0.58, w = 0.09, h = 0.4, rot = -18, round = true },
			{ x = 0.68, y = 0.74, w = 0.2, h = 0.08, rot = 0, round = true },
			{ x = 0.62, y = 0.84, w = 0.12, h = 0.08, rot = 0, round = true },
		},
	},
	{
		id = "HollowStar",
		name = "Hollow Star",
		strokes = {
			{ x = 0.5, y = 0.5, w = 0.55, h = 0.08, rot = 0, round = true },
			{ x = 0.5, y = 0.5, w = 0.55, h = 0.08, rot = 60, round = true },
			{ x = 0.5, y = 0.5, w = 0.55, h = 0.08, rot = 120, round = true },
			{ x = 0.5, y = 0.5, w = 0.14, h = 0.14, round = true },
		},
	},
	{
		id = "SleepingEye",
		name = "Sleeping Eye",
		strokes = {
			{ x = 0.5, y = 0.5, w = 0.6, h = 0.09, rot = 0, round = true },
			{ x = 0.3, y = 0.62, w = 0.09, h = 0.2, rot = 30, round = true },
			{ x = 0.5, y = 0.66, w = 0.09, h = 0.2, rot = 0, round = true },
			{ x = 0.7, y = 0.62, w = 0.09, h = 0.2, rot = -30, round = true },
		},
	},
	{
		id = "RibbonCoil",
		name = "Ribbon Coil",
		strokes = {
			{ x = 0.5, y = 0.3, w = 0.44, h = 0.09, rot = -20, round = true },
			{ x = 0.5, y = 0.5, w = 0.44, h = 0.09, rot = 20, round = true },
			{ x = 0.5, y = 0.7, w = 0.44, h = 0.09, rot = -20, round = true },
		},
	},
}

local byId: { [string]: Glyph } = {}
for _, glyph in Glyphs do
	byId[glyph.id] = glyph
end

return {
	list = Glyphs,
	byId = byId,
}
