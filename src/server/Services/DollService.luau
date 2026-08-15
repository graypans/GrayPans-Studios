--!strict
-- Dolls: rigs, care chain + minigame locks, ribbon, naming, carry (R6), procedural tells, consume.
-- Marked state lives ONLY in server tables (never attributes — replication leaks to exploiters).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Util = require(Shared:WaitForChild("Util")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local CareSteps = require(Shared:WaitForChild("Defs"):WaitForChild("CareSteps")) :: any
local DollNames = require(Shared:WaitForChild("Defs"):WaitForChild("DollNames")) :: any

local DollService = {}

local PALETTES = {
	{ body = Color3.fromRGB(214, 178, 148), dress = Color3.fromRGB(120, 60, 70), hair = Color3.fromRGB(60, 40, 30) },
	{ body = Color3.fromRGB(228, 200, 178), dress = Color3.fromRGB(60, 80, 120), hair = Color3.fromRGB(220, 190, 120) },
	{ body = Color3.fromRGB(200, 170, 150), dress = Color3.fromRGB(80, 110, 70), hair = Color3.fromRGB(40, 30, 28) },
	{ body = Color3.fromRGB(222, 190, 165), dress = Color3.fromRGB(130, 100, 150), hair = Color3.fromRGB(150, 60, 40) },
	{ body = Color3.fromRGB(206, 182, 160), dress = Color3.fromRGB(140, 120, 60), hair = Color3.fromRGB(90, 70, 50) },
	{ body = Color3.fromRGB(232, 210, 190), dress = Color3.fromRGB(90, 60, 60), hair = Color3.fromRGB(230, 225, 215) },
}

type DollRecord = {
	id: string,
	model: Model,
	slot: BasePart,
	name: string,
	variant: number,
	careDone: { [string]: boolean },
	ribbonTied: boolean,
	marked: boolean,
	consumed: boolean,
	prompt: ProximityPrompt,
	pupils: { Frame },
	resting: CFrame,
	slumped: boolean,
	namedByPicker: boolean,
}

local ctx: any
local dolls: { [string]: DollRecord } = {}
local dollOrder: { string } = {}
local locks: { [string]: { player: Player, stepId: string, expiry: number } } = {}
local ribbonHolders: { [Player]: boolean } = {}
local carriers: { [Player]: { dollId: string, clone: Model } } = {}
local stepCallbacks: { (Player, string, string) -> () } = {}
local generation = 0
local unlocked = false

local function fire(name: string, ...: any)
	Remotes.get(Remotes.Names[name]):FireAllClients(...)
end

local function fireTo(player: Player, name: string, ...: any)
	Remotes.get(Remotes.Names[name]):FireClient(player, ...)
end

-- ---------- rig ----------

local function buildRig(id: string, variant: number, slot: BasePart): (Model, { Frame })
	local pal = PALETTES[((variant - 1) % #PALETTES) + 1]
	local model = Instance.new("Model")
	model.Name = "Doll"
	model:SetAttribute("DollId", id)
	model:SetAttribute("Variant", variant)
	CollectionService:AddTag(model, "Doll")

	local function dp(name: string, size: Vector3, cf: CFrame, color: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.Material = Enum.Material.SmoothPlastic
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	local base = slot.CFrame
	local root = dp("Root", Vector3.new(0.5, 0.5, 0.5), base, pal.body)
	root.Transparency = 1
	root.CanQuery = false
	model.PrimaryPart = root

	local _body = dp("Body", Vector3.new(1.6, 2.2, 1), base * CFrame.new(0, 1.1, 0), pal.dress)
	local head = dp("Head", Vector3.new(1.3, 1.3, 1.2), base * CFrame.new(0, 2.9, 0), pal.body)
	dp("Hair", Vector3.new(1.45, 0.6, 1.3), base * CFrame.new(0, 3.55, 0), pal.hair)
	dp("ArmL", Vector3.new(0.45, 1.6, 0.45), base * CFrame.new(-1.1, 1.4, 0) * CFrame.Angles(0, 0, math.rad(12)), pal.body)
	dp("ArmR", Vector3.new(0.45, 1.6, 0.45), base * CFrame.new(1.1, 1.4, 0) * CFrame.Angles(0, 0, math.rad(-12)), pal.body)
	local musicBox = dp("MusicBox", Vector3.new(1.1, 0.7, 0.9), base * CFrame.new(0, 0.4, -1), Color3.fromRGB(80, 55, 40))
	dp("Crank", Vector3.new(0.15, 0.5, 0.15), musicBox.CFrame * CFrame.new(0.7, 0.1, 0), Color3.fromRGB(180, 160, 90))

	-- face: SurfaceGui with movable pupils
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 100
	gui.Parent = head
	local pupils: { Frame } = {}
	for i, x in { 0.28, 0.62 } do
		local eye = Instance.new("Frame")
		eye.Name = "Eye" .. i
		eye.AnchorPoint = Vector2.new(0.5, 0.5)
		eye.Position = UDim2.fromScale(x, 0.42)
		eye.Size = UDim2.fromScale(0.2, 0.24)
		eye.BackgroundColor3 = Color3.fromRGB(240, 238, 232)
		eye.BorderSizePixel = 0
		eye.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = eye
		local pupil = Instance.new("Frame")
		pupil.Name = "Pupil"
		pupil.AnchorPoint = Vector2.new(0.5, 0.5)
		pupil.Position = UDim2.fromScale(0.5, 0.5)
		pupil.Size = UDim2.fromScale(0.45, 0.45)
		pupil.BackgroundColor3 = Color3.fromRGB(20, 16, 22)
		pupil.BorderSizePixel = 0
		pupil.Parent = eye
		local pc = Instance.new("UICorner")
		pc.CornerRadius = UDim.new(1, 0)
		pc.Parent = pupil
		table.insert(pupils, pupil)
	end
	-- stitched mouth
	local mouth = Instance.new("Frame")
	mouth.AnchorPoint = Vector2.new(0.5, 0.5)
	mouth.Position = UDim2.fromScale(0.45, 0.74)
	mouth.Size = UDim2.fromScale(0.34, 0.045)
	mouth.BackgroundColor3 = Color3.fromRGB(120, 70, 70)
	mouth.BorderSizePixel = 0
	mouth.Parent = gui

	-- name tag
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	billboard.Adornee = head
	billboard.Size = UDim2.new(0, 120, 0, 28)
	billboard.StudsOffset = Vector3.new(0, 1.6, 0)
	billboard.MaxDistance = 40
	billboard.AlwaysOnTop = false
	billboard.Parent = head
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.fromScale(1, 1)
	nameLabel.Font = Enum.Font.Garamond
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.fromRGB(226, 216, 196)
	nameLabel.TextStrokeTransparency = 0.6
	nameLabel.Parent = billboard

	return model, pupils
end

-- ---------- prompt state ----------

local function refreshPrompt(rec: DollRecord)
	if rec.consumed then
		rec.prompt.Enabled = false
		return
	end
	if locks[rec.id] then
		rec.prompt.Enabled = false
		return
	end
	local nextStep = DollService.nextStepFor(rec.id)
	if nextStep then
		rec.prompt.ActionText = CareSteps.byId[nextStep].name
		rec.prompt.ObjectText = rec.name
		rec.prompt.Enabled = true
	else
		rec.prompt.ObjectText = rec.name
		-- 5 steps done: ribbon (if holder) takes precedence, else pickup when unlocked
		rec.prompt.Enabled = true
		rec.prompt.ActionText = "…" -- resolved per-player at trigger; show generic
		if unlocked then
			rec.prompt.ActionText = "Pick Up / Tie Ribbon"
		elseif not rec.ribbonTied then
			rec.prompt.ActionText = "Tie Ribbon (if you have one)"
		else
			rec.prompt.Enabled = false
		end
		-- keep it enabled if ribbon still possible even when tied dolls wait for unlock
		if not unlocked and rec.ribbonTied then
			rec.prompt.Enabled = false
		end
	end
end

local function refreshAllPrompts()
	for _, rec in dolls do
		refreshPrompt(rec)
	end
end

-- ---------- naming ----------

local function applyName(rec: DollRecord, name: string)
	rec.name = name
	rec.model:SetAttribute("DisplayName", name)
	local head = rec.model:FindFirstChild("Head")
	if head then
		local tag = head:FindFirstChild("NameTag")
		local label = tag and tag:FindFirstChild("NameLabel")
		if label and label:IsA("TextLabel") then
			label.Text = name
		end
	end
	fire("DollUpdate", rec.id, { name = name })
	refreshPrompt(rec)
end

-- ---------- public API ----------

function DollService.init(context: any)
	ctx = context

	Remotes.get(Remotes.Names.MinigameDone).OnServerEvent:Connect(function(player: Player, dollId: any, stepId: any, success: any)
		if typeof(dollId) ~= "string" or typeof(stepId) ~= "string" then
			return
		end
		local lock = locks[dollId]
		if not lock or lock.player ~= player or lock.stepId ~= stepId then
			return
		end
		locks[dollId] = nil
		if success == true then
			DollService.completeStep(player, dollId, stepId)
		else
			fireTo(player, "MinigameCancel", dollId, stepId)
		end
		local rec = dolls[dollId]
		if rec then
			refreshPrompt(rec)
		end
	end)

	Remotes.get(Remotes.Names.ChooseName).OnServerEvent:Connect(function(player: Player, dollId: any, choiceIndex: any, freeText: any)
		if not Config.Features.Naming or typeof(dollId) ~= "string" then
			return
		end
		local rec = dolls[dollId]
		if not rec or rec.consumed or rec.namedByPicker then
			return
		end
		if typeof(choiceIndex) == "number" and DollNames[choiceIndex] then
			rec.namedByPicker = true
			applyName(rec, DollNames[choiceIndex])
		elseif Config.Features.FreeTextNames and typeof(freeText) == "string" then
			local trimmed = freeText:gsub("^%s+", ""):gsub("%s+$", ""):sub(1, 20)
			if #trimmed < 2 then
				return
			end
			task.spawn(function()
				local okFilter, result = pcall(function()
					return TextService:FilterStringAsync(trimmed, player.UserId)
				end)
				if not okFilter then
					return
				end
				local okGet, filtered = pcall(function()
					return result:GetNonChatStringForBroadcastAsync()
				end)
				if okGet and typeof(filtered) == "string" and #filtered >= 2 and not filtered:find("^#+$") then
					rec.namedByPicker = true
					applyName(rec, filtered)
				end
			end)
		end
	end)

	Remotes.get(Remotes.Names.DropDoll).OnServerEvent:Connect(function(player: Player)
		DollService.drop(player)
	end)

	-- leave/reset glue for carriers + ribbon holders + locks
	Players.PlayerRemoving:Connect(function(player)
		DollService.drop(player)
		ribbonHolders[player] = nil
		for dollId, lock in locks do
			if lock.player == player then
				locks[dollId] = nil
				local rec = dolls[dollId]
				if rec then
					refreshPrompt(rec)
				end
			end
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char: Model)
			local humanoid = char:WaitForChild("Humanoid", 10)
			if humanoid and humanoid:IsA("Humanoid") then
				humanoid.Died:Connect(function()
					DollService.drop(player)
					ribbonHolders[player] = nil
				end)
			end
		end)
	end)

	-- lock expiry sweeper (R2)
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for dollId, lock in locks do
				if now > lock.expiry then
					locks[dollId] = nil
					Util.safeCall("minigameExpire", function()
						fireTo(lock.player, "MinigameCancel", dollId, lock.stepId)
					end)
					local rec = dolls[dollId]
					if rec then
						refreshPrompt(rec)
					end
				end
			end
		end
	end)
end

-- Wire ribbon spool + doll prompts against the manifest (called once from bootstrap after build)
function DollService.wireWorld(manifest: any)
	if manifest.ribbonPrompt then
		manifest.ribbonPrompt.Triggered:Connect(function(player: Player)
			ribbonHolders[player] = true
			fireTo(player, "Toast", "You take a length of silver ribbon.", 3)
		end)
	end
end

function DollService.spawnShift(shiftParams: any, names: { string }, markedIndex: number, rng: any): { any }
	generation += 1
	DollService.clearShift()
	unlocked = false
	local manifest = ctx.manifest
	local infos = {}
	for i = 1, shiftParams.dollCount do
		local slot = manifest.benchSlots[i]
		if not slot then
			break
		end
		local id = ("doll_%d_%d"):format(generation, i)
		local variant = rng:NextInteger(1, #PALETTES)
		local model, pupils = buildRig(id, variant, slot)
		model.Parent = manifest.root
		local p = Instance.new("ProximityPrompt")
		p.RequiresLineOfSight = false
		p.MaxActivationDistance = Config.Care.PromptDistance
		p.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
		local body = model:FindFirstChild("Body")
		p.Parent = body or model
		local rec: DollRecord = {
			id = id,
			model = model,
			slot = slot,
			name = names[i] or ("Doll #" .. i),
			variant = variant,
			careDone = {},
			ribbonTied = false,
			marked = (i == markedIndex),
			consumed = false,
			prompt = p,
			pupils = pupils,
			resting = slot.CFrame,
			slumped = false,
			namedByPicker = false,
		}
		dolls[id] = rec
		table.insert(dollOrder, id)
		applyName(rec, rec.name)
		p.Triggered:Connect(function(player: Player)
			DollService.onPromptTriggered(player, id)
		end)
		refreshPrompt(rec)
		table.insert(infos, { id = id, name = rec.name, variant = variant })
	end
	return infos
end

function DollService.onPromptTriggered(player: Player, dollId: string)
	local rec = dolls[dollId]
	if not rec or rec.consumed or locks[dollId] then
		return
	end
	local nextStep = DollService.nextStepFor(dollId)
	if nextStep then
		locks[dollId] = { player = player, stepId = nextStep, expiry = os.clock() + Config.Care.MinigameSeconds }
		refreshPrompt(rec)
		fireTo(player, "MinigameStart", dollId, nextStep, math.random(1, 2 ^ 30))
		return
	end
	-- 5 steps done: ribbon first if held, else pickup when unlocked
	if ribbonHolders[player] and not rec.ribbonTied then
		DollService.tieRibbon(player, dollId)
		return
	end
	if unlocked then
		DollService.pickup(player, dollId)
	end
end

function DollService.nextStepFor(dollId: string): string?
	local rec = dolls[dollId]
	if not rec then
		return nil
	end
	for _, step in CareSteps.list do
		if not rec.careDone[step.id] then
			return step.id
		end
	end
	return nil
end

function DollService.completeStep(player: Player, dollId: string, stepId: string)
	local rec = dolls[dollId]
	if not rec or rec.consumed then
		return
	end
	if DollService.nextStepFor(dollId) ~= stepId then
		return
	end
	rec.careDone[stepId] = true
	local doneList = {}
	for id in rec.careDone do
		table.insert(doneList, id)
	end
	local allDone = DollService.nextStepFor(dollId) == nil
	fire("DollUpdate", dollId, { careDone = doneList, done = allDone })
	refreshPrompt(rec)
	for _, cb in stepCallbacks do
		Util.safeCall("stepCallback", cb, player, dollId, stepId)
	end
end

function DollService.allListedCareDone(): boolean
	for _, rec in dolls do
		if not rec.consumed and DollService.nextStepFor(rec.id) ~= nil then
			return false
		end
	end
	return next(dolls) ~= nil
end

function DollService.tieRibbon(player: Player, dollId: string): boolean
	local rec = dolls[dollId]
	if not rec or rec.consumed or rec.ribbonTied then
		return false
	end
	if not ribbonHolders[player] then
		return false
	end
	if DollService.nextStepFor(dollId) ~= nil then
		return false
	end
	ribbonHolders[player] = nil
	rec.ribbonTied = true
	-- small visible ribbon on the doll
	local body = rec.model:FindFirstChild("Body")
	if body and body:IsA("BasePart") then
		local ribbon = Instance.new("Part")
		ribbon.Name = "Ribbon"
		ribbon.Anchored = true
		ribbon.CanCollide = false
		ribbon.Material = Enum.Material.Neon
		ribbon.Color = Color3.fromRGB(210, 215, 225)
		ribbon.Size = Vector3.new(1.7, 0.25, 1.05)
		ribbon.CFrame = body.CFrame * CFrame.new(0, 0.4, 0)
		ribbon.Parent = rec.model
	end
	fireTo(player, "DollUpdate", dollId, { ribbon = true })
	fireTo(player, "Toast", ("You tie the silver ribbon around %s."):format(rec.name), 3)
	refreshPrompt(rec)
	return true
end

function DollService.hasRibbon(dollId: string): boolean
	local rec = dolls[dollId]
	return rec ~= nil and rec.ribbonTied
end

function DollService.setUnlocked(state: boolean)
	unlocked = state
	refreshAllPrompts()
end

function DollService.pickup(player: Player, dollId: string): boolean
	local rec = dolls[dollId]
	if not rec or rec.consumed or carriers[player] then
		return false
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return false
	end
	-- hide original
	for _, d in rec.model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 1
		elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
			(d :: any).Enabled = false
		end
	end
	rec.prompt.Enabled = false
	-- visual clone, zero physics (R6)
	local clone = rec.model:Clone()
	clone.Name = "CarriedDoll"
	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = if d.Name == "Root" then 1 else 0
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("ProximityPrompt") then
			d:Destroy()
		elseif d:IsA("SurfaceGui") then
			d.Enabled = true
		elseif d:IsA("BillboardGui") then
			d.Enabled = false
		end
	end
	local cloneRoot = clone.PrimaryPart
	if not cloneRoot then
		clone:Destroy()
		return false
	end
	-- weld every part to the clone root, then root to carrier
	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") and d ~= cloneRoot then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = cloneRoot
			weld.Part1 = d
			weld.Parent = d
		end
	end
	clone:PivotTo(hrp.CFrame * CFrame.new(0, 0, -2.2))
	local carryWeld = Instance.new("WeldConstraint")
	carryWeld.Part0 = hrp
	carryWeld.Part1 = cloneRoot
	carryWeld.Parent = cloneRoot
	clone.Parent = char
	carriers[player] = { dollId = dollId, clone = clone }
	fireTo(player, "Toast", ("You pick up %s. Carry them to the Banish Box… if you're sure."):format(rec.name), 4)
	return true
end

function DollService.drop(player: Player)
	local carry = carriers[player]
	if not carry then
		return
	end
	carriers[player] = nil
	Util.safeCall("destroyCarryClone", function()
		carry.clone:Destroy()
	end)
	local rec = dolls[carry.dollId]
	if rec and not rec.consumed then
		for _, d in rec.model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Transparency = if d.Name == "Root" then 1 else 0
			elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
				(d :: any).Enabled = true
			end
		end
		refreshPrompt(rec)
	end
end

function DollService.getCarried(player: Player): string?
	local carry = carriers[player]
	return carry and carry.dollId or nil
end

function DollService.isMarked(dollId: string): boolean
	local rec = dolls[dollId]
	return rec ~= nil and rec.marked
end

function DollService.getMarkedId(): string?
	for id, rec in dolls do
		if rec.marked and not rec.consumed then
			return id
		end
	end
	return nil
end

function DollService.getDisplayName(dollId: string): string
	local rec = dolls[dollId]
	return rec and rec.name or "???"
end

function DollService.getDollIds(): { string }
	local out = {}
	for _, id in dollOrder do
		if dolls[id] and not dolls[id].consumed then
			table.insert(out, id)
		end
	end
	return out
end

function DollService.getModel(dollId: string): Model?
	local rec = dolls[dollId]
	return rec and rec.model or nil
end

function DollService.hasActiveLock(): boolean
	return next(locks) ~= nil
end

function DollService.consume(dollId: string)
	local rec = dolls[dollId]
	if not rec or rec.consumed then
		return
	end
	rec.consumed = true
	rec.prompt.Enabled = false
	-- sink + fade
	local parts = {}
	for _, d in rec.model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	for _, p in parts do
		TweenService:Create(p, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Transparency = 1,
			CFrame = p.CFrame * CFrame.new(0, -2, 0),
		}):Play()
	end
	task.delay(2, function()
		Util.safeCall("consumeDestroy", function()
			rec.model:Destroy()
		end)
	end)
end

function DollService.onStepCompleted(fn: (Player, string, string) -> ())
	table.insert(stepCallbacks, fn)
end

-- ---------- tells (procedural motion) ----------

local function tweenPart(inst: Instance?, time: number, props: { [string]: any })
	if inst and inst:IsA("BasePart") then
		TweenService:Create(inst, TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), props):Play()
	end
end

function DollService.performTell(dollId: string, tellId: string): boolean
	local rec = dolls[dollId]
	if not rec or rec.consumed then
		return false
	end
	local model = rec.model
	local head = model:FindFirstChild("Head")

	if tellId == "HeadTurn" then
		if not (head and head:IsA("BasePart")) then
			return false
		end
		local original = head.CFrame
		tweenPart(head, 1.2, { CFrame = original * CFrame.Angles(0, math.rad(22), 0) })
		task.delay(2.4, function()
			tweenPart(model:FindFirstChild("Head"), 1.2, { CFrame = original })
		end)
		return true
	elseif tellId == "EyesFollow" then
		local target: BasePart? = nil
		local best = math.huge
		for _, player in Players:GetPlayers() do
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if hrp and hrp:IsA("BasePart") and head and head:IsA("BasePart") then
				local d = (hrp.Position - head.Position).Magnitude
				if d < best then
					best = d
					target = hrp
				end
			end
		end
		if not target or not (head and head:IsA("BasePart")) then
			return false
		end
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < 4 do
				local h = model:FindFirstChild("Head")
				if not (h and h:IsA("BasePart")) or rec.consumed then
					break
				end
				local dir = h.CFrame:PointToObjectSpace(target.Position)
				local px = math.clamp(0.5 + dir.X * 0.06, 0.2, 0.8)
				local py = math.clamp(0.5 - dir.Y * 0.05, 0.25, 0.75)
				for _, pupil in rec.pupils do
					pupil.Position = UDim2.fromScale(px, py)
				end
				task.wait(0.1)
			end
			for _, pupil in rec.pupils do
				pupil.Position = UDim2.fromScale(0.5, 0.5)
			end
		end)
		return true
	elseif tellId == "Scoot" then
		local offset = CFrame.new((math.random() - 0.5) * 3, 0, (math.random() - 0.5) * 1.2)
		rec.resting = rec.resting * offset
		model:PivotTo(rec.resting)
		return true
	elseif tellId == "MusicBoxTurn" then
		local crank = model:FindFirstChild("Crank")
		if not (crank and crank:IsA("BasePart")) then
			return false
		end
		task.spawn(function()
			for _ = 1, 10 do
				local c = model:FindFirstChild("Crank")
				if not (c and c:IsA("BasePart")) or rec.consumed then
					break
				end
				c.CFrame = c.CFrame * CFrame.Angles(math.rad(36), 0, 0)
				task.wait(0.5)
			end
		end)
		return true
	elseif tellId == "Slump" then
		local body = model:FindFirstChild("Body")
		if not (body and body:IsA("BasePart")) then
			return false
		end
		local angle = if rec.slumped then 0 else math.rad(12)
		rec.slumped = not rec.slumped
		tweenPart(body, 1.5, { CFrame = rec.resting * CFrame.new(0, 1.1, 0) * CFrame.Angles(0, 0, angle) })
		return true
	elseif tellId == "StitchMark" then
		local arm = model:FindFirstChild("ArmL")
		if not (arm and arm:IsA("BasePart")) then
			return false
		end
		if arm:FindFirstChild("StitchGui") then
			return false
		end
		local gui = Instance.new("SurfaceGui")
		gui.Name = "StitchGui"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 100
		gui.Parent = arm
		for i = 1, 4 do
			local seg = Instance.new("Frame")
			seg.AnchorPoint = Vector2.new(0.5, 0.5)
			seg.Position = UDim2.fromScale(0.5 + (if i % 2 == 0 then 0.12 else -0.12), 0.2 + i * 0.15)
			seg.Size = UDim2.fromScale(0.4, 0.06)
			seg.Rotation = if i % 2 == 0 then 25 else -25
			seg.BackgroundColor3 = Color3.fromRGB(70, 30, 40)
			seg.BorderSizePixel = 0
			seg.Parent = gui
		end
		return true
	end
	return false
end

function DollService.clearShift()
	for _, rec in dolls do
		Util.safeCall("clearDoll", function()
			rec.model:Destroy()
		end)
	end
	dolls = {}
	dollOrder = {}
	locks = {}
	for player in carriers do
		DollService.drop(player)
	end
	carriers = {}
	ribbonHolders = {}
	unlocked = false
end

return DollService
