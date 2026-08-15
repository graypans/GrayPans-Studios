--!strict
-- Purchasable classes: ownership + one-equipped-at-a-time model + buff folding into shift params.
-- Persistence lives in DataService (R5); this service is validation + the buff-application hook
-- ShiftManager calls once per ShiftIntro.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Util = require(Shared:WaitForChild("Util")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local Classes = require(Shared:WaitForChild("Defs"):WaitForChild("Classes")) :: any

local ClassService = {}

local ctx: any

local function starterId(): string
	return Classes.starterId
end

local function ownedSet(player: Player): { [string]: boolean }
	local stats = ctx.services.DataService.getStats(player)
	return stats.ownedClasses or {}
end

function ClassService.isOwned(player: Player, classId: string): boolean
	local def = Classes.byId[classId]
	if not def then
		return false
	end
	if def.price <= 0 then
		return true -- free classes are always owned; never persisted as "owned"
	end
	return ownedSet(player)[classId] == true
end

function ClassService.getEquippedId(player: Player): string
	local stats = ctx.services.DataService.getStats(player)
	local id = stats.equippedClass
	if typeof(id) ~= "string" or id == "" or not Classes.byId[id] then
		return starterId()
	end
	if not ClassService.isOwned(player, id) then
		return starterId() -- defensive: should not happen, but never equip something not owned
	end
	return id
end

function ClassService.getEquippedBuff(player: Player): any
	local def = Classes.byId[ClassService.getEquippedId(player)]
	return (def and def.buff) or Classes.byId[starterId()].buff
end

-- Convenience read used at every coin-award call site so award code never has to know about buff
-- "kind" strings.
function ClassService.getCoinMultiplier(player: Player): number
	local buff = ClassService.getEquippedBuff(player)
	if buff.kind == "CoinMultiplier" then
		return buff.value or 1
	end
	return 1
end

local function pushClassesData(player: Player)
	Remotes.get(Remotes.Names.ClassesData):FireClient(player, {
		owned = ownedSet(player),
		equipped = ClassService.getEquippedId(player),
	})
end

-- Returns (ok: boolean, message: string) -- message is meant to go straight into a Toast.
function ClassService.buyClass(player: Player, classId: string): (boolean, string)
	if not Config.Features.Economy then
		return false, "The shop is closed right now."
	end
	local def = Classes.byId[classId]
	if not def then
		return false, "Unknown class."
	end
	if def.price <= 0 then
		return false, "That one's already free."
	end
	if ClassService.isOwned(player, classId) then
		return false, "You already own that."
	end
	local ok = ctx.services.DataService.spendCoins(player, def.price)
	if not ok then
		return false, "Not enough coins."
	end
	ctx.services.DataService.grantClassOwnership(player, classId)
	pushClassesData(player)
	return true, ("Bought %s."):format(def.name)
end

function ClassService.equipClass(player: Player, classId: string): (boolean, string)
	if not Config.Features.Economy then
		return false, "The shop is closed right now."
	end
	local def = Classes.byId[classId]
	if not def then
		return false, "Unknown class."
	end
	if not ClassService.isOwned(player, classId) then
		return false, "You don't own that yet."
	end
	ctx.services.DataService.setEquippedClass(player, classId)
	pushClassesData(player)
	return true, ("Equipped %s."):format(def.name)
end

-- Called once per shift, from ShiftManager's ShiftIntro branch, AFTER shiftParams exists and BEFORE
-- DollService.spawnShift/TellService.startShift/etc read it. R1: correct with 1 participant.
-- Shared/global buffs (ExtraStrike, TellDurationMultiplier) take the most-generous value across ALL
-- equipped participants rather than stacking -- strikes and tell timing are shift-wide state, not
-- per-player. Per-player buffs (StartWithRibbon) are applied directly here as a side effect;
-- CoinMultiplier is read per-player at the award call site instead, not folded into this aggregate.
function ClassService.applyBuffs(_shiftParams: any, participants: { Player }): any
	local aggregate = {
		strikeLimitBonus = 0,
		careSpeedMultiplier = 1, -- <1 = faster; most-generous (lowest) among equipped participants
		tellDurationMultiplier = 1, -- >1 = tells linger longer; most-generous (highest) among equipped participants
	}
	if not Config.Features.Economy then
		return aggregate
	end
	for _, player in participants do
		local buff = ClassService.getEquippedBuff(player)
		if buff.kind == "ExtraStrike" then
			aggregate.strikeLimitBonus = math.max(aggregate.strikeLimitBonus, buff.value or 0)
		elseif buff.kind == "CareSpeedMultiplier" then
			aggregate.careSpeedMultiplier = math.min(aggregate.careSpeedMultiplier, buff.value or 1)
		elseif buff.kind == "TellDurationMultiplier" then
			aggregate.tellDurationMultiplier = math.max(aggregate.tellDurationMultiplier, buff.value or 1)
		elseif buff.kind == "StartWithRibbon" then
			Util.safeCall("giveRibbon", ctx.services.DollService.giveRibbon, player)
		end
	end
	return aggregate
end

function ClassService.init(context: any)
	ctx = context

	Remotes.get(Remotes.Names.BuyClass).OnServerEvent:Connect(function(player: Player, classId: any)
		if typeof(classId) ~= "string" then
			return
		end
		Util.safeCall("buyClass", function()
			local _ok, msg = ClassService.buyClass(player, classId)
			Remotes.get(Remotes.Names.Toast):FireClient(player, msg, 3)
		end)
	end)

	Remotes.get(Remotes.Names.EquipClass).OnServerEvent:Connect(function(player: Player, classId: any)
		if typeof(classId) ~= "string" then
			return
		end
		Util.safeCall("equipClass", function()
			local _ok, msg = ClassService.equipClass(player, classId)
			Remotes.get(Remotes.Names.Toast):FireClient(player, msg, 3)
		end)
	end)

	ctx.services.DataService.onStatsChanged(function(player: Player, _stats: any)
		pushClassesData(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		pushClassesData(player)
		task.delay(3, function()
			if player.Parent then
				pushClassesData(player)
			end
		end)
	end)
end

return ClassService
