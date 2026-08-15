--!strict
-- Glyph tokens, the Spirit Compass tool, and the SHARED found-set + ledger slots.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Util = require(Shared:WaitForChild("Util")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local Glyphs = require(Shared:WaitForChild("Defs"):WaitForChild("Glyphs")) :: any
local Draw = require(Shared:WaitForChild("Logic"):WaitForChild("Draw")) :: any

local GlyphService = {}

local ctx: any
local tokens: { [string]: { part: BasePart, glyphId: string, targetValue: Vector3Value } } = {}
local found: { string } = {}
local slots: { [number]: string? } = {}
local detectorTool: Tool? = nil
local generation = 0

local function broadcast(glyphId: string?, finder: string?)
	local slotsCopy: { any } = {}
	for i = 1, 3 do
		slotsCopy[i] = slots[i] or false -- false travels; nil holes don't
	end
	Remotes.get(Remotes.Names.GlyphFound):FireAllClients(glyphId, {
		found = table.clone(found),
		slots = slotsCopy,
		finder = finder,
	})
end

local function buildDetector(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Spirit Compass"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.8, 0.5, 1.4)
	handle.Color = Color3.fromRGB(120, 96, 60)
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Parent = tool
	local needle = Instance.new("Part")
	needle.Name = "Needle"
	needle.Size = Vector3.new(0.1, 0.1, 0.9)
	needle.Color = Color3.fromRGB(200, 205, 215)
	needle.Material = Enum.Material.Neon
	needle.Massless = true
	needle.CanCollide = false
	needle.CFrame = handle.CFrame * CFrame.new(0, 0.35, 0)
	needle.Parent = tool
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = needle
	weld.Parent = needle
	local light = Instance.new("PointLight")
	light.Name = "GlowLight"
	light.Color = Color3.fromRGB(180, 120, 255)
	light.Brightness = 0
	light.Range = 8
	light.Parent = handle
	local targets = Instance.new("Folder")
	targets.Name = "GlyphTargets"
	targets.Parent = tool
	return tool
end

local function placeDetectorAtRack()
	local tool = detectorTool
	if not tool then
		return
	end
	local rack = ctx.manifest.detectorRack
	if not rack then
		return
	end
	tool.Parent = workspace
	local handle = tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		handle.CFrame = rack.CFrame * CFrame.new(0, 3.6, 0)
		handle.Anchored = true
		-- prompt to take it (tools on the ground need touch; prompt is mobile-friendlier)
		if not handle:FindFirstChildOfClass("ProximityPrompt") then
			local p = Instance.new("ProximityPrompt")
			p.ActionText = "Take Spirit Compass"
			p.ObjectText = "Detector"
			p.RequiresLineOfSight = false
			p.MaxActivationDistance = Config.Care.PromptDistance
			p.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
			p.Parent = handle
			p.Triggered:Connect(function(player: Player)
				local t = detectorTool
				local h = t and t:FindFirstChild("Handle")
				if t and h and h:IsA("BasePart") and t.Parent == workspace then
					h.Anchored = false
					p.Enabled = false
					local backpack = player:FindFirstChildOfClass("Backpack")
					if backpack then
						t.Parent = backpack
						local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
						if humanoid then
							humanoid:EquipTool(t)
						end
					end
				end
			end)
		else
			local p = handle:FindFirstChildOfClass("ProximityPrompt")
			if p then
				p.Enabled = true
			end
		end
	end
end

function GlyphService.init(context: any)
	ctx = context
	if Config.Features.Detector then
		detectorTool = buildDetector()
		placeDetectorAtRack()
	end

	Remotes.get(Remotes.Names.SlotGlyph).OnServerEvent:Connect(function(_player: Player, slotIndex: any, glyphId: any)
		if typeof(slotIndex) ~= "number" or slotIndex < 1 or slotIndex > 3 or slotIndex % 1 ~= 0 then
			return
		end
		if glyphId == nil then
			slots[slotIndex] = nil
			broadcast(nil, nil)
			Util.safeCall("shiftObjectiveRefresh", function()
				ctx.services.ShiftManager.refreshObjective()
			end)
			return
		end
		if typeof(glyphId) ~= "string" or not table.find(found, glyphId) then
			return
		end
		slots[slotIndex] = glyphId
		broadcast(nil, nil)
		-- B2 fix: slotting into (or clearing from) the ledger can complete/break the spirit match.
		Util.safeCall("shiftObjectiveRefresh", function()
			ctx.services.ShiftManager.refreshObjective()
		end)
	end)

	-- re-rack the detector if its carrier leaves/dies
	Players.PlayerRemoving:Connect(function(player: Player)
		local tool = detectorTool
		if tool and (tool:IsDescendantOf(player) or (player.Character and tool:IsDescendantOf(player.Character))) then
			task.defer(placeDetectorAtRack)
		end
	end)
end

function GlyphService.startShift(spiritCode: { string }, rng: any)
	generation += 1
	GlyphService.stopShift()
	local myGen = generation
	local spawnParts = Draw.sample(rng, ctx.manifest.glyphSpawns, #spiritCode)
	for i, glyphId in spiritCode do
		local marker = spawnParts[i]
		if not marker then
			break
		end
		local tokenId = ("glyph_%d_%d"):format(myGen, i)
		local token = Instance.new("Part")
		token.Name = "GlyphToken"
		token.Shape = Enum.PartType.Ball
		token.Size = Vector3.new(0.9, 0.9, 0.9)
		token.Color = Color3.fromRGB(40, 30, 55)
		token.Material = Enum.Material.Neon
		token.Anchored = true
		token.CanCollide = false
		token.CFrame = marker.CFrame
		CollectionService:AddTag(token, "GlyphToken")
		token:SetAttribute("GlyphId", glyphId)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(160, 110, 240)
		light.Brightness = 0.5
		light.Range = 6
		light.Parent = token
		TweenService:Create(
			token,
			TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ CFrame = marker.CFrame * CFrame.new(0, 0.8, 0) }
		):Play()
		local p = Instance.new("ProximityPrompt")
		p.ActionText = "Collect Glyph"
		p.ObjectText = "Strange Mark"
		p.RequiresLineOfSight = false
		p.MaxActivationDistance = Config.Glyphs.CollectDistance
		p.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
		p.Parent = token
		token.Parent = ctx.manifest.root

		local targetValue = Instance.new("Vector3Value")
		targetValue.Name = tokenId
		targetValue.Value = marker.CFrame.Position
		local tool = detectorTool
		if tool then
			local folder = tool:FindFirstChild("GlyphTargets")
			if folder then
				targetValue.Parent = folder
			end
		end

		tokens[tokenId] = { part = token, glyphId = glyphId, targetValue = targetValue }
		p.Triggered:Connect(function(player: Player)
			GlyphService.collect(player, tokenId)
		end)
	end
end

function GlyphService.collect(player: Player, tokenId: string)
	local token = tokens[tokenId]
	if not token then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (hrp and hrp:IsA("BasePart")) then
		return
	end
	if (hrp.Position - token.part.Position).Magnitude > Config.Glyphs.CollectDistance + 4 then
		return
	end
	tokens[tokenId] = nil
	Util.safeCall("destroyToken", function()
		token.part:Destroy()
		token.targetValue:Destroy()
	end)
	if not table.find(found, token.glyphId) then
		table.insert(found, token.glyphId)
	end
	local glyphName = Glyphs.byId[token.glyphId] and Glyphs.byId[token.glyphId].name or token.glyphId
	broadcast(token.glyphId, player.DisplayName)
	Remotes.get(Remotes.Names.Toast):FireAllClients(("%s found a glyph: %s"):format(player.DisplayName, glyphName), 4)
	-- B2 fix: a glyph collect can flip the HUD objective (care -> glyphs -> ledger), but nothing
	-- told ShiftManager to recompute + rebroadcast it.
	Util.safeCall("shiftObjectiveRefresh", function()
		ctx.services.ShiftManager.refreshObjective()
	end)
end

function GlyphService.getSlots(): { [number]: string? }
	return table.clone(slots)
end

function GlyphService.getFound(): { string }
	return table.clone(found)
end

function GlyphService.stopShift()
	for _, token in tokens do
		Util.safeCall("stopToken", function()
			token.part:Destroy()
			token.targetValue:Destroy()
		end)
	end
	tokens = {}
	found = {}
	slots = {}
	broadcast(nil, nil)
	placeDetectorAtRack()
end

return GlyphService
