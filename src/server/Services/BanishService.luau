--!strict
-- The Banish Box: unlock gating, deposit, group-confirm quorum, resolution handoff.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Util = require(Shared:WaitForChild("Util")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any

local BanishService = {}

local ctx: any
local unlocked = false
local pending: { dollId: string, confirms: { [Player]: boolean }, generation: number }? = nil
local generation = 0

local function broadcastPrompt(dollId: string?, dollName: string?, extra: any)
	Remotes.get(Remotes.Names.BanishPrompt):FireAllClients(dollId, dollName, extra)
end

local function quorumPlayers(): { Player }
	local ShiftManager = ctx.services.ShiftManager
	local participants = ShiftManager.getParticipants()
	local out = {}
	for _, player in participants do
		if player.Parent ~= nil then
			table.insert(out, player)
		end
	end
	return out
end

local function resolve()
	local p = pending
	if not p then
		return
	end
	pending = nil
	generation += 1
	broadcastPrompt(nil, nil, { cancelled = true })
	Util.safeCall("banishResolve", function()
		ctx.services.ShiftManager.onBanishResolved(p.dollId)
	end)
end

local function cancel()
	local p = pending
	if not p then
		return
	end
	pending = nil
	generation += 1
	broadcastPrompt(nil, nil, { cancelled = true })
	-- return the doll to its bench
	local DollService = ctx.services.DollService
	local model = DollService.getModel(p.dollId)
	if model then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Transparency = if d.Name == "Root" then 1 else 0
			elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
				(d :: any).Enabled = true
			end
		end
	end
	DollService.setUnlocked(unlocked) -- refresh prompts
end

local function checkQuorum()
	local p = pending
	if not p then
		return
	end
	local players = quorumPlayers()
	local yes = 0
	for _, player in players do
		if p.confirms[player] then
			yes += 1
		end
	end
	if yes >= #players and #players > 0 then
		resolve()
	end
end

function BanishService.init(context: any)
	ctx = context
	local manifest = ctx.manifest

	if manifest.banishPrompt then
		manifest.banishPrompt.Triggered:Connect(function(player: Player)
			BanishService.deposit(player)
		end)
	end

	Remotes.get(Remotes.Names.ConfirmBanish).OnServerEvent:Connect(function(player: Player, confirm: any)
		local p = pending
		if not p then
			return
		end
		if confirm == true then
			p.confirms[player] = true
			checkQuorum()
		elseif confirm == false then
			cancel()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local p = pending
		if p then
			p.confirms[player] = nil
			task.defer(checkQuorum)
		end
	end)
end

function BanishService.setUnlocked(state: boolean)
	unlocked = state
	local manifest = ctx.manifest
	if manifest.banishPrompt then
		manifest.banishPrompt.Enabled = state and pending == nil
	end
	if manifest.banishGlow then
		TweenService:Create(manifest.banishGlow, TweenInfo.new(1.5), { Brightness = if state then 1.6 else 0 }):Play()
	end
	Util.safeCall("dollUnlock", function()
		ctx.services.DollService.setUnlocked(state)
	end)
end

function BanishService.deposit(player: Player)
	if not unlocked or pending then
		return
	end
	local DollService = ctx.services.DollService
	local dollId = DollService.getCarried(player)
	if not dollId then
		Remotes.get(Remotes.Names.Toast):FireClient(player, "Pick up the doll you suspect first.", 3)
		return
	end
	DollService.drop(player)
	-- doll appears inside the box
	local model = DollService.getModel(dollId)
	local boxBase = ctx.manifest.banishBox and ctx.manifest.banishBox.PrimaryPart
	if model and boxBase then
		model:PivotTo(boxBase.CFrame * CFrame.new(0, 1.2, 0))
		for _, d in model:GetDescendants() do
			if d:IsA("ProximityPrompt") then
				d.Enabled = false
			end
		end
	end
	if ctx.manifest.banishPrompt then
		ctx.manifest.banishPrompt.Enabled = false
	end

	generation += 1
	local myGen = generation
	pending = { dollId = dollId, confirms = {}, generation = myGen }
	local dollName = DollService.getDisplayName(dollId)
	broadcastPrompt(dollId, dollName, nil)

	local players = quorumPlayers()
	if #players <= 1 then
		-- solo: auto-resolve countdown
		task.spawn(function()
			for remaining = Config.Banish.SoloConfirmSeconds, 1, -1 do
				if not pending or pending.generation ~= myGen then
					return
				end
				broadcastPrompt(dollId, dollName, { countdown = remaining })
				task.wait(1)
			end
			if pending and pending.generation == myGen then
				resolve()
			end
		end)
	else
		-- multiplayer: majority + timer fallback so an AFK player can't deadlock (plan review fix)
		task.spawn(function()
			local elapsed = 0
			while pending and pending.generation == myGen do
				task.wait(1)
				elapsed += 1
				local p = pending
				if not p or p.generation ~= myGen then
					return
				end
				local current = quorumPlayers()
				local yes = 0
				for _, plr in current do
					if p.confirms[plr] then
						yes += 1
					end
				end
				if yes > #current / 2 then
					local remaining = Config.Banish.MajorityTimerSeconds - elapsed
					broadcastPrompt(dollId, dollName, { countdown = math.max(remaining, 0) })
					if remaining <= 0 then
						resolve()
						return
					end
				end
				if elapsed > Config.Shift.Watchdog.BanishStaging + Config.Banish.MajorityTimerSeconds then
					cancel() -- watchdog: nobody decided (R2)
					return
				end
			end
		end)
	end
end

function BanishService.reset()
	pending = nil
	generation += 1
	BanishService.setUnlocked(false)
end

return BanishService
