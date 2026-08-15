--!strict
-- Haunt scheduler + world-scope event implementations. Every event pcall'd; per-event kill switches.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Util = require(Shared:WaitForChild("Util")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local SoundKit = require(Shared:WaitForChild("SoundKit")) :: any
local Haunts = require(Shared:WaitForChild("Defs"):WaitForChild("Haunts")) :: any
local Draw = require(Shared:WaitForChild("Logic"):WaitForChild("Draw")) :: any

local HauntService = {}

local ctx: any
local generation = 0
local currentTier = 0
local lastFired: { [string]: number } = {}
local participantsGetter: (() -> { Player })? = nil

local function randomParticipant(rng: any): Player?
	local list = if participantsGetter then participantsGetter() else Players:GetPlayers()
	return Draw.one(rng, list)
end

-- ---------- world event implementations ----------

local events: { [string]: (rng: any) -> () } = {}

events.BenchRattle = function(_rng)
	local bench = ctx.manifest.workbench
	if not bench then
		return
	end
	local original = bench.CFrame
	SoundKit.play("BenchRattle", bench)
	task.spawn(function()
		for _ = 1, 10 do
			bench.CFrame = original * CFrame.new((math.random() - 0.5) * 0.3, 0, (math.random() - 0.5) * 0.3)
			task.wait(0.12)
		end
		bench.CFrame = original
	end)
end

events.DoorCreakSlam = function(rng)
	local door = Draw.one(rng, ctx.manifest.hauntDoors)
	if not door or not door.PrimaryPart then
		return
	end
	local hinge = door.PrimaryPart
	local original = hinge.CFrame
	local opened = original * CFrame.Angles(0, math.rad(70), 0)
	local panel = door:FindFirstChild("Panel")
	local function setDoor(cf: CFrame)
		hinge.CFrame = cf
		if panel and panel:IsA("BasePart") then
			panel.CFrame = cf * CFrame.new(0, 0, 2)
		end
	end
	task.spawn(function()
		for i = 1, 30 do
			setDoor(original:Lerp(opened, i / 30))
			task.wait(0.1)
		end
		task.wait(0.4)
		SoundKit.play("DoorSlam", hinge)
		setDoor(original)
	end)
end

events.MusicBoxSwell = function(rng)
	local DollService = ctx.services.DollService
	local dollId = Draw.one(rng, DollService.getDollIds())
	if not dollId then
		return
	end
	DollService.performTell(dollId, "MusicBoxTurn")
	local model = DollService.getModel(dollId)
	local musicBox = model and model:FindFirstChild("MusicBox")
	if musicBox then
		local sound = SoundKit.attach("MusicBoxLoop", musicBox)
		if sound then
			sound:Play()
			task.delay(6, function()
				sound:Destroy()
			end)
		end
	end
end

events.SilhouetteDoorway = function(rng)
	local door = Draw.one(rng, ctx.manifest.hauntDoors)
	if not door or not door.PrimaryPart then
		return
	end
	local target = randomParticipant(rng)
	local lookAt = if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
		then (target.Character:FindFirstChild("HumanoidRootPart") :: BasePart).Position
		else door.PrimaryPart.Position + door.PrimaryPart.CFrame.LookVector * 10
	local base = door.PrimaryPart.Position
	local figure = Instance.new("Model")
	figure.Name = "Silhouette"
	local function fp(size: Vector3, offset: Vector3)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Color3.fromRGB(8, 6, 10)
		p.Size = size
		p.CFrame = CFrame.lookAt(Vector3.new(base.X, 0, base.Z) + Vector3.new(0, offset.Y, 0), Vector3.new(lookAt.X, offset.Y, lookAt.Z)) * CFrame.new(offset.X, 0, offset.Z)
		p.Parent = figure
	end
	fp(Vector3.new(1.6, 4.4, 0.9), Vector3.new(0, 3.4, 0)) -- body
	fp(Vector3.new(1.1, 1.1, 0.9), Vector3.new(0, 6.2, 0)) -- head
	figure.Parent = ctx.manifest.root
	task.delay(1.2, function()
		figure:Destroy()
	end)
end

events.WindowFigure = function(rng)
	local pane = Draw.one(rng, ctx.manifest.windowPanes)
	if not pane then
		return
	end
	local figure = Instance.new("Part")
	figure.Anchored = true
	figure.CanCollide = false
	figure.CanQuery = false
	figure.Material = Enum.Material.SmoothPlastic
	figure.Color = Color3.fromRGB(5, 4, 8)
	figure.Size = Vector3.new(2, 5, 0.4)
	figure.CFrame = pane.CFrame * CFrame.new(0, -0.5, -1)
	figure.Parent = ctx.manifest.root
	task.delay(1.5, function()
		figure:Destroy()
	end)
end

events.DollHeadSnap = function(rng)
	local DollService = ctx.services.DollService
	local dollId = Draw.one(rng, DollService.getDollIds())
	if dollId then
		DollService.performTell(dollId, "HeadTurn")
	end
end

events.LightsOutBeat = function(_rng)
	local lamps = ctx.manifest.lamps
	SoundKit.play("LightsOut")
	local lights: { Light } = {}
	for _, lamp in lamps do
		local light = lamp:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = false
			table.insert(lights, light)
		end
	end
	task.delay(2.5, function()
		for _, light in lights do
			light.Enabled = true
		end
	end)
end

-- ---------- scheduler ----------

function HauntService.init(context: any)
	ctx = context
end

function HauntService.setParticipantsGetter(fn: () -> { Player })
	participantsGetter = fn
end

function HauntService.setTier(tier: number)
	currentTier = tier
end

function HauntService.force(hauntId: string, rng: any)
	local def = Haunts.byId[hauntId]
	if not def then
		return
	end
	lastFired[hauntId] = os.clock()
	if def.scope == "world" then
		local impl = events[hauntId]
		if impl then
			Util.safeCall("haunt:" .. hauntId, impl, rng)
		end
	else
		if hauntId == "Taken" then
			if not Config.Features.Taken then
				return
			end
			local list = if participantsGetter then participantsGetter() else Players:GetPlayers()
			if #list <= 1 then
				return -- never solo
			end
		end
		local target = randomParticipant(rng)
		if target then
			Remotes.get(Remotes.Names.HauntFired):FireClient(target, hauntId, {})
		end
	end
end

function HauntService.startShift(rng: any)
	generation += 1
	local myGen = generation
	lastFired = {}
	task.spawn(function()
		while generation == myGen do
			task.wait(Config.Haunts.MinSecondsBetween + rng:NextNumber() * 15)
			if generation ~= myGen then
				break
			end
			if not Config.Haunts.Enabled or currentTier < 1 then
				continue
			end
			if ctx.services.DollService.hasActiveLock() then
				continue
			end
			local now = os.clock()
			local candidates = {}
			for _, def in Haunts.list do
				local enabled = Config.Haunts.Events[def.id] ~= false
				local offCooldown = (now - (lastFired[def.id] or -math.huge)) >= def.cooldown
				if enabled and offCooldown and def.tier <= currentTier then
					table.insert(candidates, { id = def.id, weight = def.weight })
				end
			end
			local pick = Draw.weighted(rng, candidates)
			if pick then
				HauntService.force(pick, rng)
			end
		end
	end)
end

function HauntService.stopShift()
	generation += 1
	currentTier = 0
end

return HauntService
