--!strict
-- Left-side lobby hub HUD: Shop / Invite / Classes / Journal, in that order (matches the team's own
-- description and the reference screenshots exactly). Pure ScreenGui (no 3D kiosk) so it drops into
-- any hub layout unchanged. Visible only in LobbyIdle, hidden during any active-shift state.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local SoundKit = require(Shared:WaitForChild("SoundKit")) :: any
local Theme = require(script.Parent.Parent:WaitForChild("Theme")) :: any

local LobbyHud = {}

-- Lazily-created client-local BindableEvent -- see PACKET_1_LOBBY_SYSTEMS.md "READ THIS FIRST" §3:
-- this is the canonical panel-open convention Shop.luau/Journal.luau both listen on.
local function getOpenPanelBindable(): BindableEvent
	local existing = ReplicatedStorage:FindFirstChild("PorcelainOpenPanel")
	if existing and existing:IsA("BindableEvent") then
		return existing
	end
	local bindable = Instance.new("BindableEvent")
	bindable.Name = "PorcelainOpenPanel"
	bindable.Parent = ReplicatedStorage
	return bindable
end

local gui: ScreenGui? = nil

local function addButton(parent: Instance, text: string, order: number): TextButton
	return Theme.button(parent, {
		Size = UDim2.new(1, 0, 0, 72),
		LayoutOrder = order,
		TextSize = 20,
		Text = text,
	})
end

local function build()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local g = Theme.screenGui("PorcelainLobbyHud", 6)
	g.Enabled = false
	g.Parent = playerGui
	gui = g

	local column = Instance.new("Frame")
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(0, 1)
	column.Position = UDim2.new(0, 16, 1, -16)
	column.Size = UDim2.new(0.34, 0, 0, 320)
	column.Parent = g
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MaxSize = Vector2.new(190, 1000)
	sizeConstraint.MinSize = Vector2.new(120, 100)
	sizeConstraint.Parent = column
	local layout = Instance.new("UIListLayout")
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, 10)
	layout.Parent = column

	-- RESTORED 2026-08-15: team confirmed Classes stays a separate button (see "READ THIS FIRST"
	-- §3). Order matches the team's own description ("shop invite, classes, and journal") AND the
	-- reference screenshots exactly: Shop, Invite, Classes, Journal, top to bottom.
	local shopButton = addButton(column, "SHOP", 1)
	local inviteButton = addButton(column, "INVITE", 2)
	local classesButton = addButton(column, "CLASSES", 3)
	local journalButton = addButton(column, "JOURNAL", 4)

	shopButton.Activated:Connect(function()
		SoundKit.play("UiClick")
		getOpenPanelBindable():Fire("Shop")
	end)
	-- Per "READ THIS FIRST" §3: InviteButton.luau's SocialService-based implementation is the
	-- resolved, recommended one (more current API, graceful disable-with-toast on failure). This
	-- button just tags itself and defers to that controller instead of keeping its own inline
	-- StarterGui:SetCore call.
	CollectionService:AddTag(inviteButton, "InviteButtonTag")
	classesButton.Activated:Connect(function()
		SoundKit.play("UiClick")
		getOpenPanelBindable():Fire("Classes")
	end)
	journalButton.Activated:Connect(function()
		SoundKit.play("UiClick")
		getOpenPanelBindable():Fire("Journal")
	end)
end

function LobbyHud.init()
	build()

	Remotes.get(Remotes.Names.StateChanged).OnClientEvent:Connect(function(state: any)
		local g = gui
		if g then
			g.Enabled = (state == "LobbyIdle")
		end
	end)
end

return LobbyHud
