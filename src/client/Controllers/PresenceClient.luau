--!strict
-- Diegetic Presence rendering: LOCAL lighting shifts + lamp flicker + ambience layers by tier.

local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local SoundKit = require(Shared:WaitForChild("SoundKit")) :: any

local PresenceClient = {}

local tier = 0
local ambienceBase: Sound? = nil
local ambienceT2: Sound? = nil
local ambienceT3: Sound? = nil

local TIER_AMBIENT = {
	[0] = Color3.fromRGB(27, 23, 31),
	[1] = Color3.fromRGB(24, 20, 30),
	[2] = Color3.fromRGB(20, 22, 24),
	[3] = Color3.fromRGB(16, 24, 18),
}

local function applyTier()
	local target = TIER_AMBIENT[tier] or TIER_AMBIENT[0]
	TweenService:Create(Lighting, TweenInfo.new(3), {
		Ambient = target,
		OutdoorAmbient = target,
	}):Play()
	local function setVolume(sound: Sound?, on: boolean, volume: number)
		if sound then
			TweenService:Create(sound, TweenInfo.new(2), { Volume = if on then volume else 0 }):Play()
		end
	end
	setVolume(ambienceT2, tier >= 2, 0.3)
	setVolume(ambienceT3, tier >= 3, 0.35)
end

local function flickerLoop()
	task.spawn(function()
		while true do
			local interval = if tier >= 3 then 0.8 elseif tier == 2 then 2 elseif tier == 1 then 5 else 12
			task.wait(interval + math.random() * interval)
			if tier < 1 then
				continue
			end
			-- flicker a random lamp locally
			local lamps = CollectionService:GetTagged("Lamp")
			if #lamps == 0 then
				continue
			end
			local lamp = lamps[math.random(1, #lamps)]
			local light = lamp:FindFirstChildOfClass("PointLight")
			if light and light.Enabled then
				task.spawn(function()
					for _ = 1, math.random(2, 5) do
						light.Brightness = 0.2
						task.wait(0.05 + math.random() * 0.08)
						light.Brightness = 1.4
						task.wait(0.05 + math.random() * 0.1)
					end
				end)
			end
		end
	end)
end

function PresenceClient.init()
	ambienceBase = SoundKit.attach("AmbienceBase", SoundService)
	ambienceT2 = SoundKit.attach("AmbienceTier2", SoundService)
	ambienceT3 = SoundKit.attach("AmbienceTier3", SoundService)
	for _, sound in { ambienceBase, ambienceT2, ambienceT3 } do
		if sound then
			sound.Volume = if sound == ambienceBase then sound.Volume else 0
			sound:Play()
		end
	end

	Remotes.get(Remotes.Names.PresenceTier).OnClientEvent:Connect(function(newTier: any)
		if typeof(newTier) == "number" then
			tier = newTier
			applyTier()
		end
	end)

	flickerLoop()
end

return PresenceClient
