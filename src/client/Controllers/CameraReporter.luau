--!strict
-- Streams the local camera CFrame so the server can run the watched-check (Weeping Angels rule).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any

local CameraReporter = {}

function CameraReporter.init()
	local remote = Remotes.get(Remotes.Names.CameraReport)
	local interval = 1 / Config.Tells.WatchReportHz
	local acc = 0
	RunService.RenderStepped:Connect(function(dt: number)
		acc += dt
		if acc < interval then
			return
		end
		acc = 0
		local camera = workspace.CurrentCamera
		if camera then
			remote:FireServer(camera.CFrame)
		end
	end)
end

return CameraReporter
