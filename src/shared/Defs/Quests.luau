--!strict
-- The Dollmaker's Journal: quest/checklist roster. Data only -- no game references, mirrors the
-- shape of Defs/CareSteps.luau and Defs/Spirits.luau (list + byId). Progress math lives in
-- Logic/QuestProgress.luau so both QuestService (server) and Journal (client) share one
-- implementation, the same split used for GlyphMatch/LedgerUI.

export type GoalType = "DollsCleared" | "ShiftsSurvived" | "FirstTryBanishes" | "RibbonsTied" | "Flag"

export type Quest = {
	id: string,
	title: string,
	description: string,
	goalType: GoalType,
	target: number,
	coinReward: number,
	category: "Milestone" | "EasterEgg",
	hidden: boolean?, -- true = Journal UI shows "???" until DataService stats.questFlags[id] is true
}

local Quests: { Quest } = {
	{
		id = "DollsTen",
		title = "Gentle Hands",
		description = "Finish caring for 10 dolls, across as many shifts as it takes.",
		goalType = "DollsCleared",
		target = 10,
		coinReward = 15,
		category = "Milestone",
	},
	{
		id = "DollsFifty",
		title = "Steady Hands",
		description = "Finish caring for 50 dolls in total. The Dollmaker is starting to notice.",
		goalType = "DollsCleared",
		target = 50,
		coinReward = 60,
		category = "Milestone",
	},
	{
		id = "DollsHundred",
		title = "The Dollmaker's Favorite",
		description = "Finish caring for 100 dolls in total. Nobody else lasts this long.",
		goalType = "DollsCleared",
		target = 100,
		coinReward = 150,
		category = "Milestone",
	},
	{
		id = "ShiftFive",
		title = "Steady Nerves",
		description = "Survive all the way to Shift 5.",
		goalType = "ShiftsSurvived",
		target = 5,
		coinReward = 40,
		category = "Milestone",
	},
	{
		id = "ShiftTen",
		title = "Old Hand",
		description = "Survive all the way to Shift 10. The workshop feels almost familiar now.",
		goalType = "ShiftsSurvived",
		target = 10,
		coinReward = 100,
		category = "Milestone",
	},
	{
		id = "FirstTryFive",
		title = "Sharp Eyes",
		description = "Banish the right one on your very first guess, 5 times total.",
		goalType = "FirstTryBanishes",
		target = 5,
		coinReward = 50,
		category = "Milestone",
	},
	{
		id = "RibbonsTwentyFive",
		title = "Silver Fingers",
		description = "Tie the silver ribbon 25 times in total. Never skip it. Always. — The Dollmaker",
		goalType = "RibbonsTied",
		target = 25,
		coinReward = 45,
		category = "Milestone",
	},
	{
		id = "EggFloorboard",
		title = "Under the Floorboard",
		description = "Something was hidden beneath the lobby floor. You found it.",
		goalType = "Flag",
		target = 1,
		coinReward = 20,
		category = "EasterEgg",
		hidden = true,
	},
	{
		id = "EggNote",
		title = "The Dollmaker's Handwriting",
		description = "You found a note in handwriting that isn't yours. It knew you'd look.",
		goalType = "Flag",
		target = 1,
		coinReward = 20,
		category = "EasterEgg",
		hidden = true,
	},
	{
		id = "EggStillness",
		title = "Don't Move",
		description = "You stood somewhere you shouldn't have, and stayed there. Something noticed.",
		goalType = "Flag",
		target = 1,
		coinReward = 25,
		category = "EasterEgg",
		hidden = true,
	},
}

local byId: { [string]: Quest } = {}
for _, quest in Quests do
	byId[quest.id] = quest
end

return {
	list = Quests,
	byId = byId,
}
