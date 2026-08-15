--!strict
-- Journal / quests: tracks progress toward Defs/Quests.luau and pays out coin rewards. Progress
-- is derived at read-time from DataService's stats via Logic/QuestProgress -- QuestService holds
-- no separate "quest progress" cache, it's a thin authority layer over DataService.
--
-- Also owns: the hidden lobby easter-egg triggers, and (behind Config.Features.TutorialGate)
-- setting tutorialDone the moment a player's first shift is won.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Util = require(Shared:WaitForChild("Util")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local Quests = require(Shared:WaitForChild("Defs"):WaitForChild("Quests")) :: any
local QuestProgress = require(Shared:WaitForChild("Logic"):WaitForChild("QuestProgress")) :: any

local QuestService = {}

local ctx: any
local stillnessDwell: { [Player]: number } = {}

local function broadcastStats(player: Player)
	local stats = ctx.services.DataService.getStats(player)
	Remotes.get(Remotes.Names.PlayerStats):FireClient(player, stats)
end

-- ---------- claim ----------

function QuestService.claim(player: Player, questId: string): boolean
	local quest = Quests.byId[questId]
	if not quest then
		return false
	end
	local DataService = ctx.services.DataService
	local stats = DataService.getStats(player)
	if stats.claimedQuestIds[questId] then
		Remotes.get(Remotes.Names.Toast):FireClient(player, "Already claimed.", 3)
		return false
	end
	if not QuestProgress.isComplete(stats, quest) then
		return false -- client shouldn't have shown Claim yet; ignore silently
	end
	if not DataService.markQuestClaimed(player, questId) then
		return false -- race: another claim beat us to it
	end
	DataService.addCoins(player, quest.coinReward)
	Remotes.get(Remotes.Names.Toast):FireClient(
		player,
		("Journal complete: %s (+%d coins)"):format(quest.title, quest.coinReward),
		4
	)
	broadcastStats(player)
	return true
end

-- ---------- easter eggs ----------
-- Built by THIS service, independently of MapBuilder.luau, and parented under ctx.manifest.root.
-- Safe to do because MapBuilder.build() always runs BEFORE any service's init() (server
-- bootstrap order per docs/INTERFACES.md), so ctx.manifest is fully populated here.

local function makeEggPrompt(part: BasePart, actionText: string, objectText: string, onTrigger: (Player) -> ())
	CollectionService:AddTag(part, "QuestTrigger")
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = Config.Care.PromptDistance
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Parent = part
	prompt.Triggered:Connect(function(player: Player)
		Util.safeCall("eggTrigger", onTrigger, player)
	end)
end

local function grantEggFlag(player: Player, questId: string, flavorLine: string)
	local DataService = ctx.services.DataService
	local stats = DataService.getStats(player)
	if stats.questFlags[questId] then
		return -- already found; no repeat toast
	end
	DataService.setQuestFlag(player, questId)
	Remotes.get(Remotes.Names.Toast):FireClient(player, flavorLine, 5)
	broadcastStats(player)
end

local function wireEasterEggs()
	local manifest = ctx.manifest
	local anchor = manifest.chalkboard or manifest.lobbySpawn
	if not anchor then
		return
	end

	-- Egg 1: a floorboard near the chalkboard, deliberately unremarkable-looking
	Util.safeCall("eggFloorboard", function()
		local board = Instance.new("Part")
		board.Name = "LooseFloorboard"
		board.Anchored = true
		board.CanCollide = false
		board.Material = Enum.Material.WoodPlanks
		board.Color = Color3.fromRGB(70, 55, 45)
		board.Size = Vector3.new(2, 0.15, 1)
		board.CFrame = anchor.CFrame * CFrame.new(-4, -0.9, 2.5) -- DEFAULT offset; retune once the real lobby geometry exists
		board.Parent = manifest.root
		makeEggPrompt(board, "Pry It Up", "Loose Floorboard", function(player: Player)
			grantEggFlag(player, "EggFloorboard", "Something glints under the floorboard. You tuck it away.")
		end)
	end)

	-- Egg 2: a folded note near the ribbon spool (thematic tie-in to the ribbon's own hidden-6th-step dread)
	Util.safeCall("eggNote", function()
		local spot = manifest.ribbonSpool or manifest.ledgerDesk or anchor
		local note = Instance.new("Part")
		note.Name = "HiddenNote"
		note.Anchored = true
		note.CanCollide = false
		note.Material = Enum.Material.SmoothPlastic
		note.Color = Color3.fromRGB(224, 214, 180)
		note.Size = Vector3.new(0.6, 0.05, 0.8)
		note.CFrame = spot.CFrame * CFrame.new(1.2, 0.05, -0.3) * CFrame.Angles(0, math.rad(15), 0) -- DEFAULT offset
		note.Parent = manifest.root
		makeEggPrompt(note, "Read the Note", "Folded Paper", function(player: Player)
			grantEggFlag(player, "EggNote", "\"Count the stitches before you count the hours. — The Dollmaker\"")
		end)
	end)

	-- Egg 3: stand still in an odd, unmarked corner of the lobby for a while
	Util.safeCall("eggStillnessSetup", function()
		local spotPart = Instance.new("Part")
		spotPart.Name = "StillnessSpot"
		spotPart.Anchored = true
		spotPart.CanCollide = false
		spotPart.CanQuery = false
		spotPart.Transparency = 1
		spotPart.Size = Vector3.new(4, 1, 4)
		spotPart.CFrame = anchor.CFrame * CFrame.new(6, 0, -5) -- DEFAULT offset
		spotPart.Parent = manifest.root
		CollectionService:AddTag(spotPart, "QuestTrigger")

		task.spawn(function()
			while true do
				task.wait(1 / Config.Quests.StillnessPollHz)
				local standing: { [Player]: boolean } = {}
				local parts = workspace:GetPartBoundsInBox(
					CFrame.new(spotPart.Position + Vector3.new(0, 2.5, 0)),
					Vector3.new(6, 6, 6)
				)
				for _, part in parts do
					local char = part:FindFirstAncestorOfClass("Model")
					local player = char and Players:GetPlayerFromCharacter(char)
					if player then
						standing[player] = true
					end
				end
				for _, player in Players:GetPlayers() do
					if standing[player] then
						local dwell = (stillnessDwell[player] or 0) + (1 / Config.Quests.StillnessPollHz)
						stillnessDwell[player] = dwell
						if dwell >= Config.Quests.StillnessSeconds then
							grantEggFlag(player, "EggStillness", "You stood still long enough for something to notice you back.")
							stillnessDwell[player] = 0
						end
					else
						stillnessDwell[player] = 0
					end
				end
			end
		end)
	end)
end

-- ---------- init ----------

function QuestService.init(context: any)
	ctx = context

	ctx.services.DataService.onStatsChanged(function(player: Player, _stats: any)
		broadcastStats(player)
	end)
	Players.PlayerAdded:Connect(function(player)
		task.delay(2, function()
			if player.Parent then
				broadcastStats(player)
			end
		end)
		stillnessDwell[player] = 0
	end)
	Players.PlayerRemoving:Connect(function(player)
		stillnessDwell[player] = nil
	end)

	if Config.Features.TutorialGate then
		Util.safeCall("wireShiftClearedHook", function()
			ctx.services.ShiftManager.onShiftCleared(function(participants: { Player }, _clearedShift: number)
				for _, player in participants do
					if player.Parent then
						ctx.services.DataService.setTutorialDone(player)
					end
				end
			end)
		end)
	end

	if Config.Features.Quests then
		Util.safeCall("wireRibbonHook", function()
			ctx.services.DollService.onRibbonTied(function(player: Player, _dollId: string)
				ctx.services.DataService.addRibbonTied(player, 1)
			end)
		end)

		Remotes.get(Remotes.Names.ClaimQuest).OnServerEvent:Connect(function(player: Player, questId: any)
			if typeof(questId) ~= "string" then
				return
			end
			QuestService.claim(player, questId)
		end)

		wireEasterEggs()
	end
end

return QuestService
