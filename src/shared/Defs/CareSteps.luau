--!strict
-- The care chain. The 5 LISTED steps show on the HUD; the silver ribbon is deliberately
-- NOT listed (the forgettable "reagent" — taught once on the lobby chalkboard, MASTER.md 9.3).
-- minigame kinds: "mash" (tap fast), "hold" (hold steady), "sequence" (tap in order), "timing" (tap in the zone)

export type CareStep = {
	id: string,
	order: number,
	name: string,
	verb: string, -- objective phrasing
	minigame: "mash" | "hold" | "sequence" | "timing",
}

local Steps: { CareStep } = {
	{ id = "Brush", order = 1, name = "Brush Hair", verb = "Brush the hair smooth", minigame = "mash" },
	{ id = "Eyes", order = 2, name = "Polish Eyes", verb = "Polish both eyes", minigame = "hold" },
	{ id = "Face", order = 3, name = "Paint Face", verb = "Paint the face", minigame = "sequence" },
	{ id = "Dress", order = 4, name = "Dress", verb = "Button the dress coat", minigame = "timing" },
	{ id = "MusicBox", order = 5, name = "Wind Music Box", verb = "Wind the music box", minigame = "hold" },
}

-- The hidden sixth act. Not part of Steps on purpose: not on the HUD checklist,
-- required by the banish. Its absence is discovered the hard way.
local Ribbon = {
	id = "Ribbon",
	name = "Tie the Silver Ribbon",
}

local byId: { [string]: CareStep } = {}
for _, step in Steps do
	byId[step.id] = step
end

return {
	list = Steps,
	byId = byId,
	Ribbon = Ribbon,
}
