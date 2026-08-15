--!strict
-- Purchasable classes. Bought with coins in the lobby Shop; exactly one equipped at a time.
-- Each class grants ONE passive buff, applied for the wearer's next shift (ClassService.applyBuffs,
-- called once at ShiftIntro).

export type BuffKind =
	"None"
	| "CareSpeedMultiplier" -- <1 = faster care minigames (0.85 = 15% faster)
	| "ExtraStrike" -- +N to that shift's effective strike limit (shared across the whole group)
	| "TellDurationMultiplier" -- >1 = tells (real + fake) linger longer before resetting (shared, shift-wide)
	| "StartWithRibbon" -- wearer starts the shift already holding a silver ribbon
	| "CoinMultiplier" -- multiplies THIS player's coin awards for the shift (1.25 = +25%)

export type ClassBuff = {
	kind: BuffKind,
	value: number?,
}

export type ClassDef = {
	id: string,
	name: string,
	price: number, -- coins; 0 = free starter, always owned
	description: string, -- one line, shown on the Shop card
	buff: ClassBuff,
}

local Classes: { ClassDef } = {
	{
		id = "Starter",
		name = "Apprentice",
		price = 0,
		description = "Steady hands, no tricks. The Dollmaker's first lesson.",
		buff = { kind = "None" },
	},
	{
		id = "RibbonReady",
		name = "Ribbon-Ready",
		price = 100,
		description = "You start every shift already holding a silver ribbon.",
		buff = { kind = "StartWithRibbon" },
	},
	{
		id = "SwiftHands",
		name = "Swift Hands",
		price = 120,
		description = "Care minigames run 15% faster.",
		buff = { kind = "CareSpeedMultiplier", value = 0.85 },
	},
	{
		id = "KeenEye",
		name = "Keen Eye",
		price = 140,
		description = "Tells linger 50% longer before they reset.",
		buff = { kind = "TellDurationMultiplier", value = 1.5 },
	},
	{
		id = "SteadyNerves",
		name = "Steady Nerves",
		price = 150,
		description = "Your group can take one extra wrong banish before the night ends.",
		buff = { kind = "ExtraStrike", value = 1 },
	},
	{
		id = "PennyPincher",
		name = "Penny-Pincher",
		price = 200,
		description = "Earn 25% more coins this shift.",
		buff = { kind = "CoinMultiplier", value = 1.25 },
	},
}

local byId: { [string]: ClassDef } = {}
for _, def in Classes do
	byId[def.id] = def
end

return {
	list = Classes,
	byId = byId,
	starterId = "Starter",
}
