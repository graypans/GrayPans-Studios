--!strict
-- Coin balance + class shop. Full-screen panel toggled via Shop.open()/close()/toggle(), or by any
-- other controller firing ReplicatedStorage's "PorcelainOpenPanel" BindableEvent with the string
-- "Shop" (see PACKET_1_LOBBY_SYSTEMS.md's integration notes -- this listens on the SAME bindable the
-- Join-Squares track's LobbyHud fires, not a separately-invented one).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local Classes = require(Shared:WaitForChild("Defs"):WaitForChild("Classes")) :: any
local SoundKit = require(Shared:WaitForChild("SoundKit")) :: any
local Theme = require(script.Parent.Parent:WaitForChild("Theme")) :: any

local Shop = {}

local gui: ScreenGui? = nil
local listFrame: ScrollingFrame? = nil
local balanceLabel: TextLabel? = nil

local coins = 0
local owned: { [string]: boolean } = {}
local equipped = Classes.starterId

local function isOwnedLocally(classId: string): boolean
	local def = Classes.byId[classId]
	if not def then
		return false
	end
	return def.price <= 0 or owned[classId] == true
end

local function priceText(def: any): string
	if def.price <= 0 then
		return "FREE"
	end
	return ("%d coins"):format(def.price)
end

local function refresh()
	local list = listFrame
	if not list then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for _, def in Classes.list do
		local card = Theme.panel(list, {
			Size = UDim2.new(1, -8, 0, 150),
			BackgroundTransparency = 0.15,
		})
		Theme.label(card, {
			Position = UDim2.new(0, 14, 0, 10),
			Size = UDim2.new(1, -28, 0, 26),
			Font = Theme.TitleFont,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = def.name,
		})
		Theme.label(card, {
			Position = UDim2.new(0, 14, 0, 38),
			Size = UDim2.new(1, -28, 0, 48),
			TextSize = 15,
			TextColor3 = Theme.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = def.description,
		})
		Theme.label(card, {
			Position = UDim2.new(0, 14, 1, -34),
			Size = UDim2.new(0.5, -14, 0, 24),
			TextSize = 15,
			TextColor3 = Theme.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = priceText(def),
		})

		local ownedNow = isOwnedLocally(def.id)
		local equippedNow = equipped == def.id
		local button = Theme.button(card, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -14, 1, -12),
			Size = UDim2.new(0, 160, 0, 64), -- mobile-first: >=64px touch target
			TextSize = 18,
			Text = if equippedNow then "EQUIPPED" elseif ownedNow then "EQUIP" else "BUY",
			AutoButtonColor = not equippedNow,
		})
		if equippedNow then
			button.Active = false
			button.BackgroundColor3 = Theme.BgSoft
		elseif ownedNow then
			button.Activated:Connect(function()
				SoundKit.play("UiClick")
				Remotes.get(Remotes.Names.EquipClass):FireServer(def.id)
			end)
		else
			if coins < def.price then
				button.BackgroundColor3 = Theme.BgSoft
				button.TextColor3 = Theme.Muted
			end
			button.Activated:Connect(function()
				SoundKit.play("UiClick")
				Remotes.get(Remotes.Names.BuyClass):FireServer(def.id)
			end)
		end
	end
end

local function build()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local g = Theme.screenGui("PorcelainShop", 13)
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
	constraint.MinSize = Vector2.new(300, 360)
	constraint.MaxSize = Vector2.new(680, 560)
	constraint.Parent = panel

	Theme.label(panel, {
		Position = UDim2.new(0, 0, 0, 10),
		Size = UDim2.new(1, 0, 0, 30),
		Font = Theme.TitleFont,
		TextSize = 26,
		Text = "— The Dollmaker's Shop —",
	})

	balanceLabel = Theme.label(panel, {
		Position = UDim2.new(0, 16, 0, 44),
		Size = UDim2.new(0.6, 0, 0, 26),
		TextSize = 18,
		TextColor3 = Theme.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "0 coins",
	})

	local close = Theme.button(panel, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.new(0, 56, 0, 44),
		TextSize = 20,
		Text = "✕",
	})
	close.Activated:Connect(function()
		Shop.close()
	end)

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.new(0, 14, 0, 78)
	list.Size = UDim2.new(1, -28, 1, -92)
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 6
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.Parent = list
	listFrame = list

	refresh()
end

function Shop.open()
	if gui then
		gui.Enabled = true
		SoundKit.play("UiConfirm")
	end
end

function Shop.close()
	if gui then
		gui.Enabled = false
	end
end

function Shop.toggle()
	if gui then
		gui.Enabled = not gui.Enabled
	end
end

function Shop.init()
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
		if panelName == "Shop" then
			Shop.open()
		end
	end)

	Remotes.get(Remotes.Names.CoinsUpdate).OnClientEvent:Connect(function(newBalance: any)
		if typeof(newBalance) == "number" then
			coins = newBalance
			if balanceLabel then
				balanceLabel.Text = ("%d coins"):format(coins)
			end
			refresh()
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
		end
		refresh()
	end)

	-- Close automatically if a shift starts while the shop is open (mirrors LedgerUI's own
	-- StateChanged-driven close).
	Remotes.get(Remotes.Names.StateChanged).OnClientEvent:Connect(function(state: any)
		if state ~= "LobbyIdle" then
			Shop.close()
		end
	end)
end

return Shop
