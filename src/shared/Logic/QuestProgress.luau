--!strict
-- Pure logic: quest progress computation, shared by QuestService (server, authoritative) and
-- Journal (client, immediate feedback) -- same split as Logic/GlyphMatch.luau for the Ledger.

export type QuestStatsView = {
	dollsCleared: number,
	bestShift: number,
	perfectShifts: number,
	ribbonsTiedTotal: number,
	questFlags: { [string]: boolean },
}

export type QuestDef = {
	id: string,
	goalType: "DollsCleared" | "ShiftsSurvived" | "FirstTryBanishes" | "RibbonsTied" | "Flag",
	target: number,
}

local QuestProgress = {}

function QuestProgress.compute(stats: QuestStatsView, quest: QuestDef): number
	if quest.goalType == "DollsCleared" then
		return stats.dollsCleared
	elseif quest.goalType == "ShiftsSurvived" then
		return stats.bestShift
	elseif quest.goalType == "FirstTryBanishes" then
		return stats.perfectShifts
	elseif quest.goalType == "RibbonsTied" then
		return stats.ribbonsTiedTotal
	elseif quest.goalType == "Flag" then
		return (stats.questFlags[quest.id] == true) and 1 or 0
	end
	return 0
end

function QuestProgress.isComplete(stats: QuestStatsView, quest: QuestDef): boolean
	return QuestProgress.compute(stats, quest) >= quest.target
end

return QuestProgress
