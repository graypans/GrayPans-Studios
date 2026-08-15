--!strict
-- Client-scope haunts: WhisperPass, the Taken stub, and the DollmakerReveal run-end scare.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local SoundKit = require(Shared:WaitForChild("SoundKit")) :: any
local Theme = require(script.Parent.Parent:WaitForChild("Theme")) :: any

local HauntClient = {}

local gui: ScreenGui? = nil

local function cameraShake(intensity: number, duration: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < duration do
			local offset = CFrame.new(
				(math.random() - 0.5) * intensity,
				(math.random() - 0.5) * intensity,
				0
			)
			camera.CFrame = camera.CFrame * offset
			task.wait(0.03)
		end
	end)
end

local function whisperPass()
	SoundKit.play("WhisperPass")
	cameraShake(0.08, 0.6)
	local g = gui
	if not g then
		return
	end
	local vignette = Instance.new("Frame")
	vignette.BackgroundColor3 = Color3.new(0, 0, 0)
	vignette.BackgroundTransparency = 1
	vignette.BorderSizePixel = 0
	vignette.Size = UDim2.new(1, 0, 1, 0)
	vignette.Parent = g
	TweenService:Create(vignette, TweenInfo.new(0.3), { BackgroundTransparency = 0.55 }):Play()
	task.delay(0.8, function()
		TweenService:Create(vignette, TweenInfo.new(1), { BackgroundTransparency = 1 }):Play()
		task.delay(1.1, function()
			vignette:Destroy()
		end)
	end)
end

local function takenStub()
	local g = gui
	if not g then
		return
	end
	local dark = Instance.new("Frame")
	dark.BackgroundColor3 = Color3.new(0, 0, 0)
	dark.BackgroundTransparency = 0.2
	dark.BorderSizePixel = 0
	dark.Size = UDim2.new(1, 0, 1, 0)
	dark.Parent = g
	local label = Theme.label(dark, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0.8, 0, 0, 60),
		Font = Theme.TitleFont,
		TextSize = 32,
		Text = "wake up… (tap 5 times)",
	})
	local taps = 0
	local button = Instance.new("TextButton")
	button.BackgroundTransparency = 1
	button.Size = UDim2.new(1, 0, 1, 0)
	button.Text = ""
	button.Parent = dark
	button.Activated:Connect(function()
		taps += 1
		label.Text = ("wake up… (%d more)"):format(math.max(0, 5 - taps))
		if taps >= 5 then
			dark:Destroy()
		end
	end)
	task.delay(20, function() -- hard auto-clear (R2)
		if dark.Parent then
			dark:Destroy()
		end
	end)
end

local function dollmakerReveal()
	local g = gui
	if not g then
		return
	end
	local dark = Instance.new("Frame")
	dark.BackgroundColor3 = Color3.new(0, 0, 0)
	dark.BackgroundTransparency = 0
	dark.BorderSizePixel = 0
	dark.Size = UDim2.new(1, 0, 1, 0)
	dark.ZIndex = 5
	dark.Parent = g
	task.delay(0.5, function()
		SoundKit.play("DollmakerScream")
		cameraShake(0.35, 1.2)
		-- the towering shadow face, assembled from frames
		local face = Instance.new("Frame")
		face.AnchorPoint = Vector2.new(0.5, 0.5)
		face.Position = UDim2.new(0.5, 0, 1.4, 0)
		face.Size = UDim2.new(0, 500, 0, 620)
		face.BackgroundTransparency = 1
		face.ZIndex = 6
		face.Parent = dark
		local function facePart(pos: UDim2, size: UDim2, color: Color3, rotation: number?)
			local frame = Instance.new("Frame")
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.Position = pos
			frame.Size = size
			frame.Rotation = rotation or 0
			frame.BackgroundColor3 = color
			frame.BorderSizePixel = 0
			frame.ZIndex = 6
			frame.Parent = face
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = frame
		end
		local shadow = Color3.fromRGB(16, 12, 18)
		local eye = Color3.fromRGB(212, 175, 96)
		facePart(UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.9, 0.95), shadow) -- head mass
		facePart(UDim2.fromScale(0.32, 0.38), UDim2.fromScale(0.16, 0.1), eye) -- left eye
		facePart(UDim2.fromScale(0.68, 0.36), UDim2.fromScale(0.13, 0.13), eye, 12) -- right eye, wrong size
		facePart(UDim2.fromScale(0.5, 0.68), UDim2.fromScale(0.5, 0.05), Color3.fromRGB(60, 40, 50), -6) -- stitched smile
		for i = 1, 6 do
			facePart(
				UDim2.fromScale(0.28 + (i - 1) * 0.09, 0.68 + (if i % 2 == 0 then 0.03 else -0.03)),
				UDim2.fromScale(0.02, 0.09),
				Color3.fromRGB(60, 40, 50),
				15
			)
		end
		TweenService:Create(face, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0.5, 0),
		}):Play()
		task.delay(2.5, function()
			TweenService:Create(dark, TweenInfo.new(1.5), { BackgroundTransparency = 1 }):Play()
			for _, child in face:GetChildren() do
				if child:IsA("Frame") then
					TweenService:Create(child, TweenInfo.new(1), { BackgroundTransparency = 1 }):Play()
				end
			end
			task.delay(1.6, function()
				dark:Destroy()
			end)
		end)
	end)
end

function HauntClient.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local g = Theme.screenGui("PorcelainHaunts", 18)
	g.Parent = playerGui
	gui = g

	Remotes.get(Remotes.Names.HauntFired).OnClientEvent:Connect(function(hauntId: any)
		if hauntId == "WhisperPass" then
			whisperPass()
		elseif hauntId == "Taken" then
			takenStub()
		elseif hauntId == "DollmakerReveal" then
			dollmakerReveal()
		end
		-- unknown ids: ignore silently
	end)
end

return HauntClient
