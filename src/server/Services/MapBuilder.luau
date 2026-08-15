--!strict
-- Builds the entire world from parts at server start (edit mode shows an empty baseplate — expected).
-- Per-room pcall segments: one broken room can't blank the world (plan review fix).
--
-- REDESIGNED per docs/packets/PACKET_1_MAP_DESIGN.md §4 ("Hollow Square" synthesis): a dead Victorian
-- town square (Hub) around a broken fountain, facing the Dollmaker's shop, with a plus-shaped Workshop
-- reached only by ShiftManager's existing ShiftIntro teleport (no walked corridor). Two structural
-- decisions eliminate the exact bug class the first playtest found (A1 sealed room / A2 void gaps),
-- BY CONSTRUCTION rather than by careful gap-matching:
--   1. The Workshop is two overlapping full-footprint floor/ceiling slabs with walls ONLY on the
--      outer perimeter of the plus-shape -- there are no interior walls anywhere to misalign a gap in.
--   2. The Hub's Shop/Classes/Apothecary buildings are solid, unopened facades (no door/window cut
--      through a wall at all) with mounted decorative props and a ProximityPrompt -- players never
--      walk into them, so there is no interior to seal off or leave a hole in.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Util = require(Shared:WaitForChild("Util")) :: any
local ServerKind = require(Shared:WaitForChild("ServerKind")) :: any

local MapBuilder = {}

local WOOD = Color3.fromRGB(62, 44, 32)
local WOOD_DARK = Color3.fromRGB(41, 29, 22)
local WALL = Color3.fromRGB(74, 62, 56)
local FLOOR = Color3.fromRGB(52, 40, 34)
local ACCENT = Color3.fromRGB(120, 96, 60)
local STONE = Color3.fromRGB(88, 86, 92)
local BOARD_WOOD = Color3.fromRGB(58, 42, 34)

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

-- Invisible collision-only boundary (R2/A2-class-bug prevention: keeps players from ever walking
-- off the Hub's open-sky Plaza/Alley into the void).
local function guardWall(cf: CFrame, size: Vector3)
	part({
		Name = "HubBoundary",
		CFrame = cf,
		Size = size,
		Transparency = 1,
		CanCollide = true,
		CanQuery = false,
	})
end

local function lamp(pos: Vector3, flicker: boolean?): Part
	local base = part({
		Name = "Lamp",
		CFrame = CFrame.new(pos),
		Size = Vector3.new(0.8, 2.2, 0.8),
		Color = ACCENT,
		Material = Enum.Material.Metal,
		Tag = if flicker then "Lamp" else nil, -- HauntService's LightsOutBeat toggles every Lamp-tagged
			-- light; Hub decorative lamps deliberately DON'T carry this tag (see hubLamp() below) so a
			-- haunt firing during someone else's shift can't plunge waiting players into darkness. This
			-- helper is now Workshop-only; see hubLamp() for the Hub's lamps.
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 120)
	light.Brightness = 1.4
	light.Range = 16
	light.Shadows = true
	light.Parent = base
	return base
end

-- Hub-only lamp: same visual, but NEVER tagged "Lamp" (see note above) so HauntService's
-- LightsOutBeat, which only fires during an active Workshop shift, can't affect the Hub. `flicker`
-- gives it a small continuous brightness wobble (graft #1: flicker stays confined to the Entry
-- Alley's one hero lamp; the Plaza's corner lamps stay steady for join-square legibility).
local function hubLamp(pos: Vector3, flicker: boolean?): Part
	local base = part({
		Name = "HubLamp",
		CFrame = CFrame.new(pos),
		Size = Vector3.new(0.8, 2.2, 0.8),
		Color = ACCENT,
		Material = Enum.Material.Metal,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 120)
	light.Brightness = 1.4
	light.Range = 18
	light.Shadows = true
	light.Parent = base
	if flicker then
		task.spawn(function()
			while base.Parent do
				light.Brightness = 0.5 + math.random() * 1.1
				task.wait(0.15 + math.random() * 0.35)
			end
		end)
	end
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
	p.MaxActivationDistance = Config.Care.PromptDistance
	p.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	p.HoldDuration = holdSeconds or 0
	p.Parent = parentPart
	return p
end

-- A lit window: a glass pane + interior PointLight + doll-silhouette props behind the glass
-- (graft #2 from the map-design judge pass). Mounted ON the wall's outer surface -- never cut
-- through it, so it can't reproduce the A1/A2 gap-bug class.
local function litWindow(cf: CFrame, silhouetteCount: number?)
	local pane = part({
		Name = "WindowPane",
		CFrame = cf,
		Size = Vector3.new(5, 5, 0.2),
		Color = Color3.fromRGB(150, 170, 220),
		Material = Enum.Material.Glass,
		Transparency = 0.35,
		CanCollide = false,
		Tag = "WindowPane",
	})
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 200, 140)
	glow.Brightness = 1.2
	glow.Range = 10
	glow.Parent = pane
	for i = 1, (silhouetteCount or 2) do
		box(
			cf * CFrame.new(-1.4 + (i - 1) * 1.6, -0.6, 0.3),
			Vector3.new(0.8, 1.8, 0.4),
			Color3.fromRGB(20, 16, 22),
			Enum.Material.SmoothPlastic,
			"DollSilhouette"
		)
	end
	return pane
end

-- Two overlapping full-footprint slabs (a plus-shape floor/ceiling) with NO interior walls -- the
-- direct A1/A2 fix. `arms` is a list of {center, footprint} boxes; every arm must be listed BEFORE
-- any perimeter wall is built, and any two arms that should connect must overlap by several studs
-- (not just touch edges) so there's never a seam a player can fall through.
local function plusSlab(arms: { { center: Vector3, footprint: Vector3 } }, height: number)
	for _, arm in arms do
		box(CFrame.new(arm.center) * CFrame.new(0, -0.5, 0), arm.footprint, FLOOR, Enum.Material.Wood, "Floor")
		box(CFrame.new(arm.center) * CFrame.new(0, height + 0.5, 0), arm.footprint, WOOD_DARK, Enum.Material.Wood, "Ceiling")
	end
end

-- Layout origins: Hub around world origin; Workshop far away (never walked to, only reached via
-- ShiftManager's ShiftIntro teleport) so the two zones never visually or physically overlap.
-- StreamingEnabled stays false (R8), so the distance costs nothing at runtime.
local HUB = Vector3.new(0, 0, 0)
local WS = Vector3.new(0, 0, 600)
local H_HUB = 16 -- Hub building height
local H_WS = 14 -- Workshop interior height

function MapBuilder.build(): (any, { string })
	local failures: { string } = {}
	local manifest: any = {
		benchSlots = {},
		glyphSpawns = {},
		lamps = {},
		hauntDoors = {},
		windowPanes = {},
		joinSquares = {},
	}

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

	-- One-Place-plus-ReserveServer topology (PACKET_1_LOBBY_SYSTEMS.md, Join Squares §2): a live
	-- reserved shift server has no players walking the Hub and a public lobby server never runs a
	-- shift in-place, so each server kind only needs to build the half of the map it will actually
	-- use. Both halves always build in Studio (ServerKind.isSameServerMode() is always true there),
	-- so this has zero effect on today's Studio playtest.
	local buildLobby = ServerKind.isSameServerMode() or ServerKind.isPublicLobbyServer()
	local buildWorkshop = ServerKind.isSameServerMode() or ServerKind.isReservedShiftServer()

	-- ============================== HUB ==============================
	if buildLobby then

	segment("EntryAlley", function()
		local center = HUB + Vector3.new(0, 0, -42)
		box(CFrame.new(center) * CFrame.new(0, -0.5, 0), Vector3.new(10, 1, 24), FLOOR, Enum.Material.Concrete, "Floor")
		-- side walls (full length -- alley is only open at its two short ends)
		box(CFrame.new(center + Vector3.new(-5, H_HUB / 2, 0)), Vector3.new(1, H_HUB, 24), WALL, Enum.Material.Brick, "Wall")
		box(CFrame.new(center + Vector3.new(5, H_HUB / 2, 0)), Vector3.new(1, H_HUB, 24), WALL, Enum.Material.Brick, "Wall")
		-- dead end (back wall) with a leaning sign
		local backWall = box(CFrame.new(center + Vector3.new(0, H_HUB / 2, -12)), Vector3.new(10, H_HUB, 1), WALL, Enum.Material.Brick, "Wall")
		local sign = box(
			backWall.CFrame * CFrame.new(0, -2, 0.6) * CFrame.Angles(0, 0, math.rad(6)),
			Vector3.new(4, 2, 0.2),
			WOOD_DARK,
			Enum.Material.WoodPlanks,
			"NoAdmittanceSign"
		)
		surfaceText(sign, Enum.NormalId.Back, { { text = "NO ADMITTANCE", size = 24 } })
		-- invisible guard walls so nobody can clip past the alley's open top
		guardWall(CFrame.new(center + Vector3.new(0, H_HUB + 4, 0)), Vector3.new(10, 4, 24))
		-- spawn, faces north (+Z) toward the Plaza
		local spawn = Instance.new("SpawnLocation")
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Enabled = true
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Size = Vector3.new(8, 1, 8)
		spawn.CFrame = CFrame.new(HUB + Vector3.new(0, 0.5, -50))
		CollectionService:AddTag(spawn, "LobbySpawn")
		spawn.Parent = root
		manifest.lobbySpawn = spawn
		-- one flickering lamp (graft #1: flicker stays confined to the alley)
		hubLamp(center + Vector3.new(0, 1.1, 0), true)
		-- chalkboard, read on the walk in
		local chalk = part({
			Name = "Chalkboard",
			CFrame = CFrame.new(center + Vector3.new(-3.2, 7, 8)) * CFrame.Angles(0, math.rad(20), 0),
			Size = Vector3.new(9, 6, 0.4),
			Color = Color3.fromRGB(24, 30, 26),
			Material = Enum.Material.SmoothPlastic,
			Tag = "Chalkboard",
		})
		surfaceText(chalk, Enum.NormalId.Back, {
			{ text = "HOUSE RULES", size = 34, color = Color3.fromRGB(232, 226, 205) },
			{ text = "1. CARE for every doll.", size = 20 },
			{ text = "2. WATCH for the wrong one.", size = 20 },
			{ text = "3. FIND the glyphs. Match the ledger.", size = 20 },
			{ text = "4. BANISH it before the Presence takes you.", size = 20 },
			{ text = '"...and always tie the silver ribbon before a banishing. Always." — The Dollmaker', size = 15, color = Color3.fromRGB(170, 150, 190) },
		})
		manifest.chalkboard = chalk
	end)

	segment("Plaza", function()
		box(CFrame.new(HUB) * CFrame.new(0, -0.5, 0), Vector3.new(70, 1, 60), STONE, Enum.Material.Slate, "Floor")
		-- invisible guard walls around the open-sky Plaza's outer edges (A2-class fall-through prevention)
		guardWall(CFrame.new(HUB + Vector3.new(-35.5, 10, 0)), Vector3.new(1, 20, 60))
		guardWall(CFrame.new(HUB + Vector3.new(35.5, 10, 0)), Vector3.new(1, 20, 60))
		guardWall(CFrame.new(HUB + Vector3.new(0, 10, 30.5)), Vector3.new(70, 20, 1))
		-- steady corner lamps (graft #1: never flicker, so a haunt/lighting event never makes the
		-- join squares unreadable on a phone screen)
		hubLamp(HUB + Vector3.new(-28, 1.1, -24))
		hubLamp(HUB + Vector3.new(28, 1.1, -24))
		hubLamp(HUB + Vector3.new(-28, 1.1, 22))
		hubLamp(HUB + Vector3.new(28, 1.1, 22))
	end)

	segment("Fountain", function()
		local basin = part({
			Name = "FountainBasin",
			Shape = Enum.PartType.Cylinder,
			CFrame = CFrame.new(HUB + Vector3.new(0, 1, 14)) * CFrame.Angles(0, 0, math.rad(90)),
			Size = Vector3.new(2, 14, 14),
			Color = STONE,
			Material = Enum.Material.Concrete,
		})
		box(basin.CFrame * CFrame.new(2.2, 0, 0) * CFrame.Angles(0, 0, math.rad(-90)), Vector3.new(1.4, 1.4, 1.4), Color3.fromRGB(30, 26, 34), Enum.Material.SmoothPlastic, "PorcelainStatue")
	end)

	segment("JoinSquares", function()
		-- Diamond-shaped floor tiles: a rotated-square footprint, glowing Neon material. One BasePart
		-- per square, directly recolorable by JoinSquareService (idle/occupied/locking) -- see
		-- docs/packets/PACKET_1_LOBBY_SYSTEMS.md's map addendum for why a solid diamond (not a hollow
		-- outline) was chosen: it's the same visual read with far less construction risk, and it's a
		-- pure decoration upgrade later if the team wants a true hollow outline.
		local positions = {
			HUB + Vector3.new(-24, 0.15, -6),
			HUB + Vector3.new(-12, 0.15, 2),
			HUB + Vector3.new(0, 0.15, 5),
			HUB + Vector3.new(12, 0.15, 2),
			HUB + Vector3.new(24, 0.15, -6),
		}
		for i, pos in positions do
			local tile = part({
				Name = "JoinSquare" .. i,
				CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(45), 0),
				Size = Vector3.new(7, 0.3, 7),
				Color = Config.JoinSquares.IdleColor,
				Material = Enum.Material.Neon,
				Transparency = 0.1,
				CanCollide = false,
				Tag = "JoinSquare",
			})
			tile:SetAttribute("SquareIndex", i)
			table.insert(manifest.joinSquares, tile)
		end
	end)

	segment("InvitePostbox", function()
		local post = box(CFrame.new(HUB + Vector3.new(4, 1.5, -26)), Vector3.new(1.4, 3, 1.4), Color3.fromRGB(120, 34, 30), Enum.Material.Metal, "InvitePostbox")
		CollectionService:AddTag(post, "InviteKiosk")
		manifest.inviteKiosk = post
		manifest.invitePrompt = prompt(post, "Send for a Friend", "Postbox")
	end)

	segment("DollmakerShop", function()
		-- A solid, closed facade -- no door cut through the wall, no interior to build or seal off.
		-- Players never walk inside; the ProximityPrompt is what "enters" the shop.
		local center = HUB + Vector3.new(0, 0, 38)
		box(CFrame.new(center) * CFrame.new(0, H_HUB / 2, 0), Vector3.new(26, H_HUB, 16), WALL, Enum.Material.Brick, "ShopBuilding")
		box(CFrame.new(center) * CFrame.new(0, H_HUB + 3, 0), Vector3.new(28, 6, 18), WOOD_DARK, Enum.Material.Wood, "RoofCap")
		local front = center + Vector3.new(0, 0, -8.1)
		litWindow(CFrame.new(front + Vector3.new(-7, 7, 0)), 3)
		litWindow(CFrame.new(front + Vector3.new(7, 7, 0)), 3)
		local sign = box(CFrame.new(front + Vector3.new(0, H_HUB + 0.5, 0)), Vector3.new(14, 3, 0.5), WOOD_DARK, Enum.Material.Wood, "ShopSign")
		surfaceText(sign, Enum.NormalId.Back, { { text = "THE DOLLMAKER'S", size = 30 } })
		local stoop = box(CFrame.new(front + Vector3.new(0, 0.3, -1.5)), Vector3.new(6, 0.6, 3), STONE, Enum.Material.Concrete, "ShopStoop")
		CollectionService:AddTag(stoop, "ShopKiosk")
		manifest.shopKiosk = stoop
		manifest.shopPrompt = prompt(stoop, "Enter the Shop", "The Dollmaker's")
	end)

	segment("ClassesShopfront", function()
		local center = HUB + Vector3.new(-28, 0, 36)
		box(CFrame.new(center) * CFrame.new(0, H_HUB / 2, 0), Vector3.new(16, H_HUB, 12), WALL, Enum.Material.Brick, "ClassesBuilding")
		box(CFrame.new(center) * CFrame.new(0, H_HUB + 3, 0), Vector3.new(18, 6, 14), WOOD_DARK, Enum.Material.Wood, "RoofCap")
		local front = center + Vector3.new(0, 0, -6.1)
		litWindow(CFrame.new(front + Vector3.new(0, 6.5, 0)), 2)
		-- crossed boarding over the window, matching the "boarded shopfront" reference look
		box(CFrame.new(front + Vector3.new(0, 6.5, 0.15)) * CFrame.Angles(0, 0, math.rad(18)), Vector3.new(6, 0.3, 0.15), BOARD_WOOD, Enum.Material.WoodPlanks, "Board")
		box(CFrame.new(front + Vector3.new(0, 6.5, 0.15)) * CFrame.Angles(0, 0, math.rad(-18)), Vector3.new(6, 0.3, 0.15), BOARD_WOOD, Enum.Material.WoodPlanks, "Board")
		local sign = box(CFrame.new(front + Vector3.new(0, H_HUB - 1, 0)), Vector3.new(9, 2, 0.4), WOOD_DARK, Enum.Material.Wood, "TailorSign")
		surfaceText(sign, Enum.NormalId.Back, { { text = "TAILOR", size = 22, color = Color3.fromRGB(150, 140, 130) } })
		local stoop = box(CFrame.new(front + Vector3.new(0, 0.3, -1.2)), Vector3.new(5, 0.6, 2.4), STONE, Enum.Material.Concrete, "ClassesStoop")
		CollectionService:AddTag(stoop, "ClassesKiosk")
		manifest.classesKiosk = stoop
		manifest.classesPrompt = prompt(stoop, "Browse Classes", "Tailor's Shopfront")
	end)

	segment("ApothecaryShopfront", function()
		-- Pure backdrop dressing -- balances the skyline, sells nothing, no prompt.
		local center = HUB + Vector3.new(28, 0, 36)
		box(CFrame.new(center) * CFrame.new(0, H_HUB / 2, 0), Vector3.new(16, H_HUB, 12), WALL, Enum.Material.Brick, "ApothecaryBuilding")
		box(CFrame.new(center) * CFrame.new(0, H_HUB + 3, 0), Vector3.new(18, 6, 14), WOOD_DARK, Enum.Material.Wood, "RoofCap")
		local front = center + Vector3.new(0, 0, -6.1)
		box(CFrame.new(front + Vector3.new(0, 6.5, 0)), Vector3.new(4.5, 4, 0.2), Color3.fromRGB(90, 100, 90), Enum.Material.Glass, "BoardedWindow")
		box(CFrame.new(front + Vector3.new(0, 6.5, 0.15)) * CFrame.Angles(0, 0, math.rad(18)), Vector3.new(5, 0.3, 0.15), BOARD_WOOD, Enum.Material.WoodPlanks, "Board")
		box(CFrame.new(front + Vector3.new(0, 6.5, 0.15)) * CFrame.Angles(0, 0, math.rad(-18)), Vector3.new(5, 0.3, 0.15), BOARD_WOOD, Enum.Material.WoodPlanks, "Board")
	end)

	segment("JournalNoticeboard", function()
		local post = box(CFrame.new(HUB + Vector3.new(18, 3, 6)), Vector3.new(0.4, 6, 0.4), WOOD_DARK, Enum.Material.Wood, "NoticeboardPost")
		local board = box(CFrame.new(HUB + Vector3.new(18, 5, 6)), Vector3.new(4.5, 3.5, 0.3), Color3.fromRGB(150, 120, 90), Enum.Material.Fabric, "JournalBoard")
		CollectionService:AddTag(board, "JournalKiosk")
		manifest.journalKiosk = board
		surfaceText(board, Enum.NormalId.Front, { { text = "THE DOLLMAKER'S", size = 18 }, { text = "JOURNAL", size = 26 } })
		manifest.journalPrompt = prompt(board, "Read the Journal", "Noticeboard")
		local _ = post
	end)

	segment("LeaderboardBoards", function()
		-- TWO separate boards per the reference screenshots: best-shift and dolls-cleared, flanking
		-- the Shop.
		local shiftBoard = box(
			CFrame.new(HUB + Vector3.new(-16, 6.5, 29.4)),
			Vector3.new(9, 7, 0.4),
			WOOD_DARK,
			Enum.Material.Wood,
			"LeaderboardBoard"
		)
		CollectionService:AddTag(shiftBoard, "LeaderboardBoard")
		manifest.leaderboardBoard = shiftBoard
		local patientsBoard = box(
			CFrame.new(HUB + Vector3.new(16, 6.5, 29.4)),
			Vector3.new(9, 7, 0.4),
			WOOD_DARK,
			Enum.Material.Wood,
			"PatientsBoard"
		)
		CollectionService:AddTag(patientsBoard, "PatientsBoard")
		manifest.patientsBoard = patientsBoard
	end)

	-- Kept for compatibility with ShiftManager.setDoorLocked (it nil-safely no-ops if the Slab child
	-- is absent, per docs/packets/PACKET_1_LOBBY_SYSTEMS.md Track C: repurposed as a static
	-- "Shift N in progress" plaque, never a physical CanCollide slab -- entry to a shift is gated by
	-- the join-square countdown now, not a walked-and-locked door.
	segment("WorkshopStatusPlaque", function()
		local doorModel = Instance.new("Model")
		doorModel.Name = "WorkshopDoor"
		CollectionService:AddTag(doorModel, "WorkshopDoor")
		doorModel.Parent = root
		local sign = box(CFrame.new(WS + Vector3.new(0, H_WS + 1, 8.4)), Vector3.new(6, 2, 0.3), Color3.fromRGB(30, 24, 28), nil, "Sign")
		sign.Parent = doorModel
		surfaceText(sign, Enum.NormalId.Back, { { text = "", size = 30 } })
		manifest.workshopDoor = doorModel
		manifest.workshopDoorSign = sign
	end)
	end -- buildLobby

	-- ============================== WORKSHOP ==============================
	if buildWorkshop then
	-- One plus-shaped footprint: two overlapping slabs (built together, before any wall), then
	-- perimeter walls on the OUTER boundary only. No interior wall is ever placed, which is what
	-- makes the A1 (sealed Banish room) and A2 (void gap) bug class structurally impossible here,
	-- not just carefully avoided.

	segment("WorkshopShell", function()
		plusSlab({
			{ center = WS, footprint = Vector3.new(68, 1, 18) }, -- horizontal arm: Bench Wing + Foyer + Banish Wing
			{ center = WS + Vector3.new(0, 0, -18), footprint = Vector3.new(16, 1, 36) }, -- vertical arm: Ledger Nook, overlaps the ENTIRE Foyer band (Z -9..9), an 18-stud overlap not an edge-touch
		}, H_WS)

		-- Outer boundary walls, traced clockwise from the horizontal arm's SE corner. Every segment
		-- below is a plain solid wall -- there is no gap anywhere in this list, because there is
		-- nowhere in this design a player is meant to walk OUT of the plus-shape.
		local wallT = 1
		local h2 = H_WS / 2
		-- south wall (full width, X -34..34 at Z=9)
		box(CFrame.new(WS + Vector3.new(0, h2, 9)), Vector3.new(68, H_WS, wallT), WALL, Enum.Material.Wood, "Wall")
		-- Banish Wing east wall (X=34, Z -9..9)
		box(CFrame.new(WS + Vector3.new(34, h2, 0)), Vector3.new(wallT, H_WS, 18), WALL, Enum.Material.Wood, "Wall")
		-- Banish Wing north wall (Z=-9, X 8..34)
		box(CFrame.new(WS + Vector3.new(21, h2, -9)), Vector3.new(26, H_WS, wallT), WALL, Enum.Material.Wood, "Wall")
		-- Ledger Nook east wall (X=8, Z -27..-9)
		box(CFrame.new(WS + Vector3.new(8, h2, -18)), Vector3.new(wallT, H_WS, 18), WALL, Enum.Material.Wood, "Wall")
		-- Ledger Nook north wall (Z=-27, X -8..8, the "top" of the whole plus-shape)
		box(CFrame.new(WS + Vector3.new(0, h2, -27)), Vector3.new(16, H_WS, wallT), WALL, Enum.Material.Wood, "Wall")
		-- Ledger Nook west wall (X=-8, Z -27..-9)
		box(CFrame.new(WS + Vector3.new(-8, h2, -18)), Vector3.new(wallT, H_WS, 18), WALL, Enum.Material.Wood, "Wall")
		-- Bench Wing north wall (Z=-9, X -34..-8)
		box(CFrame.new(WS + Vector3.new(-21, h2, -9)), Vector3.new(26, H_WS, wallT), WALL, Enum.Material.Wood, "Wall")
		-- Bench Wing west wall (X=-34, Z -9..9)
		box(CFrame.new(WS + Vector3.new(-34, h2, 0)), Vector3.new(wallT, H_WS, 18), WALL, Enum.Material.Wood, "Wall")

		-- teleport landing point, default Enabled=true (a live reserved shift server has no
		-- lobbySpawn to protect against, and TeleportAsync arrivals need somewhere enabled the
		-- instant the server boots -- LobbyService.setShiftSpawnActive still toggles this in Studio's
		-- single-server mode exactly as before).
		local wspawn = Instance.new("SpawnLocation")
		wspawn.Anchored = true
		wspawn.Neutral = true
		wspawn.Enabled = true
		wspawn.Transparency = 1
		wspawn.CanCollide = false
		wspawn.Size = Vector3.new(6, 1, 6)
		wspawn.CFrame = CFrame.new(WS + Vector3.new(0, 0.5, 0))
		CollectionService:AddTag(wspawn, "WorkshopSpawn")
		wspawn.Parent = root
		manifest.workshopSpawn = wspawn
	end)

	segment("BenchWing", function()
		local c = WS + Vector3.new(-21, 0, 0)
		lamp(c + Vector3.new(4, 1.1, -6))
		lamp(c + Vector3.new(4, 1.1, 6))
		local bench = box(CFrame.new(c + Vector3.new(-10, 2, 0)), Vector3.new(4, 4, 16), WOOD, Enum.Material.Wood, "Workbench")
		CollectionService:AddTag(bench, "Workbench")
		manifest.workbench = bench
		for i = 1, 5 do
			local z = -8 + (i - 1) * 4
			local slot = part({
				Name = "BenchSlot" .. i,
				CFrame = CFrame.new(c + Vector3.new(-10, 4.6, z)),
				Size = Vector3.new(1, 1, 1),
				Transparency = 1,
				CanCollide = false,
				CanQuery = false,
				Tag = "BenchSlot",
			})
			table.insert(manifest.benchSlots, slot)
		end
		local spool = part({
			Name = "RibbonSpool",
			-- dz=7.2 (not 8.5): south wall's inner face is at Z=8.5, so 8.5 would clip the spool
			-- 0.8 studs into it; 7.2 keeps it seated on the bench top with a clean 0.5-stud gap.
			CFrame = CFrame.new(c + Vector3.new(-10, 4.8, 7.2)),
			Size = Vector3.new(1.6, 1.6, 1.6),
			Color = Color3.fromRGB(200, 205, 215),
			Material = Enum.Material.Metal,
			Tag = "RibbonSpool",
		})
		manifest.ribbonSpool = spool
		manifest.ribbonPrompt = prompt(spool, "Take Silver Ribbon", "Ribbon Spool")
		-- shelf decor (former "storage alcove"), along the north wall segment of this wing. Local X
		-- range for this wing is roughly -13..13 (west wall at -13, workbench occupies -13..-9, the
		-- closet-nook door hinge sits at -4) -- these three shelves at local X 1/5.5/10 stay clear of
		-- both and well inside the east wall at +13.
		for i = 1, 3 do
			-- dz=-7.5 (not -8.3): north wall's inner face is at Z=-8.5, so -8.3 would clip the
			-- 0.6-half-depth shelf 0.4 studs into it; -7.5 keeps a clean 0.4-stud gap.
			local shelf = box(CFrame.new(c + Vector3.new(1 + (i - 1) * 4.5, 5, -7.5)), Vector3.new(4, 0.6, 1.2), WOOD_DARK, Enum.Material.Wood, "Shelf")
			for j = 1, 3 do
				box(
					shelf.CFrame * CFrame.new(-1.2 + (j - 1) * 1.2, 1.2, 0),
					Vector3.new(0.7, 1.8, 0.6),
					Color3.fromRGB(25, 20, 24),
					Enum.Material.SmoothPlastic,
					"DecorDoll"
				)
			end
		end
		-- window on the outer (west) wall. Offset is WS-relative (matches the west wall's WS-relative
		-- X=-34 from the boundary wall list above), NOT c-relative -- c is already offset -21 from WS.
		table.insert(manifest.windowPanes, litWindow(CFrame.new(WS + Vector3.new(-33.4, 8, 0)) * CFrame.Angles(0, math.rad(90), 0), 0))
		-- decorative closet nook (never load-bearing -- it's mounted flush on a solid wall, not an
		-- opening cut through one)
		local doorModel = Instance.new("Model")
		doorModel.Name = "HauntDoor1"
		CollectionService:AddTag(doorModel, "HauntDoor")
		doorModel.Parent = root
		local hinge = part({
			Name = "Hinge",
			CFrame = CFrame.new(c + Vector3.new(-4, 5, -8.5)),
			Size = Vector3.new(0.4, 10, 0.4),
			Transparency = 1,
			CanCollide = false,
			Parent = doorModel,
		})
		doorModel.PrimaryPart = hinge
		part({
			Name = "Panel",
			CFrame = hinge.CFrame * CFrame.new(0, 0, 0.3),
			Size = Vector3.new(3, 9.6, 0.5),
			Color = WOOD_DARK,
			Material = Enum.Material.Wood,
			CanCollide = false,
			Parent = doorModel,
		})
		table.insert(manifest.hauntDoors, doorModel)
	end)

	segment("LedgerNook", function()
		local c = WS + Vector3.new(0, 0, -18)
		lamp(c + Vector3.new(0, 1.1, -3))
		local desk = box(CFrame.new(c + Vector3.new(0, 2, -6)), Vector3.new(8, 4, 4), WOOD, Enum.Material.Wood, "LedgerDesk")
		CollectionService:AddTag(desk, "LedgerDesk")
		local book = box(desk.CFrame * CFrame.new(0, 2.3, 0) * CFrame.Angles(0, 0, math.rad(8)), Vector3.new(3, 0.6, 2.2), Color3.fromRGB(90, 40, 40), Enum.Material.Fabric, "LedgerBook")
		manifest.ledgerDesk = desk
		manifest.ledgerPrompt = prompt(book, "Open Ledger", "Spirit Ledger")
		local rack = part({
			Name = "DetectorRack",
			CFrame = CFrame.new(c + Vector3.new(6, 3, -6)),
			Size = Vector3.new(2, 6, 2),
			Color = WOOD_DARK,
			Tag = "DetectorRack",
		})
		manifest.detectorRack = rack
		-- decorative closet nook on the west wall
		local doorModel = Instance.new("Model")
		doorModel.Name = "HauntDoor2"
		CollectionService:AddTag(doorModel, "HauntDoor")
		doorModel.Parent = root
		local hinge = part({
			Name = "Hinge",
			CFrame = CFrame.new(c + Vector3.new(-7.5, 5, 4)) * CFrame.Angles(0, math.rad(90), 0),
			Size = Vector3.new(0.4, 10, 0.4),
			Transparency = 1,
			CanCollide = false,
			Parent = doorModel,
		})
		doorModel.PrimaryPart = hinge
		part({
			Name = "Panel",
			CFrame = hinge.CFrame * CFrame.new(0, 0, 0.3),
			Size = Vector3.new(3, 9.6, 0.5),
			Color = WOOD_DARK,
			Material = Enum.Material.Wood,
			CanCollide = false,
			Parent = doorModel,
		})
		table.insert(manifest.hauntDoors, doorModel)
	end)

	segment("BanishWing", function()
		local c = WS + Vector3.new(21, 0, 0)
		lamp(c + Vector3.new(4, 1.1, 0))
		local boxModel = Instance.new("Model")
		boxModel.Name = "BanishBox"
		CollectionService:AddTag(boxModel, "BanishBox")
		boxModel.Parent = root
		local base = part({
			Name = "Base",
			CFrame = CFrame.new(c + Vector3.new(9, 2.2, 0)),
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
		-- window on the outer (east) wall. Offset is WS-relative (matches the east wall's WS-relative
		-- X=34 from the boundary wall list above), NOT c-relative -- c is already offset +21 from WS.
		table.insert(manifest.windowPanes, litWindow(CFrame.new(WS + Vector3.new(33.4, 8, 0)) * CFrame.Angles(0, math.rad(-90), 0), 0))
	end)

	segment("GlyphSpawns", function()
		-- 3 per wing, all comfortably clear of walls/props (A3/B13 fix baked in from the start: none
		-- of these sit in a corridor behind a locked door -- there is no corridor anymore -- and none
		-- overlap the Banish Box's deposit prompt).
		local spots = {
			-- Bench Wing
			WS + Vector3.new(-30, 5, 5),
			WS + Vector3.new(-14, 2, -6),
			WS + Vector3.new(-24, 7, 6),
			-- Ledger Nook
			WS + Vector3.new(-4, 2, -14),
			WS + Vector3.new(5, 6, -22),
			WS + Vector3.new(0, 2, -25),
			-- Banish Wing
			WS + Vector3.new(28, 2, -6),
			WS + Vector3.new(14, 6, 5),
			WS + Vector3.new(30, 7, 2),
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
	end -- buildWorkshop

	segment("Atmosphere", function()
		Lighting.FogEnd = 140
		Lighting.FogStart = 30
		Lighting.FogColor = Color3.fromRGB(18, 14, 22)
		Lighting.ClockTime = 1.5
		local atmo = Instance.new("Atmosphere")
		atmo.Density = 0.35
		atmo.Color = Color3.fromRGB(120, 110, 130)
		atmo.Parent = Lighting
		-- collect Workshop lamps into the manifest (Hub lamps are deliberately untagged -- see
		-- hubLamp() -- so HauntService's LightsOutBeat can never affect players still in the Hub)
		for _, inst in CollectionService:GetTagged("Lamp") do
			table.insert(manifest.lamps, inst)
		end
	end)

	Util.log(("MapBuilder: built with %d failed segment(s)"):format(#failures))
	return manifest, failures
end

function MapBuilder.init(_ctx: any) end

return MapBuilder
