--!strict
-- Spirit Compass feel: passive rattle rate + glow by distance to the nearest uncollected glyph.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local SoundKit = require(Shared:WaitForChild("SoundKit")) :: any

local DetectorClient = {}

local equipped: Tool? = nil
local lastTick = 0

local function watchCharacter(char: Model)
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == "Spirit Compass" then
			equipped = child
		end
	end)
	char.ChildRemoved:Connect(function(child)
		if child == equipped then
			equipped = nil
		end
	end)
	local existing = char:FindFirstChild("Spirit Compass")
	if existing and existing:IsA("Tool") then
		equipped = existing
	end
end

function DetectorClient.init()
	if not Config.Features.Detector then
		return
	end
	local player = Players.LocalPlayer
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)

	RunService.Heartbeat:Connect(function()
		local tool = equipped
		if not tool then
			return
		end
		local handle = tool:FindFirstChild("Handle")
		local targets = tool:FindFirstChild("GlyphTargets")
		if not (handle and handle:IsA("BasePart") and targets) then
			return
		end
		local best = math.huge
		for _, value in targets:GetChildren() do
			if value:IsA("Vector3Value") then
				local d = (value.Value - handle.Position).Magnitude
				best = math.min(best, d)
			end
		end
		local light = handle:FindFirstChild("GlowLight")
		if best == math.huge or best > Config.Glyphs.DetectorMaxRange then
			if light and light:IsA("PointLight") then
				light.Brightness = 0
			end
			return
		end
		local closeness = 1 - best / Config.Glyphs.DetectorMaxRange -- 0..1
		if light and light:IsA("PointLight") then
			light.Brightness = 0.2 + closeness * 3
		end
		-- tick rate 0.2..5 Hz by proximity
		local rate = 0.2 + closeness * 4.8
		local now = os.clock()
		if now - lastTick >= 1 / rate then
			lastTick = now
			SoundKit.play("DetectorTick")
		end
	end)
end

return DetectorClient
