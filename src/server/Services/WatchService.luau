--!strict
-- Watched-check: clients stream camera CFrames; server does authoritative cone + occlusion tests.
-- Fallback to character facing when a client has no fresh report (plan review fix).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any

local WatchService = {}

local reports: { [Player]: { cframe: CFrame, at: number } } = {}
local ctx: any

function WatchService.init(context: any)
	ctx = context
	Remotes.get(Remotes.Names.CameraReport).OnServerEvent:Connect(function(player: Player, cf: any)
		if typeof(cf) ~= "CFrame" then
			return
		end
		local char = player.Character
		local head = char and char:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			if (cf.Position - head.Position).Magnitude > 25 then
				return -- stale/spoofed
			end
		end
		reports[player] = { cframe = cf, at = os.clock() }
	end)
	Players.PlayerRemoving:Connect(function(player)
		reports[player] = nil
	end)
end

local function viewCFrameFor(player: Player): CFrame?
	local rep = reports[player]
	if rep and os.clock() - rep.at < 1 then
		return rep.cframe
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp.CFrame
	end
	return nil
end

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local function seesPoint(viewCf: CFrame, point: Vector3, excludes: { Instance }): boolean
	local offset = point - viewCf.Position
	local dist = offset.Magnitude
	if dist > Config.Tells.WatchMaxDistance then
		return false
	end
	if dist < 1 then
		return true
	end
	local cosAngle = viewCf.LookVector:Dot(offset.Unit)
	if cosAngle < math.cos(math.rad(Config.Tells.WatchFovDegrees / 2)) then
		return false
	end
	raycastParams.FilterDescendantsInstances = excludes
	local hit = workspace:Raycast(viewCf.Position, offset, raycastParams)
	return hit == nil
end

function WatchService.isWatched(model: Model): boolean
	local target = model:FindFirstChild("Head") or model.PrimaryPart
	if not (target and target:IsA("BasePart")) then
		return false
	end
	local excludes: { Instance } = { model }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(excludes, player.Character)
		end
	end
	for _, player in Players:GetPlayers() do
		local viewCf = viewCFrameFor(player)
		if viewCf and seesPoint(viewCf, target.Position, excludes) then
			return true
		end
	end
	return false
end

function WatchService.watchedMap(): { [string]: boolean }
	local out: { [string]: boolean } = {}
	local DollService = ctx.services.DollService
	for _, dollId in DollService.getDollIds() do
		local model = DollService.getModel(dollId)
		out[dollId] = model ~= nil and WatchService.isWatched(model)
	end
	return out
end

return WatchService
