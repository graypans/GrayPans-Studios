--!strict
-- Builds the entire world from parts at server start (edit mode shows an empty baseplate — expected).
-- Per-room pcall segments: one broken room can't blank the world (plan review fix).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util")) :: any

local MapBuilder = {}

local WOOD = Color3.fromRGB(62, 44, 32)
local WOOD_DARK = Color3.fromRGB(41, 29, 22)
local WALL = Color3.fromRGB(74, 62, 56)
local FLOOR = Color3.fromRGB(52, 40, 34)
local ACCENT = Color3.fromRGB(120, 96, 60)

local root: Folder

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.WoodPlanks
	p.Color = WOOD
	for k, v in props do
		if k == "Tag" then
			CollectionService:AddTag(p, v)
		else
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent or root
	return p
end

local function box(cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?, name: string?): Part
	return part({
		Name = name or "Part",
		CFrame = cf,
		Size = size,
		Color = color,
		Material = material or Enum.Material.WoodPlanks,
	})
end

-- Builds a rectangular room: floor, ceiling, 4 walls with optional door gaps (gapAxis: "X" or "Z" wall openings)
local function room(center: Vector3, sizeX: number, sizeZ: number, height: number, gaps: { [string]: boolean })
	local wallT = 1
	box(CFrame.new(center.X, center.Y - 0.5, center.Z), Vector3.new(sizeX, 1, sizeZ), FLOOR, Enum.Material.Wood, "Floor")
	box(CFrame.new(center.X, center.Y + height + 0.5, center.Z), Vector3.new(sizeX, 1, sizeZ), WOOD_DARK, Enum.Material.Wood, "Ceiling")
	local h2 = center.Y + height / 2
	local function wall(cf: CFrame, size: Vector3, gapKey: string)
		if gaps[gapKey] then
			-- split the wall into two segments leaving a 8-stud center gap
			local along = if size.X > size.Z then "X" else "Z"
			local full = if along == "X" then size.X else size.Z
			local seg = (full - 8) / 2
			if seg > 0.5 then
				local off = (seg + 8) / 2
				if along == "X" then
					box(cf * CFrame.new(-off, 0, 0), Vector3.new(seg, size.Y, size.Z), WALL, Enum.Material.Wood, "Wall")
					box(cf * CFrame.new(off, 0, 0), Vector3.new(seg, size.Y, size.Z), WALL, Enum.Material.Wood, "Wall")
				else
					box(cf * CFrame.new(0, 0, -off), Vector3.new(size.X, size.Y, seg), WALL, Enum.Material.Wood, "Wall")
					box(cf * CFrame.new(0, 0, off), Vector3.new(size.X, size.Y, seg), WALL, Enum.Material.Wood, "Wall")
				end
				-- lintel above the gap
				box(cf * CFrame.new(0, size.Y / 2 - 1.5, 0), Vector3.new(if along == "X" then 8 else size.X, 3, if along == "Z" then 8 else size.Z), WALL, Enum.Material.Wood, "Lintel")
			end
		else
			box(cf, size, WALL, Enum.Material.Wood, "Wall")
		end
	end
	wall(CFrame.new(center.X, h2, center.Z - sizeZ / 2), Vector3.new(sizeX, height, wallT), "N")
	wall(CFrame.new(center.X, h2, center.Z + sizeZ / 2), Vector3.new(sizeX, height, wallT), "S")
	wall(CFrame.new(center.X - sizeX / 2, h2, center.Z), Vector3.new(wallT, height, sizeZ), "W")
	wall(CFrame.new(center.X + sizeX / 2, h2, center.Z), Vector3.new(wallT, height, sizeZ), "E")
end

local function lamp(pos: Vector3): Part
	local base = part({
		Name = "Lamp",
		CFrame = CFrame.new(pos),
		Size = Vector3.new(0.8, 2.2, 0.8),
		Color = ACCENT,
		Material = Enum.Material.Metal,
		Tag = "Lamp",
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 120)
	light.Brightness = 1.4
	light.Range = 16
	light.Shadows = true
	light.Parent = base
	return base
end

local function surfaceText(parent: Part, face: Enum.NormalId, lines: { { text: string, size: number, color: Color3? } })
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = gui
	for _, line in lines do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(0.92, 0, 0, line.size + 8)
		label.Font = Enum.Font.Garamond
		label.TextSize = line.size
		label.TextWrapped = true
		label.TextColor3 = line.color or Color3.fromRGB(226, 216, 196)
		label.Text = line.text
		label.Parent = gui
	end
	return gui
end

local function prompt(parentPart: Part, action: string, object: string, holdSeconds: number?): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.RequiresLineOfSight = false
	p.MaxActivationDistance = 8
	p.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	p.HoldDuration = holdSeconds or 0
	p.Parent = parentPart
	return p
end

-- Layout constants: lobby around origin, workshop 240 studs +X.
local LOBBY = Vector3.new(0, 0, 0)
local SHOP = Vector3.new(240, 0, 0)
local H = 14

function MapBuilder.build(): (any, { string })
	local failures: { string } = {}
	local manifest: any = { benchSlots = {}, glyphSpawns = {}, lamps = {}, hauntDoors = {}, windowPanes = {} }

	root = Instance.new("Folder")
	root.Name = "PorcelainMap"
	root.Parent = workspace
	manifest.root = root

	local function segment(name: string, fn: () -> ...any)
		local ok, err = pcall(fn)
		if not ok then
			table.insert(failures, name)
			Util.warn(("MapBuilder segment '%s' FAILED: %s"):format(name, tostring(err)))
		end
	end

	segment("Lobby", function()
		room(LOBBY, 44, 44, H, { E = true })
		-- warm lobby lamps
		lamp(LOBBY + Vector3.new(-16, 1.1, -16))
		lamp(LOBBY + Vector3.new(-16, 1.1, 16))
		lamp(LOBBY + Vector3.new(16, 1.1, -16))
		-- spawn
		local spawn = Instance.new("SpawnLocation")
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Enabled = true
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Size = Vector3.new(8, 1, 8)
		spawn.CFrame = CFrame.new(LOBBY + Vector3.new(-10, 0.5, 0))
		CollectionService:AddTag(spawn, "LobbySpawn")
		spawn.Parent = root
		manifest.lobbySpawn = spawn
		-- ready pad: glowing circle
		local pad = part({
			Name = "ReadyPad",
			Shape = Enum.PartType.Cylinder,
			CFrame = CFrame.new(LOBBY + Vector3.new(12, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Size = Vector3.new(0.3, 12, 12),
			Color = Color3.fromRGB(150, 120, 220),
			Material = Enum.Material.Neon,
			Transparency = 0.55,
			CanCollide = false,
			Tag = "ReadyPad",
		})
		manifest.readyPad = pad
		local padLabel = part({
			Name = "ReadyPadSign",
			CFrame = CFrame.new(LOBBY + Vector3.new(12, 6.5, -7)),
			Size = Vector3.new(8, 3, 0.4),
			Color = WOOD_DARK,
		})
		surfaceText(padLabel, Enum.NormalId.Front, {
			{ text = "STAND HERE", size = 42 },
			{ text = "to start the night shift", size = 24 },
		})
		-- chalkboard
		local chalk = part({
			Name = "Chalkboard",
			CFrame = CFrame.new(LOBBY + Vector3.new(0, 7, -21.4)),
			Size = Vector3.new(18, 9, 0.5),
			Color = Color3.fromRGB(24, 30, 26),
			Material = Enum.Material.SmoothPlastic,
			Tag = "Chalkboard",
		})
		surfaceText(chalk, Enum.NormalId.Front, {
			{ text = "HOUSE RULES", size = 46, color = Color3.fromRGB(232, 226, 205) },
			{ text = "1. CARE for every doll.", size = 30 },
			{ text = "2. WATCH for the wrong one.", size = 30 },
			{ text = "3. FIND the glyphs. Match the ledger.", size = 30 },
			{ text = "4. BANISH it before the Presence takes you.", size = 30 },
			{ text = '"...and always tie the silver ribbon before a banishing. Always." — The Dollmaker', size = 22, color = Color3.fromRGB(170, 150, 190) },
		})
		manifest.chalkboard = chalk
		-- leaderboard
		local board = part({
			Name = "LeaderboardBoard",
			CFrame = CFrame.new(LOBBY + Vector3.new(-21.4, 7, 0)) * CFrame.Angles(0, math.rad(90), 0),
			Size = Vector3.new(12, 9, 0.5),
			Color = WOOD_DARK,
			Tag = "LeaderboardBoard",
		})
		manifest.leaderboardBoard = board
	end)

	segment("Corridor", function()
		-- long connector from lobby to workshop with moonlit windows
		local mid = (LOBBY + SHOP) / 2
		local len = SHOP.X - LOBBY.X - 44
		room(Vector3.new(mid.X, 0, 0), len, 12, H - 4, { W = true, E = true })
		for i = 1, 3 do
			local x = LOBBY.X + 44 + (len / 4) * i - len / 8
			local pane = part({
				Name = "WindowPane",
				CFrame = CFrame.new(x, 8, -6 + 0.2),
				Size = Vector3.new(5, 6, 0.2),
				Color = Color3.fromRGB(150, 170, 220),
				Material = Enum.Material.Glass,
				Transparency = 0.6,
				CanCollide = false,
				Tag = "WindowPane",
			})
			table.insert(manifest.windowPanes, pane)
			local moon = Instance.new("SpotLight")
			moon.Color = Color3.fromRGB(160, 180, 255)
			moon.Brightness = 0.8
			moon.Range = 24
			moon.Angle = 60
			moon.Face = Enum.NormalId.Front
			moon.Parent = pane
		end
	end)

	segment("WorkshopDoor", function()
		-- lockable door at the workshop end of the corridor
		local doorModel = Instance.new("Model")
		doorModel.Name = "WorkshopDoor"
		CollectionService:AddTag(doorModel, "WorkshopDoor")
		doorModel.Parent = root
		local slab = part({
			Name = "Slab",
			CFrame = CFrame.new(SHOP.X - 23, 5, 0),
			Size = Vector3.new(1.2, 10, 8),
			Color = WOOD_DARK,
			Material = Enum.Material.Wood,
			Parent = doorModel,
		})
		doorModel.PrimaryPart = slab
		local sign = part({
			Name = "Sign",
			CFrame = CFrame.new(SHOP.X - 23.8, 9, 0) * CFrame.Angles(0, math.rad(-90), 0),
			Size = Vector3.new(6, 2, 0.3),
			Color = Color3.fromRGB(30, 24, 28),
			Parent = doorModel,
		})
		surfaceText(sign, Enum.NormalId.Front, { { text = "", size = 30 } })
		manifest.workshopDoor = doorModel
		manifest.workshopDoorSign = sign
	end)

	segment("BenchRoom", function()
		-- main workshop: bench room
		room(SHOP, 44, 36, H, { W = true, N = true, S = true })
		lamp(SHOP + Vector3.new(-18, 1.1, -14))
		lamp(SHOP + Vector3.new(-18, 1.1, 14))
		lamp(SHOP + Vector3.new(18, 1.1, 0))
		-- workbench along the north side
		local bench = box(CFrame.new(SHOP.X, 2, SHOP.Z - 13), Vector3.new(34, 4, 6), WOOD, Enum.Material.Wood, "Workbench")
		CollectionService:AddTag(bench, "Workbench")
		manifest.workbench = bench
		for i = 1, 5 do
			local slot = part({
				Name = "BenchSlot" .. i,
				CFrame = CFrame.new(SHOP.X - 17 + (i - 1) * 8.5, 4.6, SHOP.Z - 13),
				Size = Vector3.new(1, 1, 1),
				Transparency = 1,
				CanCollide = false,
				CanQuery = false,
				Tag = "BenchSlot",
			})
			table.insert(manifest.benchSlots, slot)
		end
		-- ribbon spool on the bench end
		local spool = part({
			Name = "RibbonSpool",
			CFrame = CFrame.new(SHOP.X + 19, 4.8, SHOP.Z - 13),
			Size = Vector3.new(1.6, 1.6, 1.6),
			Color = Color3.fromRGB(200, 205, 215),
			Material = Enum.Material.Metal,
			Tag = "RibbonSpool",
		})
		manifest.ribbonSpool = spool
		manifest.ribbonPrompt = prompt(spool, "Take Silver Ribbon", "Ribbon Spool")
		-- workshop spawn (disabled by default; toggled during shifts)
		local wspawn = Instance.new("SpawnLocation")
		wspawn.Anchored = true
		wspawn.Neutral = true
		wspawn.Enabled = false
		wspawn.Transparency = 1
		wspawn.CanCollide = false
		wspawn.Size = Vector3.new(6, 1, 6)
		wspawn.CFrame = CFrame.new(SHOP + Vector3.new(0, 0.5, 8))
		CollectionService:AddTag(wspawn, "WorkshopSpawn")
		wspawn.Parent = root
		manifest.workshopSpawn = wspawn
	end)

	segment("StorageAlcove", function()
		local c = SHOP + Vector3.new(0, 0, -36 + 6)
		room(Vector3.new(SHOP.X, 0, SHOP.Z - 36), 20, 20, H - 4, { S = true })
		-- shelves with silhouette decor dolls
		for i = 1, 3 do
			local shelf = box(CFrame.new(SHOP.X - 8 + (i - 1) * 8, 5, SHOP.Z - 44), Vector3.new(6, 0.6, 3), WOOD_DARK, Enum.Material.Wood, "Shelf")
			for j = 1, 3 do
				box(
					shelf.CFrame * CFrame.new(-2 + (j - 1) * 2, 1.2, 0),
					Vector3.new(0.9, 1.8, 0.7),
					Color3.fromRGB(25, 20, 24),
					Enum.Material.SmoothPlastic,
					"DecorDoll"
				)
			end
		end
		local _ = c
	end)

	segment("LedgerRoom", function()
		room(Vector3.new(SHOP.X, 0, SHOP.Z + 36), 24, 24, H - 4, { N = true })
		lamp(Vector3.new(SHOP.X - 8, 1.1, SHOP.Z + 42))
		local desk = box(CFrame.new(SHOP.X, 2, SHOP.Z + 42), Vector3.new(8, 4, 4), WOOD, Enum.Material.Wood, "LedgerDesk")
		CollectionService:AddTag(desk, "LedgerDesk")
		local book = box(desk.CFrame * CFrame.new(0, 2.3, 0) * CFrame.Angles(0, 0, math.rad(8)), Vector3.new(3, 0.6, 2.2), Color3.fromRGB(90, 40, 40), Enum.Material.Fabric, "LedgerBook")
		manifest.ledgerDesk = desk
		manifest.ledgerPrompt = prompt(book, "Open Ledger", "Spirit Ledger")
		-- detector rack beside the desk
		local rack = part({
			Name = "DetectorRack",
			CFrame = CFrame.new(SHOP.X + 8, 3, SHOP.Z + 42),
			Size = Vector3.new(2, 6, 2),
			Color = WOOD_DARK,
			Tag = "DetectorRack",
		})
		manifest.detectorRack = rack
	end)

	segment("BanishRoom", function()
		-- east of bench room through the E gap? bench room gaps: W (corridor), N (storage... wait N is -Z toward storage), S (ledger +Z)
		room(Vector3.new(SHOP.X + 36, 0, SHOP.Z), 28, 22, H - 2, { W = true })
		-- carve the E wall gap of bench room handled by bench room's own walls (it has no E gap) — add a doorway connector
		box(CFrame.new(SHOP.X + 22, H / 2, SHOP.Z), Vector3.new(2.5, H, 8), FLOOR, Enum.Material.Wood, "BanishDoorwayFloorPatch")
		local boxModel = Instance.new("Model")
		boxModel.Name = "BanishBox"
		CollectionService:AddTag(boxModel, "BanishBox")
		boxModel.Parent = root
		local base = part({
			Name = "Base",
			CFrame = CFrame.new(SHOP.X + 40, 2.2, SHOP.Z),
			Size = Vector3.new(4, 4.4, 7),
			Color = Color3.fromRGB(38, 26, 40),
			Material = Enum.Material.Wood,
			Parent = boxModel,
		})
		boxModel.PrimaryPart = base
		local lid = part({
			Name = "Lid",
			CFrame = base.CFrame * CFrame.new(-2.4, 1.4, 0) * CFrame.Angles(0, 0, math.rad(70)),
			Size = Vector3.new(4, 0.6, 7),
			Color = Color3.fromRGB(48, 32, 52),
			Material = Enum.Material.Wood,
			Parent = boxModel,
		})
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(180, 120, 255)
		glow.Brightness = 0
		glow.Range = 12
		glow.Parent = base
		manifest.banishBox = boxModel
		manifest.banishLid = lid
		manifest.banishGlow = glow
		local depositPrompt = prompt(base, "Place the doll inside", "Banish Box", 0.5)
		depositPrompt.Enabled = false
		manifest.banishPrompt = depositPrompt
		lamp(Vector3.new(SHOP.X + 46, 1.1, SHOP.Z - 8))
	end)

	segment("HauntDoors", function()
		-- two hinged doors: storage entrance + ledger entrance
		local defs = {
			{ pos = Vector3.new(SHOP.X - 4, 0, SHOP.Z - 18), rotY = 0 },
			{ pos = Vector3.new(SHOP.X + 4, 0, SHOP.Z + 18), rotY = 180 },
		}
		for i, def in defs do
			local doorModel = Instance.new("Model")
			doorModel.Name = "HauntDoor" .. i
			CollectionService:AddTag(doorModel, "HauntDoor")
			doorModel.Parent = root
			local hinge = part({
				Name = "Hinge",
				CFrame = CFrame.new(def.pos + Vector3.new(0, 5, 0)) * CFrame.Angles(0, math.rad(def.rotY), 0),
				Size = Vector3.new(0.4, 10, 0.4),
				Transparency = 1,
				CanCollide = false,
				Parent = doorModel,
			})
			doorModel.PrimaryPart = hinge
			part({
				Name = "Panel",
				CFrame = hinge.CFrame * CFrame.new(0, 0, 2),
				Size = Vector3.new(0.5, 9.6, 4),
				Color = WOOD_DARK,
				Material = Enum.Material.Wood,
				CanCollide = false,
				Parent = doorModel,
			})
			table.insert(manifest.hauntDoors, doorModel)
		end
	end)

	segment("GlyphSpawns", function()
		local spots = {
			SHOP + Vector3.new(-19, 5.5, 10), -- bench room shadow corner
			SHOP + Vector3.new(14, 1.5, 15), -- bench room floor
			SHOP + Vector3.new(-6, 5.8, -44), -- storage shelf
			SHOP + Vector3.new(8, 1.5, -40), -- storage floor corner
			SHOP + Vector3.new(-9, 1.5, 40), -- ledger room corner
			SHOP + Vector3.new(10, 6, 44), -- ledger room high shelf level
			SHOP + Vector3.new(46, 1.5, 6), -- banish room corner
			SHOP + Vector3.new(34, 7, -8), -- banish room high
			Vector3.new((LOBBY.X + SHOP.X) / 2, 2, 4), -- corridor
			Vector3.new((LOBBY.X + SHOP.X) / 2 + 30, 8, -4), -- corridor high
		}
		for i, pos in spots do
			local marker = part({
				Name = "GlyphSpawn" .. i,
				CFrame = CFrame.new(pos),
				Size = Vector3.new(0.5, 0.5, 0.5),
				Transparency = 1,
				CanCollide = false,
				CanQuery = false,
				Tag = "GlyphSpawn",
			})
			table.insert(manifest.glyphSpawns, marker)
		end
	end)

	segment("Atmosphere", function()
		Lighting.FogEnd = 140
		Lighting.FogStart = 30
		Lighting.FogColor = Color3.fromRGB(18, 14, 22)
		local atmo = Instance.new("Atmosphere")
		atmo.Density = 0.35
		atmo.Color = Color3.fromRGB(120, 110, 130)
		atmo.Parent = Lighting
		-- collect lamps into manifest
		for _, inst in CollectionService:GetTagged("Lamp") do
			table.insert(manifest.lamps, inst)
		end
	end)

	Util.log(("MapBuilder: built with %d failed segment(s)"):format(#failures))
	return manifest, failures
end

function MapBuilder.init(_ctx: any) end

return MapBuilder
