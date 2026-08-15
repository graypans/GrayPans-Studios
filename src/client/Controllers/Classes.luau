--!strict
-- Dedicated Classes screen: browse the full roster (owned + locked), preview the selected one, and
-- equip an owned class. Separate from Shop.luau (which handles BUYING) per the team's own reference
-- screenshots -- Animal Hospital's "Classes" screen is a distinct list-with-lock-icons + equip flow,
-- not folded into the shop. Reuses Shop.luau's exact remotes (CoinsUpdate, ClassesData) -- no new
-- remotes needed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local Classes = require(Shared:WaitForChild("Defs"):WaitForChild("Classes")) :: any
local SoundKit = require(Shared:WaitForChild("SoundKit")) :: any
local Theme = require(script.Parent.Parent:WaitForChild("Theme")) :: any

local ClassesUI = {}

local gui: ScreenGui? = nil
local listFrame: ScrollingFrame? = nil
local descLabel: TextLabel? = nil
local equipButton: TextButton? = nil
local nameLabel: TextLabel? = nil

local owned: { [string]: boolean } = {}
local equipped = Classes.starterId
local selectedId = Classes.starterId

local function isOwnedLocally(classId: string): boolean
	local def = Classes.byId[classId]
	if not def then
		return false
	end
	return def.price <= 0 or owned[classId] == true
end

local function refreshDetail()
	local def = Classes.byId[selectedId]
	if not def then
		return
	end
	if nameLabel then
		nameLabel.Text = def.name
	end
	if descLabel then
		descLabel.Text = def.description
	end
	local ownedNow = isOwnedLocally(selectedId)
	local equippedNow = equipped == selectedId
	if equipButton then
		equipButton.Text = if equippedNow then "EQUIPPED" elseif ownedNow then "EQUIP" else "BUY IN SHOP"
		equipButton.Active = ownedNow and not equippedNow
		equipButton.BackgroundColor3 = if ownedNow and not equippedNow then Theme.Gold else Theme.BgSoft
		equipButton.TextColor3 = if ownedNow and not equippedNow then Color3.fromRGB(30, 24, 20) else Theme.Muted
	end
end

local function refreshList()
	local list = listFrame
	if not list then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for _, def in Classes.list do
		local ownedNow = isOwnedLocally(def.id)
		local equippedNow = equipped == def.id
		local selectedNow = selectedId == def.id
		local row = Theme.button(list, {
			Size = UDim2.new(1, 0, 0, 56), -- mobile touch target
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = if ownedNow then ("  " .. def.name) else ("  🔒 " .. def.name),
		})
		row.BackgroundColor3 = if equippedNow then Theme.Gold elseif selectedNow then Theme.Accent else Theme.BgSoft
		row.TextColor3 = if equippedNow then Color3.fromRGB(30, 24, 20) else Theme.Muted
		row.Activated:Connect(function()
			selectedId = def.id
			SoundKit.play("UiClick")
			refreshList()
			refreshDetail()
		end)
	end
end

local function build()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local g = Theme.screenGui("PorcelainClasses", 13)
	g.Enabled = false
	g.Parent = playerGui
	gui = g

	local panel = Theme.panel(g, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0.94, 0, 0.86, 0),
		BackgroundTransparency = 0.02,
	})
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(320, 380)
	constraint.MaxSize = Vector2.new(680, 520)
	constraint.Parent = panel

	Theme.label(panel, {
		Position = UDim2.new(0, 0, 0, 10),
		Size = UDim2.new(1, 0, 0, 30),
		Font = Theme.TitleFont,
		TextSize = 26,
		Text = "— Choose Your Class —",
	})

	local close = Theme.button(panel, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.new(0, 56, 0, 44),
		TextSize = 20,
		Text = "✕",
	})
	close.Activated:Connect(function()
		ClassesUI.close()
	end)

	-- left: scrollable class list (locked entries show a padlock, matches the team's reference screenshots)
	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.new(0, 14, 0, 56)
	list.Size = UDim2.new(0.42, -20, 1, -70)
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 6
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list
	listFrame = list

	-- right: selected-class detail + Equip button
	local detail = Theme.panel(panel, {
		Position = UDim2.new(0.44, 0, 0, 56),
		Size = UDim2.new(0.56, -14, 1, -70),
		BackgroundTransparency = 0.15,
	})
	nameLabel = Theme.label(detail, {
		Position = UDim2.new(0, 14, 0, 14),
		Size = UDim2.new(1, -28, 0, 30),
		Font = Theme.TitleFont,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})
	descLabel = Theme.label(detail, {
		Position = UDim2.new(0, 14, 0, 50),
		Size = UDim2.new(1, -28, 1, -130),
		TextSize = 16,
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Text = "",
	})
	local equip = Theme.button(detail, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(0, 200, 0, 64), -- mobile-first: >=64px touch target
		TextSize = 18,
		Text = "EQUIP",
	})
	equip.Activated:Connect(function()
		if not isOwnedLocally(selectedId) or equipped == selectedId then
			return
		end
		SoundKit.play("UiClick")
		Remotes.get(Remotes.Names.EquipClass):FireServer(selectedId)
	end)
	equipButton = equip

	refreshList()
	refreshDetail()
end

function ClassesUI.open()
	if gui then
		gui.Enabled = true
		SoundKit.play("UiConfirm")
		refreshList()
		refreshDetail()
	end
end

function ClassesUI.close()
	if gui then
		gui.Enabled = false
	end
end

function ClassesUI.init()
	build()

	local openBindable: BindableEvent
	local existing = ReplicatedStorage:FindFirstChild("PorcelainOpenPanel")
	if existing and existing:IsA("BindableEvent") then
		openBindable = existing
	else
		openBindable = Instance.new("BindableEvent")
		openBindable.Name = "PorcelainOpenPanel"
		openBindable.Parent = ReplicatedStorage
	end
	openBindable.Event:Connect(function(panelName: string?)
		if panelName == "Classes" then
			ClassesUI.open()
		end
	end)

	Remotes.get(Remotes.Names.ClassesData).OnClientEvent:Connect(function(data: any)
		if typeof(data) ~= "table" then
			return
		end
		if typeof(data.owned) == "table" then
			owned = data.owned
		end
		if typeof(data.equipped) == "string" then
			equipped = data.equipped
			selectedId = equipped
		end
		refreshList()
		refreshDetail()
	end)

	Remotes.get(Remotes.Names.StateChanged).OnClientEvent:Connect(function(state: any)
		if state ~= "LobbyIdle" then
			ClassesUI.close()
		end
	end)
end

return ClassesUI
