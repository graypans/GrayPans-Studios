--!strict
-- Panic emote: corner button + E key. The characters scream so the players don't have to.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local SoundKit = require(Shared:WaitForChild("SoundKit")) :: any
local Theme = require(script.Parent.Parent:WaitForChild("Theme")) :: any

local PanicEmote = {}

local cooldownUntil = 0

local function panic()
	local now = os.clock()
	if now < cooldownUntil then
		return
	end
	cooldownUntil = now + 3
	local player = Players.LocalPlayer
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	SoundKit.play("PanicBark", head)
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Jump = true
	end
	-- local "!!" billboard (local-only stub for the beta)
	if head and head:IsA("BasePart") then
		local billboard = Instance.new("BillboardGui")
		billboard.Adornee = head
		billboard.Size = UDim2.new(0, 60, 0, 40)
		billboard.StudsOffset = Vector3.new(0, 3.4, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = head
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Theme.Danger
		label.Text = "!!"
		label.Parent = billboard
		task.delay(2, function()
			billboard:Destroy()
		end)
	end
	-- tiny camera pop
	local camera = workspace.CurrentCamera
	if camera then
		task.spawn(function()
			for _ = 1, 6 do
				camera.CFrame = camera.CFrame * CFrame.new((math.random() - 0.5) * 0.15, (math.random() - 0.5) * 0.15, 0)
				task.wait(0.03)
			end
		end)
	end
end

function PanicEmote.init()
	if not Config.Features.PanicEmote then
		return
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Theme.screenGui("PorcelainPanic", 8)
	gui.Parent = playerGui
	local button = Theme.button(gui, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -90),
		Size = UDim2.new(0, 68, 0, 68),
		TextSize = 30,
		Text = "😱",
	})
	local corner = button:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(1, 0)
	end
	button.Activated:Connect(panic)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.E then
			panic()
		end
	end)
end

return PanicEmote
