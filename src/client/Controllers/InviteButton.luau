--!strict
-- Invite: Roblox's native friend-invite prompt via SocialService, entirely client-side (R3
-- pcall-wrapped via Util.safeCall). Wires to any GuiButton tagged "InviteButtonTag" so whichever
-- controller builds the physical left-nav HUD button only needs to CollectionService:AddTag() it.
-- If nothing has claimed the tag, an optional fallback button ships behind
-- Config.Features.InviteFallbackButton (default false).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Util = require(Shared:WaitForChild("Util")) :: any
local Theme = require(script.Parent.Parent:WaitForChild("Theme")) :: any
local Toast = require(script.Parent:WaitForChild("Toast")) :: any

local InviteButton = {}

local TAG = "InviteButtonTag"

local function disableButton(button: GuiButton, message: string)
	button.Active = false
	button.AutoButtonColor = false
	if button:IsA("TextButton") then
		button.BackgroundColor3 = Theme.BgSoft
		button.TextColor3 = Theme.Muted
	end
	Toast.show(message, 4)
end

local function trySendInvite(button: GuiButton)
	local player = Players.LocalPlayer
	local canInvite = false
	local checkOk = Util.safeCall("canSendGameInvite", function()
		canInvite = SocialService:CanSendGameInviteAsync(player)
	end)
	if not checkOk or not canInvite then
		disableButton(button, "Invites aren't available right now on this device or platform.")
		return
	end
	local promptOk = Util.safeCall("promptGameInvite", function()
		SocialService:PromptGameInvite(player)
	end)
	if not promptOk then
		Toast.show("Couldn't open the invite prompt — try again in a moment.", 4)
	end
end

local function wire(inst: Instance)
	if not inst:IsA("GuiButton") then
		return
	end
	local button = inst :: GuiButton
	button.Activated:Connect(function()
		trySendInvite(button)
	end)
end

local function buildFallbackButton()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Theme.screenGui("PorcelainInviteFallback", 8)
	gui.Parent = playerGui
	local button = Theme.button(gui, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.new(0, 150, 0, 64), -- mobile touch target
		TextSize = 18,
		Text = "Invite Friends",
	})
	CollectionService:AddTag(button, TAG) -- triggers wire() via the signal below, no double-path needed
end

function InviteButton.init()
	for _, inst in CollectionService:GetTagged(TAG) do
		wire(inst)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(wire)

	if Config.Features.InviteFallbackButton then
		buildFallbackButton()
	end
end

return InviteButton
