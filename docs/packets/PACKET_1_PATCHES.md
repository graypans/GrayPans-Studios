# Packet 1 — Ready-to-apply Patches (Blockers A1–A4, Bugs B1–B13)

Source: 4 independent agents, each assigned one cluster of confirmed bugs from
`docs/PLAYTEST_REPORT_2026-08-15.md` (the first-ever human playtest, 2026-08-15) and
`CHECKLIST_1.md` §3/§4. Each agent read the *actual current* repo before writing its fix, so line
numbers below should be accurate as of this packet's drafting — but re-verify against the live file
before applying, since other patches in this same packet (and the map redesign in
`PACKET_1_MAP_DESIGN.md`) will shift things around.

**No code in this file has been applied to the repo.** Everything below is copy-paste-ready but
unapplied — it's written for the cloud Claude session to review and land as real commits.

---

## READ THIS FIRST — `ShiftManager.luau` needs a single merged pass, not 2 separate patches

**P2 (Banish & shift-state bugs) and P3 (Presence pacing) both give a full replacement of
`ShiftManager.luau`'s `transition()` function, and P3 also fully replaces `armWatchdog()` and
`ShiftManager.init()`.** They were written by two agents who couldn't see each other's work, so they
independently based their "full function" listings on the *original* unpatched file — applying them
as two sequential full-file pastes will make the second one silently overwrite the first one's fixes.
**Do not apply them as two independent patches.** Merge them by hand (or have cloud Claude do a single
pass) in this order:

1. **Start from P2's version of `transition()`.** It already contains: the B4 fix (LobbyIdle resets
   `strikes`/etc. *before* `broadcastState()`), the A4 fix (marked-doll-name snapshot at `ShiftIntro`,
   `returnToBench` branching in the wrong-banish path — though that branching itself lives in
   `onBanishResolved`, not `transition`), and the B7 fix (`shiftReached = shiftNumber`, not
   `shiftNumber - 1`, and `traitorName` reads the mark-time snapshot).
2. **Layer P3's `runEndReason` tracking on top.** Add the `runEndReason` local; in `armWatchdog`,
   tag `runEndReason = "watchdog"` before transitioning to `RunEnd` from the `ShiftActive` case (drop
   the generic watchdog toast for *that specific* case only, per P3); in `ShiftManager.init`'s
   `PresenceService.onMaxed` callback, tag `runEndReason = "presence"` before transitioning. Inside
   `transition`'s `RunEnd` branch, replace the always-fire-the-scare block with P3's `reason`-branch
   (timeout → calm `ShiftTimeout` toast/haunt, presence → the existing scare) — but **keep P2's
   `traitorName`/`shiftReached` fix** in the payload construction, not P3's stale version (P3's own
   listing still shows the *old* `shiftReached = shiftNumber - 1` and a live `DollService` lookup for
   `traitorName`, because it was written against the pre-A4/B7 file). Add P3's `reason` field to the
   `Recap` payload.
3. **Layer `PACKET_1_LOBBY_SYSTEMS.md`'s three system tracks on top of that merged base**, in the
   order and exact insertion points described in that packet's own "integration conflicts" section at
   the top (Economy's coin-award hooks, Social's `onShiftCleared` hook, Join-Squares' `beginShiftFor`
   + `RunEnd`'s teleport-vs-`sendGroupHome` branch). Do this as one final pass over the file, not four
   more sequential full-file pastes.

Everything else in this document (P1, P4, and P2/P3's changes to *other* files) applies independently
with no conflicts.

---

## P1 — Map geometry & world-building bugs (stopgap patch for the CURRENT `MapBuilder`)

> **Superseded once the map redesign in `PACKET_1_MAP_DESIGN.md` ships** — every fix below is a
> stopgap so today's build is playable while that redesign is in progress. If the team wants to skip
> straight to the redesign, this whole section can be skipped; if they want a playable build *today*
> while the redesign is being built, apply this first (it's independent of everything else in this
> packet).

> Source: `docs/PLAYTEST_REPORT_2026-08-15.md`, first human playtest. All fixes below are grounded in
> the actual current contents of the files as of this drafting pass (line numbers cited are current,
> not the possibly-drifted numbers from the original bug report).
>
> Layout constants used throughout (from `MapBuilder.luau` line ~141-143): `LOBBY = Vector3.new(0,0,0)`,
> `SHOP = Vector3.new(240,0,0)`, `H = 14`. The `room()` helper (lines 51-82) always carves gaps as
> **exactly 8 studs wide, centered on the wall's own center-axis coordinate**.

### A1 — Banish room is sealed

**Files:** `src/server/Services/MapBuilder.luau` — `BenchRoom` segment (~line 287-332) and `BanishRoom` segment (~line 372-410).

**Current behavior:** The bench room is built with `room(SHOP, 44, 36, H, { W = true, N = true, S = true })` — no `E = true`. A separate part named `BanishDoorwayFloorPatch` is placed exactly where a doorway should be, but it's a solid, full-height (`H` tall), default-material `WoodPlanks` box, not a floor patch. Net effect: the Banish Box room is fully walled off; a correct banish (the shift-win condition) is unreachable.

**Root cause:** The bench room's own east wall was never given a door gap, and the "doorway connector" part that was added instead is solid and sits squarely in the gap's footprint, plugging it rather than bridging it.

**Why this is safe to fix by adding `E = true`:** The bench room floor (`x: 218–262`) and the Banish room floor (`x: 262–290`, from `room(Vector3.new(SHOP.X+36, 0, SHOP.Z), 28, 22, H-2, {W=true})`) already touch exactly at `x = 262` — there is **no Z-gap or X-gap between the two floors**, only a missing wall opening. Both rooms are centered on `SHOP.Z = 0`, so `room()`'s gap-centering math puts both the bench room's new E-wall gap and the Banish room's existing W-wall gap at the same place: `z ∈ [-4, 4]` — exactly the footprint of the old `BanishDoorwayFloorPatch` part. Once the bench room carves its own gap, the two rooms connect cleanly and the patch part becomes redundant (and actively bad, since it was solid).

**Fix — `BenchRoom` segment, full corrected block:**

```lua
	segment("BenchRoom", function()
		-- main workshop: bench room
		room(SHOP, 44, 36, H, { W = true, N = true, S = true, E = true })
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
```

Only change from current: `{ W = true, N = true, S = true }` → `{ W = true, N = true, S = true, E = true }`. Everything else in this segment is unchanged (quoted in full so it can be pasted wholesale).

**Fix — `BanishRoom` segment, full corrected block (removes the solid plug part):**

```lua
	segment("BanishRoom", function()
		-- East of the bench room. Bench room now carves its own E-wall gap (see BenchRoom segment,
		-- E = true) and this room's W = true gap already aligns with it — both rooms are centered on
		-- SHOP.Z, so room()'s gap math puts both gaps at the same z ∈ [-4, 4]. Floors already touch
		-- exactly at x = 262 (bench floor ends there, this room's floor starts there), so no bridge
		-- part is needed here — removed the old solid "BanishDoorwayFloorPatch" that used to plug the
		-- doorway shut.
		room(Vector3.new(SHOP.X + 36, 0, SHOP.Z), 28, 22, H - 2, { W = true })
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
```

- **Config notes:** none — no new tunables needed; the 8-stud gap width is already baked into `room()`'s existing (non-Config) constant.
- **Remote notes:** none.
- **Test notes:** none — `tests/logic.spec.luau` only covers `src/shared/Logic/*`, none of which touch map geometry.

### A2 — Void gaps at two doorways (ledger-desk room, storage alcove), players fall out of the world

**Files:** `src/server/Services/MapBuilder.luau` — new segment to insert between the existing `LedgerRoom` segment (~line 353-370) and `BanishRoom` segment (~line 372).

**Current behavior:** `room()` only cuts gaps into **walls**; each room's **floor** is always a single solid slab covering that room's own footprint, with no gap logic at all. Two pairs of adjacent rooms have wall-gaps that line up in X, but their floor footprints don't touch in Z:
- Bench room floor (`room(SHOP, 44, 36, H, {...})`) spans `z: -18` to `+18`.
- Storage alcove floor (`room(Vector3.new(SHOP.X, 0, SHOP.Z - 36), 20, 20, H-4, {S=true})`) spans `z: -46` to `-26`.
- Ledger room floor (`room(Vector3.new(SHOP.X, 0, SHOP.Z + 36), 24, 24, H-4, {N=true})`) spans `z: +24` to `+48`.

That leaves a real **8-stud void** between bench (`z=-18`) and storage (`z=-26`), and a **6-stud void** between bench (`z=+18`) and ledger (`z=+24`). Confirmed live via raycasts at those world positions hitting nothing.

**Root cause:** `room()`'s wall-gap carving creates a walkable-looking doorway in the walls, but nothing ties the two rooms' floor slabs together across the physical distance between their footprints.

**Why a floor-only bridge is sufficient (no side walls needed):** every gap on both sides of each void is already centered on `x = 236…244` (both rooms share `center.X = SHOP.X = 240`). The **solid** wall segments on either side of that opening already stop a player from reaching the floor edge anywhere outside the doorway, so a player can only approach the void through the 8-stud-wide doorway opening itself. A floor slab exactly matching that opening's width closes the fall-through hazard completely.

**Fix — insert a new segment (place it after `LedgerRoom`, before `BanishRoom`):**

```lua
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

	-- NEW SEGMENT: bridges the two doorway voids room()'s per-room floor slabs leave behind. Both
	-- gaps are 8 studs wide in X (room() always centers gaps on the wall's own axis coordinate, and
	-- every room here shares center.X = SHOP.X = 240, so the openings line up). Depth (Z) is sized to
	-- exactly close each specific void: bench↔storage is 8 studs (bench floor ends z=-18, storage
	-- floor starts z=-26); bench↔ledger is 6 studs (bench floor ends z=+18, ledger floor starts z=+24).
	segment("DoorwayBridges", function()
		box(
			CFrame.new(SHOP.X, -0.5, -22),
			Vector3.new(8, 1, 8),
			FLOOR,
			Enum.Material.Wood,
			"StorageBridgeFloor"
		)
		box(
			CFrame.new(SHOP.X, -0.5, 21),
			Vector3.new(8, 1, 6),
			FLOOR,
			Enum.Material.Wood,
			"LedgerBridgeFloor"
		)
	end)

	segment("BanishRoom", function()
```

(The `BanishRoom` segment body itself is unchanged here except for the A1 fix above — shown fully under A1, not repeated.)

- **Config/Remote/Test notes:** none.

### A3 — Two glyph spawn markers are behind the shift-locked workshop door

**Files:** `src/server/Services/MapBuilder.luau` — `GlyphSpawns` segment (~line 445-470, primary fix). Context confirmed (no code change needed there) in `src/server/Services/ShiftManager.luau`'s `setDoorLocked` function — `setDoorLocked(true)` correctly keeps `Slab.CanCollide = true` for the entire `ShiftActive` duration; that's intended behavior for keeping non-participants out mid-shift, not itself a bug. The bug is purely that two glyph markers were placed on the wrong (corridor) side of that door.

**Current behavior:** `GlyphSpawn9` (`Vector3.new(120, 2, 4)`) and `GlyphSpawn10` (`Vector3.new(150, 8, -4)`) sit in the outer Lobby↔Workshop corridor (`x: 22–218`), west of the `WorkshopDoor` slab (`x ≈ 217`). Since the door is `CanCollide = true` for the entire shift, any shift that draws one of these two markers makes that glyph permanently uncollectable until the shift ends. Confirmed live in both playtest runs.

**Root cause:** `docs/INTERFACES.md`'s MapBuilder contract calls for "≥8 glyph spawn markers spread across ALL workshop rooms" — i.e., **inside** the shift-locked door, not in the connecting corridor.

**Fix — full corrected `GlyphSpawns` segment**, relocating `GlyphSpawn9` and `GlyphSpawn10` into workshop rooms (storage alcove and ledger room respectively). This same block also relocates `GlyphSpawn7`, which is the fix for **B13** below — both bugs live in this one array, so there is exactly one edit to make here, not two:

```lua
	segment("GlyphSpawns", function()
		local spots = {
			SHOP + Vector3.new(-19, 5.5, 10), -- 1: bench room shadow corner
			SHOP + Vector3.new(14, 1.5, 15), -- 2: bench room floor
			SHOP + Vector3.new(-6, 5.8, -44), -- 3: storage shelf
			SHOP + Vector3.new(8, 1.5, -40), -- 4: storage floor corner
			SHOP + Vector3.new(-9, 1.5, 40), -- 5: ledger room corner
			SHOP + Vector3.new(10, 6, 44), -- 6: ledger room high shelf level
			SHOP + Vector3.new(47, 9, 9), -- 7: banish room, far corner (moved for B13 — was too close to the deposit prompt)
			SHOP + Vector3.new(34, 7, -8), -- 8: banish room high
			SHOP + Vector3.new(2, 7, -30), -- 9: storage alcove, second spot (moved for A3 — was in the locked corridor)
			SHOP + Vector3.new(2, 8, 30), -- 10: ledger room, second spot (moved for A3 — was in the locked corridor)
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
```

All 10 positions are re-verified to sit well inside their room's interior clearance (≥1.5 studs from any wall/ceiling/floor) and clear of props.

- **Config/Remote/Test notes:** none — `GlyphService.startShift` just does `Draw.sample(rng, ctx.manifest.glyphSpawns, n)`, no dependency on marker names/order/position.

### B1 — Several SurfaceGui text boards face away from the room they're meant to be read in

**Files:** `src/server/Services/MapBuilder.luau` — `Lobby` segment (~line 162-230) and `WorkshopDoor` segment (~line 260-285); **also `src/server/Services/LobbyService.luau`** (~line 65-112) for the `LeaderboardBoard`'s SurfaceGui — `MapBuilder.luau` only places/rotates the `LeaderboardBoard` part itself, but its actual `SurfaceGui.Face` is set later by `LobbyService.refreshLeaderboard()`.

**Current behavior / root cause:** Roblox's `Enum.NormalId` mapping to a part's **local** axes is fixed: `Front = -Z`, `Back = +Z`, `Right = +X`, `Left = -X`. Every affected part is mounted with `Face = Enum.NormalId.Front`, but its position and/or rotation puts the readable face on the wrong side of the room. Derived for each:

| Part | Position | Rotation | Local `Front` (-Z) maps to (world) | Room interior is toward | Verdict |
|---|---|---|---|---|---|
| `Chalkboard` | `LOBBY + (0, 7, -21.4)` | identity | world **-Z** | **+Z** | faces away — broken |
| `ReadyPadSign` | `LOBBY + (12, 6.5, -7)` | identity | world **-Z** | **+Z** | faces away — broken |
| `LeaderboardBoard` | `LOBBY + (-21.4, 7, 0)` | `CFrame.Angles(0, rad(90), 0)` | local **-Z → world -X** | **+X** | faces away — broken |
| `WorkshopDoor`'s `Sign` | `(SHOP.X-23.8, 9, 0)` | `CFrame.Angles(0, rad(-90), 0)` | local **-Z → world +X** | **-X** | faces into the workshop, away from approaching lobby-side players — broken |

**Fix:** All four have the same minimal, individually-verified fix: flip `Enum.NormalId.Front` → `Enum.NormalId.Back` at each call site.

**Fix — `Lobby` segment, full corrected block** (`ReadyPadSign` and `Chalkboard` Face changed; `LeaderboardBoard` part itself is unchanged here — its fix is in `LobbyService.luau` below):

```lua
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
		surfaceText(padLabel, Enum.NormalId.Back, {
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
		surfaceText(chalk, Enum.NormalId.Back, {
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
```

**Fix — `WorkshopDoor` segment, full corrected block** (`Sign` Face changed):

```lua
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
		surfaceText(sign, Enum.NormalId.Back, { { text = "", size = 30 } })
		manifest.workshopDoor = doorModel
		manifest.workshopDoorSign = sign
	end)
```

**Fix — `LobbyService.luau`, full corrected `refreshLeaderboard` function** (`Face` changed for the `LeaderboardBoard`'s `BoardGui`):

```lua
local function refreshLeaderboard()
	local board = ctx.manifest.leaderboardBoard
	if not board then
		return
	end
	local gui = board:FindFirstChild("BoardGui")
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Name = "BoardGui"
		gui.Face = Enum.NormalId.Back
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.Parent = board
		local layout = Instance.new("UIListLayout")
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Top
		layout.Padding = UDim.new(0, 4)
		layout.Parent = gui
	end
	local sg = gui :: SurfaceGui
	for _, child in sg:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local rows: { { name: string, best: number } } = {}
	for _, player in Players:GetPlayers() do
		local stats = ctx.services.DataService.getStats(player)
		table.insert(rows, { name = player.DisplayName, best = stats.bestShift })
	end
	table.sort(rows, function(a, b)
		return a.best > b.best
	end)
	local function addRow(text: string, size: number, color: Color3)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(0.9, 0, 0, size + 6)
		label.Font = Enum.Font.Garamond
		label.TextSize = size
		label.TextColor3 = color
		label.Text = text
		label.Parent = sg
	end
	addRow("NIGHT SHIFT RECORDS", 40, Color3.fromRGB(226, 216, 196))
	for i = 1, math.min(#rows, 8) do
		addRow(("%d.  %s — Shift %d"):format(i, rows[i].name, rows[i].best), 28, Color3.fromRGB(190, 170, 210))
	end
end
```

- **Config/Remote/Test notes:** none. Worth flagging to whoever owns the redesign: bake a "face the room interior" helper into the new `room()`-equivalent so this class of bug can't recur per-part.
- **Follow-up spotted in the reference screenshots (2026-08-15, not part of this fix):** Animal
  Hospital uses TWO separate leaderboard boards ("Patients Treated" / our `dollsCleared`, and
  "Highest Shift" / our `bestShift`) rather than one combined board. This B1 fix only corrects the
  existing single board's facing direction — splitting it into two boards is a small follow-up for
  whoever implements the map redesign (`PACKET_1_MAP_DESIGN.md` §5 addendum), not required here.

### B13 — GlyphSpawn7 overlaps the Banish Box's deposit prompt

**Files:** `src/server/Services/MapBuilder.luau` — `GlyphSpawns` segment (same array already rewritten under **A3** above).

**Current behavior:** `GlyphSpawn7` sits at `SHOP + Vector3.new(46, 1.5, 6)` = `(286, 1.5, 6)`. The Banish Box's deposit `ProximityPrompt` is on the `Base` part at `(280, 2.2, 0)`. Measured distance: `√(6² + 0.7² + 6²) ≈ 8.5 studs`.

**Root cause:** Two `ProximityPrompt`s within roughly-overlapping activation radii. The Banish deposit prompt hardcodes `MaxActivationDistance = 8` via the `prompt()` helper (note: this does **not** go through `Config.Care.PromptDistance` despite `docs/INTERFACES.md`'s stated rule that every prompt should — they happen to be numerically equal today, but it's a latent drift risk, flagged not fixed here). The glyph token's prompt uses `MaxActivationDistance = Config.Glyphs.CollectDistance = 10`. At `~8.5` studs apart, both prompts' ranges reach the same ground.

**Fix:** Relocate `GlyphSpawn7` to `SHOP + Vector3.new(47, 9, 9)` = `(287, 9, 9)` — now `~13.3 studs` from the deposit prompt. This position change is **already included** in the full `GlyphSpawns` segment replacement given under A3 above (apply it once, not twice).

**Side note (not in scope, flagging only):** `GlyphSpawn8` is `~11.1` studs from the same deposit prompt — under the 12-stud target but close. The playtest only confirmed the collision on #7; worth a quick manual check next playtest pass.

- **Config notes:** consider (separately) making `MapBuilder.luau`'s `prompt()` helper take `MaxActivationDistance = Config.Care.PromptDistance` explicitly instead of the hardcoded `8`. Not applied here since it touches the Ribbon spool and Ledger prompts too.
- **Remote/Test notes:** none.

---

## P2 — Banish flow & shift-state bugs, including one game-breaking soft-lock

Scope: `A4` (game-breaking), `B2`, `B3`, `B4`, `B7`, `B11`. **See the merge-order note at the top of this
document before applying anything below** — this section's `transition()`/`onBanishResolved()` code
must be merged with P3's, not applied as an independent full-file paste.

**Note on overlapping edits within this section:** `A4`, `B4`, `B7`, and `B11` all touch the same three
functions in `src/server/Services/ShiftManager.luau` — `transition()`, `onBanishResolved()`, and
`currentObjective()`. The full, final, merged versions of `transition()` and `onBanishResolved()` are
given once, under A4, and the full, final version of `currentObjective()` is given once, under B11. The
B4 and B7 sections explain their slice of that same A4 code with a focused before/after so each section
still stands alone for review, but the code to actually paste lives in A4 (and B11 for the objective
string).

### A4 — ribbon-less correct banish consumes the traitor (soft-lock)

**File(s):** `src/server/Services/ShiftManager.luau` (primary), `src/server/Services/DollService.luau` (new function), `src/client/Controllers/RecapUI.luau` (reveal-line wording).

**Current behavior:** `ShiftManager.onBanishResolved(dollId)` computes `correct = isMarked and slotsMatch and hasRibbon`, then **unconditionally** calls `DollService.consume(dollId)` before even checking `correct`. Every non-correct outcome — including banishing the actual marked doll without its ribbon tied — gets identical treatment: strike, Presence surge, and permanent destruction of that doll.

**Root cause:** The code never distinguishes *which* part of `correct` failed. `isMarked == true` but `hasRibbon == false` is fundamentally different from `isMarked == false` — the first means "you found the traitor, you just skipped a step," the second means "you accused an innocent." Both currently destroy the doll, and since the marked doll is the *only* doll that can ever resolve the shift as a win, this makes the shift permanently unwinnable.

**Fix:** Split the non-correct path on `isMarked`. Only a genuinely wrong doll gets `DollService.consume()`. The marked-but-incomplete doll gets a new `DollService.returnToBench()` instead — visually and functionally restored to bench — plus a distinct `BanishResult`/`Toast` message. This same pass also captures the marked doll's display name **at mark-time** (in `ShiftIntro`) into ShiftManager's own state, so recap's `traitorName` never depends on the doll's server record still existing later (also fixes B7's placeholder).

Add two new module-level locals near the existing `spirit`/`shiftParams`/`runStats` declarations:

```lua
local spirit: any = nil
local shiftParams: any = nil
local markedDollName: string? = nil -- A4/B7: mark-time name snapshot; recap must never depend on
                                     -- the doll's server record still existing at RunEnd
local lastBanishOutcome: string? = nil -- B11: nil | "wrongDoll" | "incomplete" — drives the
                                        -- post-wrong-banish objective string
local runStats = { dollsCleared = 0, perfect = 0, strikesThisShift = 0 }
```

Full corrected `transition` function (**merge with P3's version per the note at the top of this doc —
this listing carries B4's reset-order fix and B7's traitorName/shiftReached fix; it does NOT yet carry
P3's `runEndReason` branching, which must be layered on top**):

```lua
transition = function(newState: string)
	stateGen += 1
	local gen = stateGen
	state = newState

	if newState == "LobbyIdle" then
		-- B4 fix: reset run-scoped state (esp. `strikes`) BEFORE broadcastState() runs below, so
		-- the StateChanged payload that announces LobbyIdle already carries strikes = 0 instead of
		-- the just-ended run's strike count.
		shiftNumber = 1
		strikes = 0
		spirit = nil
		markedDollName = nil -- A4/B7: clear the mark-time snapshot between runs
		lastBanishOutcome = nil -- B11: clear the post-banish objective override between runs
		runStats = { dollsCleared = 0, perfect = 0, strikesThisShift = 0 }
		participants = {}
		setDoorLocked(false)
		cleanupRun()
	end

	broadcastState()
	armWatchdog(newState, gen)

	if newState == "ShiftIntro" then
		pruneParticipants()
		if #participants == 0 then
			transition("LobbyIdle")
			return
		end
		setDoorLocked(true)
		Util.safeCall("spawnToggle", function()
			ctx.services.LobbyService.setShiftSpawnActive(true)
		end)
		runStats.strikesThisShift = 0
		lastBanishOutcome = nil -- B11: fresh shift, fresh objective wording
		spirit = Draw.one(ctx.rng, Spirits.list)
		shiftParams = Escalation.forShift(escalationCfg, shiftNumber, #participants)
		local names = Draw.sample(ctx.rng, DollNames, shiftParams.dollCount)
		local markedIndex = ctx.rng:NextInteger(1, shiftParams.dollCount)
		local dollInfos = ctx.services.DollService.spawnShift(shiftParams, names, markedIndex, ctx.rng)
		-- A4/B7 fix: snapshot the marked doll's display name NOW, at mark-time, into ShiftManager's
		-- own state. Recap must never depend on the doll's DollService record still existing later.
		markedDollName = (dollInfos[markedIndex] and dollInfos[markedIndex].name) or "…someone"
		ctx.services.GlyphService.startShift(spirit.code, ctx.rng)
		teleportTo(ctx.manifest.workshopSpawn, participants)
		Remotes.get(Remotes.Names.ShiftData):FireAllClients({
			shift = shiftNumber,
			dolls = dollInfos,
			glyphTotal = #spirit.code,
		})
		task.delay(Config.Shift.IntroSeconds, function()
			if state == "ShiftIntro" and stateGen == gen then
				transition("ShiftActive")
			end
		end)
	elseif newState == "ShiftActive" then
		ctx.services.PresenceService.startShift(shiftParams.presenceRateMultiplier)
		ctx.services.TellService.startShift(shiftParams, ctx.rng)
		ctx.services.HauntService.startShift(ctx.rng)
	elseif newState == "ShiftResult" then
		stopShiftSystems()
		task.delay(Config.Shift.ResultSeconds, function()
			if state == "ShiftResult" and stateGen == gen then
				transition("ShiftIntro")
			end
		end)
	elseif newState == "RunEnd" then
		stopShiftSystems()
		-- THE scare
		Remotes.get(Remotes.Names.HauntFired):FireAllClients("DollmakerReveal", {})
		for _, lamp in ctx.manifest.lamps do
			local light = lamp:FindFirstChildOfClass("PointLight")
			if light then
				light.Enabled = false
			end
		end
		-- B7/A4 fix: use the name captured at mark-time (see ShiftIntro above), never a live
		-- DollService lookup — the marked doll's record may already be gone by RunEnd.
		local traitorName = markedDollName or "…someone"
		task.delay(4, function()
			if stateGen ~= gen then
				return
			end
			for _, lamp in ctx.manifest.lamps do
				local light = lamp:FindFirstChildOfClass("PointLight")
				if light then
					light.Enabled = true
				end
			end
			pruneParticipants()
			for _, player in participants do
				local stats = ctx.services.DataService.getStats(player)
				-- B7 fix: shiftReached = "the shift number the player was on when the run ended"
				-- (matches the HUD's live `SHIFT N` banner), NOT "shifts fully survived".
				local isNewBest = shiftNumber > stats.bestShift
				ctx.services.DataService.recordRun(player, {
					shiftReached = shiftNumber,
					dollsCleared = runStats.dollsCleared,
					perfect = runStats.perfect,
				})
				Remotes.get(Remotes.Names.Recap):FireClient(player, {
					shiftReached = shiftNumber,
					dollsCleared = runStats.dollsCleared,
					perfect = runStats.perfect > 0 and strikes == 0,
					traitorName = traitorName,
					bestShift = math.max(stats.bestShift, shiftNumber),
					isNewBest = isNewBest,
				})
			end
			cleanupRun()
			teleportTo(ctx.manifest.lobbySpawn, participants)
			transition("LobbyIdle")
		end)
	end
end
```

Full corrected `onBanishResolved` function (**this one has no P3 conflict — apply as-is**):

```lua
function ShiftManager.onBanishResolved(dollId: string)
	if state ~= "ShiftActive" then
		return
	end
	local DollService = ctx.services.DollService
	local GlyphService = ctx.services.GlyphService
	local dollName = DollService.getDisplayName(dollId)
	local isMarked = DollService.isMarked(dollId)
	local slotsMatch = spirit ~= nil and GlyphMatch.matches(spirit.code, GlyphService.getSlots())
	local hasRibbon = DollService.hasRibbon(dollId)
	local correct = isMarked and slotsMatch and hasRibbon

	if correct then
		DollService.consume(dollId)
		Remotes.get(Remotes.Names.BanishResult):FireAllClients({
			correct = true,
			dollId = dollId,
			dollName = dollName,
			spiritName = spirit.name,
			strikes = strikes,
		})
		runStats.dollsCleared += shiftParams.dollCount
		if runStats.strikesThisShift == 0 then
			runStats.perfect += 1
		end
		shiftNumber += 1
		transition("ShiftResult")
		return
	end

	-- A4 fix: every non-correct outcome used to be treated identically (strike + surge + consume),
	-- which meant banishing the CORRECT doll without its ribbon tied destroyed the only doll that
	-- could ever win the shift, soft-locking the run. Now: only a genuinely WRONG doll gets consumed.
	strikes += 1
	runStats.strikesThisShift += 1
	ctx.services.PresenceService.surge(Config.Presence.WrongBanishSurge)

	if isMarked then
		lastBanishOutcome = "incomplete"
		DollService.returnToBench(dollId)
		Remotes.get(Remotes.Names.BanishResult):FireAllClients({
			correct = false,
			incomplete = true,
			dollId = dollId,
			dollName = dollName,
			strikes = strikes,
		})
		Remotes.get(Remotes.Names.Toast):FireAllClients("The box would not close… something is missing.", 4)
	else
		lastBanishOutcome = "wrongDoll"
		DollService.consume(dollId)
		Remotes.get(Remotes.Names.BanishResult):FireAllClients({
			correct = false,
			dollId = dollId,
			dollName = dollName,
			strikes = strikes,
		})
	end

	if strikes >= Config.Shift.StrikeLimit then
		transition("RunEnd")
	else
		ctx.services.BanishService.setUnlocked(true)
		broadcastState()
	end
end
```

*(Note: `PACKET_1_LOBBY_SYSTEMS.md`'s Economy track inserts a coin-bonus payout into this same
`correct` branch, before `shiftNumber += 1`, and its Social track inserts an `onShiftCleared` callback
loop right after that. Its strike-limit check is also extended with a class-buff bonus. See that
packet's integration notes for exact insertion order.)*

New `DollService` function — insert immediately after `DollService.drop()` (right before `getCarried`):

```lua
-- A4: companion to consume() — undoes a deposit-into-the-box WITHOUT destroying the doll, for the
-- "right doll, missing requirement" banish outcome. Mirrors drop()'s restore logic but also moves
-- the model back to its bench slot, since deposit() PivotTo'd it into the Banish Box.
function DollService.returnToBench(dollId: string): boolean
	local rec = dolls[dollId]
	if not rec or rec.consumed then
		return false
	end
	rec.model:PivotTo(rec.resting)
	for _, d in rec.model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = if d.Name == "Root" then 1 else 0
		elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
			(d :: any).Enabled = true
		end
	end
	refreshPrompt(rec)
	return true
end
```

`RecapUI.playReveal` needs to know about the new `incomplete` flag so it doesn't tell players the traitor doll "WAS INNOCENT" (false, and undermines the point of not consuming it). Full corrected function (RecapUI.luau, lines 31–60):

```lua
local function playReveal(data: any)
	local g = gui
	if not g then
		return
	end
	local flash = black(0)
	SoundKit.play(if data.correct then "StingReveal" else "StingWrong")
	local text
	if data.correct then
		text = ("%s WAS %s"):format(string.upper(data.dollName or "?"), string.upper(data.spiritName or "THE SPIRIT"))
	elseif data.incomplete then
		-- A4: this WAS the marked doll — never tell players it was "innocent".
		text = ("THE BOX WOULD NOT CLOSE ON %s… SOMETHING IS MISSING."):format(string.upper(data.dollName or "?"))
	else
		text = ("%s WAS INNOCENT."):format(string.upper(data.dollName or "?"))
	end
	local line = Theme.label(g, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.45, 0),
		Size = UDim2.new(0.9, 0, 0, 120),
		Font = Theme.TitleFont,
		TextSize = 12,
		TextColor3 = if data.correct then Theme.Gold elseif data.incomplete then Theme.Accent else Theme.Sickly,
		TextStrokeTransparency = 0.3,
		ZIndex = 3,
		Text = text,
	})
	TweenService:Create(line, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextSize = 52 }):Play()
	task.delay(3, function()
		TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(line, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.delay(0.9, function()
			flash:Destroy()
			line:Destroy()
		end)
	end)
end
```

- **Config:** no new Config key needed.
- **Remotes:** no new remote name. Extends two existing payloads (no `Remotes.luau` `Names` table change needed) — flag for doc updates: `BanishResult` gains optional `incomplete: boolean?`; `docs/INTERFACES.md`'s DollService API list should gain a one-line entry for `returnToBench(dollId): boolean`.
- **Tests:** no `tests/logic.spec.luau` changes needed.

### B2 — HUD objective text stuck on "Find the glyphs" after glyphs are matched

**File(s):** `src/server/Services/GlyphService.luau`, `src/server/Services/ShiftManager.luau` (new public method).

**Current behavior:** `GlyphService.collect()` and the `SlotGlyph` handler inside `GlyphService.init()` update glyph/slot state and broadcast `GlyphFound` to clients, which the Ledger UI reads directly. Neither path notifies `ShiftManager`, so the HUD's `objective` field goes stale.

**Fix:** Give `ShiftManager` a small public method that just recomputes-and-rebroadcasts (reusing the existing `StateChanged` remote), and call it from both GlyphService entry points.

Add to `ShiftManager.luau`, next to the other public API functions:

```lua
-- B2: lightweight objective-only refresh for services whose state changes affect the objective
-- string but don't themselves warrant a full state transition (glyph collect / ledger slot).
function ShiftManager.refreshObjective()
	if state == "ShiftActive" then
		broadcastState()
	end
end
```

Full corrected `GlyphService.collect` (lines 213–237):

```lua
function GlyphService.collect(player: Player, tokenId: string)
	local token = tokens[tokenId]
	if not token then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (hrp and hrp:IsA("BasePart")) then
		return
	end
	if (hrp.Position - token.part.Position).Magnitude > Config.Glyphs.CollectDistance + 4 then
		return
	end
	tokens[tokenId] = nil
	Util.safeCall("destroyToken", function()
		token.part:Destroy()
		token.targetValue:Destroy()
	end)
	if not table.find(found, token.glyphId) then
		table.insert(found, token.glyphId)
	end
	local glyphName = Glyphs.byId[token.glyphId] and Glyphs.byId[token.glyphId].name or token.glyphId
	broadcast(token.glyphId, player.DisplayName)
	Remotes.get(Remotes.Names.Toast):FireAllClients(("%s found a glyph: %s"):format(player.DisplayName, glyphName), 4)
	-- B2 fix: a glyph collect can flip the HUD objective (care -> glyphs -> ledger), but nothing
	-- told ShiftManager to recompute + rebroadcast it.
	Util.safeCall("shiftObjectiveRefresh", function()
		ctx.services.ShiftManager.refreshObjective()
	end)
end
```

Full corrected `SlotGlyph` handler inside `GlyphService.init` (lines 129–143):

```lua
	Remotes.get(Remotes.Names.SlotGlyph).OnServerEvent:Connect(function(_player: Player, slotIndex: any, glyphId: any)
		if typeof(slotIndex) ~= "number" or slotIndex < 1 or slotIndex > 3 or slotIndex % 1 ~= 0 then
			return
		end
		if glyphId == nil then
			slots[slotIndex] = nil
			broadcast(nil, nil)
			Util.safeCall("shiftObjectiveRefresh", function()
				ctx.services.ShiftManager.refreshObjective()
			end)
			return
		end
		if typeof(glyphId) ~= "string" or not table.find(found, glyphId) then
			return
		end
		slots[slotIndex] = glyphId
		broadcast(nil, nil)
		-- B2 fix: slotting into (or clearing from) the ledger can complete/break the spirit match.
		Util.safeCall("shiftObjectiveRefresh", function()
			ctx.services.ShiftManager.refreshObjective()
		end)
	end)
```

- **Config:** no new Config key.
- **Remotes:** no new remote — reuses `StateChanged`. Flag for `docs/INTERFACES.md`: add `refreshObjective()` to the ShiftManager public-API list.
- **Tests:** none — pure event-wiring, no pure-logic module touched.

### B3 — banish countdown/modal survives past run-end

**File(s):** `src/server/Services/BanishService.luau`, `src/client/Controllers/BanishConfirmUI.luau`.

**Current behavior:** `BanishService.reset()` clears `pending` and bumps `generation`, but never broadcasts `{cancelled = true}`. Confirmed live: `BanishPrompt` countdown ticks kept firing after `StateChanged(RunEnd)`, and `BanishConfirmUI`'s modal stayed visible into the next lobby session.

**Root cause:** Two gaps. (1) `reset()` never tells the client the modal should close, unlike `cancel()`/`resolve()` which both call `broadcastPrompt(nil, nil, {cancelled = true})`. (2) `BanishConfirmUI.luau`'s modal only ever closes on an explicit `{cancelled = true}` payload or a `BanishResult` event — no fallback tied to the more fundamental `StateChanged` signal.

**Fix, two parts.**

**(1)** Full corrected `BanishService.reset()`:

```lua
function BanishService.reset()
	pending = nil
	generation += 1
	-- B3 fix: always broadcast cancelled=true, unconditionally — not just from cancel()/resolve().
	broadcastPrompt(nil, nil, { cancelled = true })
	BanishService.setUnlocked(false)
end
```

**(2)** Full corrected `BanishConfirmUI.init()` — add a `StateChanged` listener:

```lua
function BanishConfirmUI.init()
	build()

	Remotes.get(Remotes.Names.BanishPrompt).OnClientEvent:Connect(function(dollId: any, dollName: any, extra: any)
		local g = gui
		if not g then
			return
		end
		if typeof(extra) == "table" and extra.cancelled then
			g.Enabled = false
			confirmed = false
			return
		end
		if typeof(dollId) == "string" and typeof(dollName) == "string" then
			if not g.Enabled then
				confirmed = false
				local confirmButton = modal and modal:FindFirstChildOfClass("TextButton")
				if confirmButton then
					confirmButton.Text = "BANISH"
				end
			end
			g.Enabled = true
			if titleLabel then
				titleLabel.Text = ("Banish %s?"):format(dollName)
			end
		end
		if typeof(extra) == "table" and typeof(extra.countdown) == "number" and countdownLabel then
			countdownLabel.Text = ("Banishing in %d… (refuse to stop it)"):format(extra.countdown)
		end
	end)

	Remotes.get(Remotes.Names.BanishResult).OnClientEvent:Connect(function()
		local g = gui
		if g then
			g.Enabled = false
		end
		confirmed = false
	end)

	-- B3 fix: belt-and-suspenders close. State transitions are the more fundamental signal.
	Remotes.get(Remotes.Names.StateChanged).OnClientEvent:Connect(function(state: any)
		if state == "RunEnd" or state == "LobbyIdle" then
			local g = gui
			if g then
				g.Enabled = false
			end
			confirmed = false
		end
	end)
end
```

- **Config/Remotes:** none new — both fixes reuse existing remotes already imported.
- **Tests:** none — remote/event wiring, not pure logic.

### B4 — strike pips not reset on return to lobby

**File(s):** `src/server/Services/ShiftManager.luau` (already merged into A4's `transition()` above), `src/client/Controllers/Hud.luau`.

**Current behavior:** `transition("LobbyIdle")` used to call `broadcastState()` *before* the code that resets `strikes = 0` ran. Confirmed live: after a run ended with 2 strikes, the lobby HUD still showed 2 lit/red pips.

**Fix:** Already folded into A4's merged `transition()` above (reset block moved above `broadcastState()`). `Config.Shift.Watchdog` has no `LobbyIdle` entry, so `armWatchdog` is a no-op for this state either way.

Per the bug's own recommendation, also add the defensive client-side fix — full corrected `Hud.luau` `StateChanged` handler (lines 167–187):

```lua
	Remotes.get(Remotes.Names.StateChanged).OnClientEvent:Connect(function(state: any, data: any)
		if typeof(data) ~= "table" then
			return
		end
		if shiftLabel then
			shiftLabel.Text = if state == "LobbyIdle" then "THE DOLLMAKER'S" else ("SHIFT %d"):format(data.shift or 1)
		end
		if objectiveLabel then
			objectiveLabel.Text = data.objective or ""
		end
		-- B4 fix: defensively force strike pips to zero on LobbyIdle regardless of whatever
		-- `strikes` value is in this particular payload.
		local displayStrikes = if state == "LobbyIdle" then 0 else (data.strikes or 0)
		for i, pip in strikePips do
			pip.BackgroundColor3 = if i <= displayStrikes then Theme.Danger else Theme.BgSoft
		end
		if dollList and (state == "LobbyIdle" or state == "RunEnd") then
			dollList.Visible = false
			for _, entry in dollRows do
				entry.row:Destroy()
			end
			dollRows = {}
		end
	end)
```

- **Config/Remotes/Tests:** none new.

### B7 — recap shows wrong shift number and placeholder traitor name

**File(s):** `src/server/Services/ShiftManager.luau` — already folded into A4's merged `transition()` above.

**Current behavior:** `shiftReached` used to be `shiftNumber - 1` in both `DataService.recordRun` and the `Recap` payload, so a player who died mid-shift-2 (HUD showing "SHIFT 2") got a recap saying "SHIFT 1". Separately, `traitorName` was a live `DollService.getDisplayName` lookup, which broke if that doll's record had already been destroyed (mainly via the A4 bug).

**Fix:** Semantic decision, stated plainly: **`shiftReached` = "the shift number the player was on when the run ended"** (`shiftNumber` itself, matches the HUD's live banner), not "shifts fully survived." Already folded into A4's merged `transition()`. `traitorName` now reads the mark-time snapshot (`markedDollName`), also already folded in.

- **Config/Remotes/Tests:** none — `Recap`'s payload shape is unchanged, just computed differently.

### B8 — consumed doll's checklist row stays fully-ticked

**File(s):** `src/server/Services/DollService.luau`, `src/client/Controllers/Hud.luau`.

**Current behavior:** `DollService.consume(dollId)` marks the record consumed, disables its prompt, and tweens the model down before destroying it — but never notifies clients. `Hud.luau`'s checklist panel has no way to learn the doll is gone.

**Fix:** Reuse the existing `DollUpdate` remote/payload shape with a new optional `removed` flag.

Full corrected `DollService.consume`:

```lua
function DollService.consume(dollId: string)
	local rec = dolls[dollId]
	if not rec or rec.consumed then
		return
	end
	rec.consumed = true
	rec.prompt.Enabled = false
	-- B8 fix: tell clients this doll is gone so Hud.luau's checklist panel stops showing it as a
	-- fully-cared-for, still-in-play doll.
	fire("DollUpdate", dollId, { removed = true })
	-- sink + fade
	local parts = {}
	for _, d in rec.model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	for _, p in parts do
		TweenService:Create(p, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Transparency = 1,
			CFrame = p.CFrame * CFrame.new(0, -2, 0),
		}):Play()
	end
	task.delay(2, function()
		Util.safeCall("consumeDestroy", function()
			rec.model:Destroy()
		end)
	end)
end
```

Full corrected `DollUpdate` handler in `Hud.luau`:

```lua
	Remotes.get(Remotes.Names.DollUpdate).OnClientEvent:Connect(function(dollId: any, update: any)
		local entry = dollRows[dollId]
		if not entry or typeof(update) ~= "table" then
			return
		end
		if update.removed == true then
			-- B8 fix: a consumed doll must stop reading as a fully-cared-for, still-in-play doll.
			entry.nameLabel.Text = ("%s — gone"):format(entry.nameLabel.Text)
			entry.nameLabel.TextColor3 = Theme.Muted
			for _, tick in entry.ticks do
				tick.BackgroundColor3 = Theme.BgSoft
			end
			return
		end
		if typeof(update.name) == "string" then
			entry.nameLabel.Text = update.name
		end
		if typeof(update.careDone) == "table" then
			local doneSet: { [string]: boolean } = {}
			for _, stepId in update.careDone do
				doneSet[stepId] = true
			end
			for i, step in CareSteps.list do
				if doneSet[step.id] and entry.ticks[i] then
					entry.ticks[i].BackgroundColor3 = Theme.Gold
				end
			end
		end
		if update.done == true then
			entry.nameLabel.TextColor3 = Theme.Gold
		end
	end)
```

- **Config:** none.
- **Remotes:** no new remote name — extends `DollUpdate` with an optional `removed: boolean?`. Flag for doc update.
- **Tests:** none.

### B11 — confusing objective text after a wrong banish

**File(s):** `src/server/Services/ShiftManager.luau`.

**Current behavior:** `currentObjective()` has exactly one hard-coded string for the "ledger matched, go banish" phase: `"Bring the WRONG doll to the Banish Box."` — shown both *before* the first attempt (intentionally, spookily misleading — correct, must stay) and, unchanged, immediately *after* a wrong banish.

**Root cause:** `currentObjective()` is a pure function of live care/glyph/ledger state; it has no memory of "did a wrong banish just happen this shift."

**Fix:** Track the outcome of the most recent wrong banish this shift (`lastBanishOutcome`, introduced under A4) and branch the final line of `currentObjective()` on it.

Full corrected `currentObjective()`:

```lua
local function currentObjective(): string
	if state == "LobbyIdle" then
		return "Stand on the glowing pad to start the night shift."
	elseif state == "ShiftIntro" then
		return "The dolls are arriving…"
	elseif state ~= "ShiftActive" then
		return ""
	end
	local DollService = ctx.services.DollService
	local GlyphService = ctx.services.GlyphService
	local remaining = 0
	for _, id in DollService.getDollIds() do
		if DollService.nextStepFor(id) ~= nil then
			remaining += 1
		end
	end
	if remaining > 0 then
		return ("Care for the dolls — %d still need%s work."):format(remaining, if remaining == 1 then "s" else "")
	end
	local found = #GlyphService.getFound()
	local total = if spirit then #spirit.code else 3
	if found < total then
		return ("Find the glyphs — %d of %d found."):format(found, total)
	end
	local slots = GlyphService.getSlots()
	if not (spirit and GlyphMatch.matches(spirit.code, slots)) then
		return "Match the spirit in the ledger."
	end
	-- B11 fix: the post-wrong-banish message must NOT tell players to do the exact thing they were
	-- just penalized for. `lastBanishOutcome` is set in onBanishResolved (see A4) and cleared at the
	-- start of each shift, so these branches only fire after an actual wrong attempt THIS shift. The
	-- original pre-attempt copy below is intentionally a little misleading by design and is untouched.
	if lastBanishOutcome == "wrongDoll" then
		return "That wasn't it. Find the REAL one."
	elseif lastBanishOutcome == "incomplete" then
		return "You had the right one — something's still missing. Try again."
	end
	return "Bring the WRONG doll to the Banish Box."
end
```

- **Config/Remotes/Tests:** none.

### Cross-cutting doc updates for cloud Claude to make in `docs/INTERFACES.md`

| Location | Change |
|---|---|
| ~line 199–203 (ShiftManager `onBanishResolved` prose) | Document the `isMarked`-but-incomplete branch (A4) and that `BanishResult` gains `incomplete: boolean?`. |
| ~line 217–218 (ShiftManager public API list) | Add `refreshObjective()` (B2). |
| ~line 66–68 (DollService API list, near `consume()`) | Add `returnToBench(dollId): boolean` (A4) and note `consume()` now also fires `DollUpdate {removed = true}` (B8). |
| ~line 312 (`BanishResult` payload quick-reference) | Add `incomplete: boolean?`. |
| ~line 308 (`DollUpdate` payload quick-reference) | Add `removed: boolean?`. |
| `src/shared/Remotes.luau` lines 16 and 20 (inline payload-shape comments) | Update to mention `removed`/`incomplete` respectively. |

---

## P3 — Presence-meter pacing and watchdog-vs-Presence-max ordering

**See the merge-order note at the top of this document — this section's `transition()`,
`armWatchdog()`, and `ShiftManager.init()` code must be merged with P2's, not applied independently.**

### B9 — Presence spikes far faster than documented late-shift, and the Watchdog can end a run *before* Presence ever maxes (dishonest ending)

**File(s):**
- `src/shared/Logic/PresenceMath.luau` — pure-logic module, root cause of the spike lives here
- `src/shared/Config.luau` — `Presence` table (retune) and `Shift.Watchdog` table (comment only, value kept)
- `src/server/Services/ShiftManager.luau` — watchdog-vs-Presence-maxed `RunEnd` cause tracking
- `src/client/Controllers/HauntClient.luau` — new calm "timeout" beat, distinct from the possession scare
- `src/client/Controllers/RecapUI.luau` — recap card must not always say "the Presence took you"
- `tests/logic.spec.luau` — new coverage for the fixed surge math
- No change needed in `src/server/Services/PresenceService.luau` — it builds `mathCfg` straight from `Config.Presence` at require-time, so the Config retune below takes effect automatically.

### Current behavior
Presence is supposed to be a slow ~16-minute "quiet" clock that escalation/mistakes speed up. In play, two wrong banishes plus the post-all-care 2× acceleration pushed Presence from 40→100 in under a minute. Separately, `Config.Shift.Watchdog.ShiftActive` (900s) fired on a careful, mistake-free solo run while Presence was only at 87/100, and that watchdog path reuses the exact same `RunEnd` → `"DollmakerReveal"` possession-scare + recap as a genuine Presence-maxed ending, so the game told the player "the Presence took you" when what actually happened was "you ran out of watchdog time."

### Root cause
Two independent defects:

1. **A real math bug in `PresenceMath.step`**, not just bad tuning. The spend-per-tick was capped at `RushDecayPerSecond * dt * 4`, while the surge *pool* was only drained by `RushDecayPerSecond * dt` — two different rates for what should be the same quantity. A nominal surge of `S` points ends up injecting **≈4×S** points into Presence, not `S`. A "flat +15" wrong-banish surge is actually worth ~60 points over its lifetime.
2. **A design/ordering bug in `ShiftManager`.** `RunEnd` is reached from two different causes (`PresenceService.onMaxed` and the `ShiftActive` watchdog) but the state machine never records *which one* fired. Compounding this: even with *zero* mistakes, solo's baseline time-to-max (`100 / (0.10 * 0.75)` ≈ 1333s ≈ 22m13s) already exceeds the 900s watchdog by a wide margin.

### Worked math

**Baseline "quiet" claim (Config's own comment) — confirmed correct, not the bug:**
`Max / BaseFillPerSecond = 100 / 0.10 = 1000s = 16m40s` — matches the "~16 quiet minutes" comment.

**Reproducing "40→100 in well under a minute" with current (buggy) numbers**, illustrative (shift 15, 3 players, all care done, 2 wrong banishes just landed):
- `presenceRateMultiplier` = `min(1 + 0.08*14, 3) = 2.12`
- `fill = 0.10 * 2.12 * LastDollAccelMultiplier(2.0) = 0.424 pts/s`
- surge pool after 2 wrong banishes = `2 * WrongBanishSurge(15) = 30`
- buggy `surgeSpend` cap = `RushDecayPerSecond(0.25) * dt * 4` → steady **1.0 pt/s** for `30/0.25 = 120s`
- combined rate ≈ `0.424 + 1.0 = 1.424 pts/s`
- time to close a 60-point gap: `60 / 1.424 ≈ 42s` — **matches the playtest report almost exactly.**

**Solo watchdog race, no mistakes at all** (proves this isn't about strikes):
- solo baseline fill = `0.10 * 0.75 = 0.075 pts/s`
- time to max from 0: `100 / 0.075 ≈ 1333s ≈ 22m13s`
- `Config.Shift.Watchdog.ShiftActive = 900s` fires **~7+ minutes before** Presence could possibly max, even with flawless play.

**After the fix**, same worst-case (max escalation, all care done, 2 wrong banishes, starting at 40):
- `fill = 0.10 * 3.0 * LastDollAccelMultiplier(1.5) = 0.45 pts/s`
- surge pool = `2 * WrongBanishSurge(10) = 20`, spends at the correct rate `0.25 pts/s` for `80s`
- combined rate while surge lasts: `0.70 pts/s`; in 80s: `+56` → value 96; remaining `4` at `0.45 pts/s` → `+8.9s`
- **total ≈ 89s (~1.5 minutes)** — still a real endgame punishment, but no longer effectively-instant.

### Decision on watchdog vs. Presence-max ordering

**Chosen fix: keep `Config.Shift.Watchdog.ShiftActive = 900` unchanged, and make `RunEnd` self-aware of why it fired.** Raising the watchdog to leave real margin (~25 min+) would stop it doing its R2 job (a hard ceiling rescuing a genuinely stuck shift in a reasonable time). Instead `RunEnd` now carries a `reason` ("presence" | "watchdog") through the scare beat and the recap card.

### Fix 1 — `PresenceMath.step`: correct the surge-accounting bug

Current code (lines 52–62):
```lua
function PresenceMath.step(state: PresenceState, cfg: PresenceConfig, dt: number, rateMultiplier: number)
	local fill = cfg.BaseFillPerSecond * rateMultiplier
	if state.allDollsDone then
		fill *= cfg.LastDollAccelMultiplier
	end
	local surgeSpend = math.min(state.surge, cfg.RushDecayPerSecond * dt * 4)
	state.surge = math.max(0, state.surge - cfg.RushDecayPerSecond * dt)
	state.value = math.min(cfg.Max, state.value + fill * dt + surgeSpend)
end
```

Full corrected file:
```lua
--!strict
-- Pure logic: the Presence meter (no `game` references — unit-tested).
-- Constant fill + rush-surge rubber band + last-doll acceleration + event surges.

export type PresenceState = {
	value: number,
	surge: number, -- decaying extra fill from rushing
	stepTimestamps: { number }, -- recent care-step completion times (for rush detection)
	allDollsDone: boolean,
}

export type PresenceConfig = {
	Max: number,
	BaseFillPerSecond: number,
	LastDollAccelMultiplier: number,
	RushWindowSeconds: number,
	RushStepsInWindow: number,
	RushSurgeAmount: number,
	RushDecayPerSecond: number,
	Tiers: { number },
}

local PresenceMath = {}

function PresenceMath.new(): PresenceState
	return {
		value = 0,
		surge = 0,
		stepTimestamps = {},
		allDollsDone = false,
	}
end

function PresenceMath.onStepCompleted(state: PresenceState, cfg: PresenceConfig, t: number)
	table.insert(state.stepTimestamps, t)
	local cutoff = t - cfg.RushWindowSeconds
	while #state.stepTimestamps > 0 and state.stepTimestamps[1] < cutoff do
		table.remove(state.stepTimestamps, 1)
	end
	if #state.stepTimestamps >= cfg.RushStepsInWindow then
		state.surge += cfg.RushSurgeAmount
		table.clear(state.stepTimestamps)
	end
end

function PresenceMath.addSurge(state: PresenceState, amount: number)
	state.surge += amount
end

-- Advance the meter by dt seconds. rateMultiplier comes from Escalation.
function PresenceMath.step(state: PresenceState, cfg: PresenceConfig, dt: number, rateMultiplier: number)
	local fill = cfg.BaseFillPerSecond * rateMultiplier
	if state.allDollsDone then
		fill *= cfg.LastDollAccelMultiplier
	end
	-- Surge is a bounded "rubber band" pool: spend it into the meter at a fixed rate
	-- (RushDecayPerSecond points/sec) until the pool is empty, so a surge of amount S
	-- always contributes exactly S total points over S / RushDecayPerSecond seconds —
	-- never more. (B9 fix: the old code let the meter receive up to 4x that rate while
	-- only draining the pool at 1x that rate, so a surge silently injected ~4x its
	-- nominal amount into Presence. See tests/logic.spec.luau's "surge integral" checks.)
	local surgeSpend = math.min(state.surge, cfg.RushDecayPerSecond * dt)
	state.surge -= surgeSpend
	state.value = math.min(cfg.Max, state.value + fill * dt + surgeSpend)
end

function PresenceMath.tier(state: PresenceState, cfg: PresenceConfig): number
	local tier = 0
	for i, threshold in cfg.Tiers do
		if state.value >= threshold then
			tier = i
		end
	end
	return tier
end

function PresenceMath.isMaxed(state: PresenceState, cfg: PresenceConfig): boolean
	return state.value >= cfg.Max
end

return PresenceMath
```

(`state.surge = math.max(0, ...)` is no longer needed since `surgeSpend <= state.surge` by construction.)

### Fix 2 — `Config.luau`: retune `Presence` and document why `Watchdog.ShiftActive` stays put

Full corrected blocks:
```lua
	Presence = {
		Max = 100,
		-- ~16.7 quiet minutes to max (100 / 0.10) with no acceleration, no surge, no escalation
		-- multiplier — this is the deliberate "calm" baseline and playtest confirmed it's accurate.
		-- B9: the reported spikes were NOT from this constant; they were a surge-accounting bug in
		-- PresenceMath.step (fixed) plus LastDollAccelMultiplier/WrongBanishSurge being tuned for
		-- the old (over-amplified) surge math. See docs/PLAYTEST_REPORT_2026-08-15.md B9.
		BaseFillPerSecond = 0.10,
		LastDollAccelMultiplier = 1.5, -- (was 2.0) after every doll's care chain is done — still a
			-- real hurry-up once care is finished, without erasing minutes of buffer in one shift
		RushSurge = { -- anti-rush rubber band: surge added when steps complete too fast
			WindowSeconds = 20,
			StepsInWindow = 4,
			SurgeAmount = 6,
			DecayPerSecond = 0.25,
		},
		-- NOTE: StrikeSurge is currently UNREFERENCED by any service — every strike in this game
		-- originates from a wrong banish, and that path only calls
		-- PresenceService.surge(Config.Presence.WrongBanishSurge). Kept in Config (never
		-- remove/rename existing keys) and tuned in step with WrongBanishSurge in case a future
		-- strike source wires it in later.
		StrikeSurge = 10, -- (was 12)
		WrongBanishSurge = 10, -- (was 15) fires once per wrong banish via PresenceService.surge();
			-- PresenceMath.step now spends this pool at exactly RushSurge.DecayPerSecond pts/sec, so
			-- this number IS the total Presence contribution of one wrong banish (was ~4x this
			-- under the old, buggy surge math).
		Tiers = { 25, 55, 85 }, -- tier 0 below first threshold; tiers gate haunts + ambience
			-- (unchanged: these gate ambience/haunt tier, not pacing, and stay sensible under the
			-- corrected math)
	},
```
```lua
		Watchdog = {
			ShiftIntro = 20,
			-- 15 min ceiling on one shift. Deliberately NOT raised to chase Presence's own
			-- worst-case time-to-max: solo's unaccelerated baseline alone is ~22 minutes
			-- (100 / (BaseFillPerSecond * 0.75)), well past any reasonable watchdog ceiling.
			-- B9: instead of racing the watchdog against Presence, ShiftManager now tags RunEnd
			-- with reason="watchdog" vs reason="presence" so a timeout never impersonates a
			-- possession scare. See ShiftManager.luau's armWatchdog/transition.
			ShiftActive = 900,
			BanishStaging = 30,
			ShiftResult = 25,
			RunEnd = 30,
		},
```

- **Config notes:** no new Config keys — only existing values (`LastDollAccelMultiplier`, `StrikeSurge`, `WrongBanishSurge`) change, plus comments. `Config.Shift.Watchdog.ShiftActive` value is unchanged (900) — only its comment changes.

### Fix 3 — `ShiftManager.luau`: tag `RunEnd` with its real cause

**Apply this on top of A4/B4/B7's merged `transition()` from P2 above — see the merge-order note at
the top of this document.**

Add one new piece of state near the existing module-level state block:
```lua
local runEndReason: string = "presence" -- "presence" | "watchdog" — B9: RunEnd must say which one it was
```

Full corrected `armWatchdog`:
```lua
local function armWatchdog(forState: string, gen: number)
	local seconds = Config.Shift.Watchdog[forState]
	if not seconds then
		return
	end
	task.delay(seconds, function()
		if state == forState and stateGen == gen then
			Util.warn(("WATCHDOG: state '%s' exceeded %ds — forcing transition"):format(forState, seconds))
			if forState == "ShiftActive" then
				-- B9: a ShiftActive timeout is NOT a possession scare — never reuse that framing.
				runEndReason = "watchdog"
				transition("RunEnd")
			elseif forState == "ShiftIntro" then
				Remotes.get(Remotes.Names.Toast):FireAllClients(("watchdog: forcing past %s"):format(forState), 4)
				transition("ShiftActive")
			elseif forState == "ShiftResult" then
				Remotes.get(Remotes.Names.Toast):FireAllClients(("watchdog: forcing past %s"):format(forState), 4)
				transition("ShiftIntro")
			elseif forState == "RunEnd" then
				Remotes.get(Remotes.Names.Toast):FireAllClients(("watchdog: forcing past %s"):format(forState), 4)
				transition("LobbyIdle")
			end
		end
	end)
end
```

`RunEnd` branch of `transition()` — **apply this replacement to P2's merged `RunEnd` branch** (keep
P2's `traitorName`/`shiftReached` fix inside it; only the scare-vs-timeout framing and the `reason`
field on the `Recap` payload are new here):

```lua
	elseif newState == "RunEnd" then
		stopShiftSystems()
		local reason = runEndReason
		if reason == "watchdog" then
			-- B9: a shift timeout is NOT a possession scare. No scream, no shadow face, no
			-- lights-out — just an honest, in-world "we're closing" beat.
			Remotes.get(Remotes.Names.Toast):FireAllClients(
				"The shift ran too long... the shop is closing for the night.",
				6
			)
			Remotes.get(Remotes.Names.HauntFired):FireAllClients("ShiftTimeout", {})
		else
			-- THE scare (genuine Presence-maxed ending only)
			Remotes.get(Remotes.Names.HauntFired):FireAllClients("DollmakerReveal", {})
			for _, lamp in ctx.manifest.lamps do
				local light = lamp:FindFirstChildOfClass("PointLight")
				if light then
					light.Enabled = false
				end
			end
		end
		-- (traitorName snapshot logic per P2's A4/B7 fix, unchanged, goes here)
		local traitorName = markedDollName or "…someone"
		task.delay(4, function()
			if stateGen ~= gen then
				return
			end
			for _, lamp in ctx.manifest.lamps do
				local light = lamp:FindFirstChildOfClass("PointLight")
				if light then
					light.Enabled = true
				end
			end
			pruneParticipants()
			for _, player in participants do
				local stats = ctx.services.DataService.getStats(player)
				local isNewBest = shiftNumber > stats.bestShift
				ctx.services.DataService.recordRun(player, {
					shiftReached = shiftNumber,
					dollsCleared = runStats.dollsCleared,
					perfect = runStats.perfect,
				})
				Remotes.get(Remotes.Names.Recap):FireClient(player, {
					shiftReached = shiftNumber,
					dollsCleared = runStats.dollsCleared,
					perfect = runStats.perfect > 0 and strikes == 0,
					traitorName = traitorName,
					bestShift = math.max(stats.bestShift, shiftNumber),
					isNewBest = isNewBest,
					reason = reason, -- "presence" | "watchdog" — B9: recap must not lie about the cause
				})
			end
			cleanupRun()
			teleportTo(ctx.manifest.lobbySpawn, participants)
			transition("LobbyIdle")
		end)
	end
```

`ShiftManager.init` — only the `PresenceService.onMaxed` callback changes (tag the reason):

```lua
	ctx.services.PresenceService.onMaxed(function()
		if state == "ShiftActive" then
			-- B9: genuine Presence-maxed ending — tag it explicitly (armWatchdog tags "watchdog"
			-- on the other RunEnd path) so transition("RunEnd") knows which beat/message to use.
			runEndReason = "presence"
			transition("RunEnd")
		end
	end)
```

- **Remote notes:** No new remote — reuses `HauntFired` with a new `hauntId` value `"ShiftTimeout"`
  (same pattern as `"DollmakerReveal"`; not in `Defs/Haunts.luau`'s weighted-draw catalog, that's only
  for `HauntService`'s ambient scheduler). `Recap`'s payload gains one new field: `reason: "presence" |
  "watchdog"` — flag for `docs/INTERFACES.md` to document.

### Fix 4 — `HauntClient.luau`: a calm "shop is closing" beat, distinct from the possession scare

New function to add (place it near `dollmakerReveal`, before `HauntClient.init`):
```lua
-- B9: the watchdog-timeout RunEnd — a calm "closing time" beat, deliberately NOT a scare.
local function shiftTimeout()
	local g = gui
	if not g then
		return
	end
	SoundKit.play("DoorSlam") -- existing placeholder cue, thematically a closing door (id currently 0/silent)
	local dim = Instance.new("Frame")
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.Size = UDim2.new(1, 0, 1, 0)
	dim.ZIndex = 5
	dim.Parent = g
	local label = Theme.label(dim, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0.8, 0, 0, 80),
		Font = Theme.TitleFont,
		TextSize = 34,
		TextColor3 = Theme.Muted,
		TextTransparency = 1,
		ZIndex = 6,
		Text = "The shop is closing for the night…",
	})
	TweenService:Create(dim, TweenInfo.new(0.8), { BackgroundTransparency = 0.55 }):Play()
	TweenService:Create(label, TweenInfo.new(0.8), { TextTransparency = 0 }):Play()
	task.delay(3.5, function()
		TweenService:Create(dim, TweenInfo.new(1), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, TweenInfo.new(1), { TextTransparency = 1 }):Play()
		task.delay(1.1, function()
			dim:Destroy()
		end)
	end)
end
```

Full corrected dispatcher:
```lua
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
		elseif hauntId == "ShiftTimeout" then
			shiftTimeout()
		end
		-- unknown ids: ignore silently
	end)
end
```

Also update the module's header comment (line 2) to mention the new `ShiftTimeout` closing beat.

### Fix 5 — `RecapUI.luau`: the recap card must say which ending it was

Full corrected function (adds one reason-aware line just under the shift-number headline; layout of everything below it shifts down 24px):

```lua
local function showRecap(data: any)
	local g = gui
	if not g then
		return
	end
	local dim = black(0.35)
	local card = Theme.panel(g, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 460, 0, 424),
		BackgroundTransparency = 0.02,
		ZIndex = 3,
	})
	Theme.label(card, {
		Position = UDim2.new(0, 0, 0, 14),
		Size = UDim2.new(1, 0, 0, 26),
		TextSize = 16,
		TextColor3 = Theme.Muted,
		Text = "THE NIGHT ENDS",
	})
	Theme.label(card, {
		Position = UDim2.new(0, 0, 0, 40),
		Size = UDim2.new(1, 0, 0, 110),
		Font = Theme.TitleFont,
		TextSize = 92,
		Text = ("SHIFT %d"):format(data.shiftReached or 0),
	})
	-- B9: the recap must not always imply "the Presence got you" — say the real cause.
	Theme.label(card, {
		Position = UDim2.new(0, 0, 0, 150),
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 14,
		TextColor3 = Theme.Muted,
		Text = if data.reason == "watchdog"
			then "The night ran long. The shop had to close before the Presence ever caught you."
			else "The Presence caught up with you.",
	})
	local statLines = {
		("Dolls cared for: %d"):format(data.dollsCleared or 0),
		("The traitor was %s."):format(data.traitorName or "…unknown"),
		("Best shift: %d"):format(data.bestShift or 0),
	}
	for i, text in statLines do
		Theme.label(card, {
			Position = UDim2.new(0, 0, 0, 178 + (i - 1) * 30),
			Size = UDim2.new(1, 0, 0, 26),
			Font = Theme.TitleFont,
			TextSize = 21,
			Text = text,
		})
	end
	if data.isNewBest then
		Theme.label(card, {
			Position = UDim2.new(0, 0, 0, 270),
			Size = UDim2.new(1, 0, 0, 34),
			Font = Theme.TitleFont,
			TextSize = 30,
			TextColor3 = Theme.Gold,
			Text = "✦ NEW BEST ✦",
		})
	end
	if data.perfect then
		Theme.label(card, {
			Position = UDim2.new(0, 0, 0, 302),
			Size = UDim2.new(1, 0, 0, 26),
			TextSize = 16,
			TextColor3 = Theme.Gold,
			Text = "Perfect shifts, zero strikes. The Dollmaker approves.",
		})
	end
	local button = Theme.button(card, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(0, 220, 0, 56),
		TextSize = 22,
		Text = "RETURN",
	})
	button.Activated:Connect(function()
		dim:Destroy()
		card:Destroy()
	end)
	task.delay(20, function()
		if dim.Parent then
			dim:Destroy()
			card:Destroy()
		end
	end)
end
```

### Test notes — `tests/logic.spec.luau`

`PresenceMath.step`'s behavior changes (the surge no longer over-amplifies). The two existing surge-related checks (`"surge raises value faster than base"` and `"event surge raises value"`) still pass unmodified — they're loose lower-bound checks, not exact-value checks. Add a new, tight "surge integral" check that pins down the exact total contribution and would fail loudly against the old formula:

```lua
	-- surge integral: a surge event contributes exactly its nominal amount, never amplified (B9 fix)
	local st6 = PresenceMath.new()
	PresenceMath.addSurge(st6, 20)
	local dt = 0.1
	local ticks = 0
	while st6.surge > 0 and ticks < 10000 do
		PresenceMath.step(st6, cfg, dt, 0) -- rateMultiplier=0 isolates the surge-only contribution
		ticks += 1
	end
	local elapsed = ticks * dt
	check("surge fully drains", st6.surge == 0, tostring(st6.surge))
	check("surge contributes exactly its nominal amount, not amplified", math.abs(st6.value - 20) < 0.01, tostring(st6.value))
	check(
		"surge drains in amount/DecayPerSecond seconds",
		math.abs(elapsed - (20 / cfg.RushDecayPerSecond)) < 0.15,
		tostring(elapsed)
	)
```

Place this block right after the existing `"strike surges"` block (before the closing `end` of the `== PresenceMath ==` `do` block). With the pre-fix formula this new block fails hard: `st6.value` converges to ~80 (≈4×20) instead of 20. No other test in the file references `Presence`/`Escalation` numbers affected by the `Config.luau` retune, since `logic.spec.luau`'s `PresenceMath` block already uses its own literal `cfg` table, independent of `src/shared/Config.luau`.

---

## P4 — Client-side UI polish: Ledger not closing, a tofu-box emoji, and a naming-picker self-duplicate

> Cluster: **Client-side UI polish** — Ledger not closing, tofu-box emoji, naming-picker self-duplicate.
> No conflicts with P2/P3 — applies independently.

### B5 — Ledger book doesn't close on walk-away or on the ShiftResult→ShiftIntro transition

**File(s):** `src/client/Controllers/LedgerUI.luau`

**Current behavior:** The Ledger panel only closes via its own ✕ button, or when `StateChanged` fires `"LobbyIdle"` or `"RunEnd"`. Nothing closes it when the player walks away from the desk, and nothing closes it on the shift→shift transition.

**Root cause:** Two gaps: (1) `LedgerUI.init()`'s `StateChanged` handler only checks `"LobbyIdle"`/`"RunEnd"`, not `"ShiftResult"`/`"ShiftIntro"` — the two states that actually fire between shifts. (2) No proximity/distance watch at all.

Confirmed state ordering in `ShiftManager.luau`: on shift end, `transition("ShiftResult")` fires immediately, then after `Config.Shift.ResultSeconds` (default 8s) it calls `transition("ShiftIntro")`, and **only inside the `ShiftIntro` branch** does `teleportTo(ctx.manifest.workshopSpawn, participants)` run. So `"ShiftResult"` fires well before the teleport — closing the book on `"ShiftResult"` is the earliest-and-safest hook.

**Fix:**

Update the top of the file (add `Players`, `ProximityPromptService`, `RunService`; keep the existing `CollectionService` import):

```lua
--!strict
-- The Dollmaker's ledger: spirits + codes on the left, shared slots + found tray on the right.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local Glyphs = require(Shared:WaitForChild("Defs"):WaitForChild("Glyphs")) :: any
local Spirits = require(Shared:WaitForChild("Defs"):WaitForChild("Spirits")) :: any
local GlyphMatch = require(Shared:WaitForChild("Logic"):WaitForChild("GlyphMatch")) :: any
local GlyphRender = require(Shared:WaitForChild("GlyphRender")) :: any
local SoundKit = require(Shared:WaitForChild("SoundKit")) :: any
local Theme = require(script.Parent.Parent:WaitForChild("Theme")) :: any

local LedgerUI = {}

local gui: ScreenGui? = nil
local slotFrames: { Frame } = {}
local trayFrame: Frame? = nil
local matchBanner: TextLabel? = nil
local found: { string } = {}
local slots: { [number]: string? } = {}
local selectedGlyph: string? = nil
local deskPart: BasePart? = nil
local distanceConn: RBXScriptConnection? = nil
```

Insert this new block of open/close helpers right after the state locals above (before the existing `glyphButton` function):

```lua
-- ---------- open / close + walk-away auto-close (B5) ----------

local function stopDistanceWatch()
	if distanceConn then
		distanceConn:Disconnect()
		distanceConn = nil
	end
end

local function closeBook()
	if gui then
		gui.Enabled = false
	end
	stopDistanceWatch()
end

local function getLedgerDesk(): BasePart?
	if deskPart and deskPart.Parent then
		return deskPart
	end
	local tagged = CollectionService:GetTagged("LedgerDesk")
	local part = tagged[1]
	if part and part:IsA("BasePart") then
		deskPart = part
		return deskPart
	end
	return nil
end

local function startDistanceWatch()
	stopDistanceWatch()
	local desk = getLedgerDesk()
	if not desk then
		-- desk not found (shouldn't happen once MapBuilder has run) — fail open rather than
		-- trap the player with an unclosable book (R2)
		return
	end
	distanceConn = RunService.Heartbeat:Connect(function()
		local g = gui
		if not g or not g.Enabled then
			stopDistanceWatch()
			return
		end
		local char = Players.LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		if (root.Position - desk.Position).Magnitude > Config.Ledger.AutoCloseDistance then
			closeBook()
		end
	end)
end

local function openBook()
	if not gui then
		return
	end
	gui.Enabled = true
	startDistanceWatch()
end
```

Inside `buildBook()`, the close (✕) button wiring changes from `close.Activated:Connect(function() g.Enabled = false end)` to:

```lua
	close.Activated:Connect(closeBook)
```

Finally, replace the whole `LedgerUI.init()` function with:

```lua
function LedgerUI.init()
	buildBook()

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		if player ~= Players.LocalPlayer then
			return
		end
		if prompt.ObjectText == "Spirit Ledger" then
			openBook()
		end
	end)

	Remotes.get(Remotes.Names.GlyphFound).OnClientEvent:Connect(function(_glyphId: any, data: any)
		if typeof(data) ~= "table" then
			return
		end
		if typeof(data.found) == "table" then
			found = data.found
		end
		if typeof(data.slots) == "table" then
			slots = {}
			for i = 1, 3 do
				local v = data.slots[i]
				slots[i] = if typeof(v) == "string" then v else nil
			end
		end
		refreshTray()
		refreshSlots()
	end)

	-- close the book automatically: end of run, AND the shift->shift transition (B5).
	Remotes.get(Remotes.Names.StateChanged).OnClientEvent:Connect(function(state: any)
		if state == "LobbyIdle" or state == "RunEnd" or state == "ShiftResult" or state == "ShiftIntro" then
			closeBook()
		end
	end)
end
```

(`glyphButton`, `refreshSlots`, `refreshTray`, and `buildBook` are otherwise unchanged — only the close-button wiring line inside `buildBook` changes.)

- **Config:** add a new key `Config.Ledger.AutoCloseDistance = 12` (studs) to `src/shared/Config.luau`. Insert a new top-level `Ledger` table between the existing `Glyphs` and `Banish` tables:
  ```lua
  	Glyphs = {
  		PerShift = 3,
  		CollectDistance = 10,
  		DetectorMaxRange = 40,
  	},

  	Ledger = {
  		AutoCloseDistance = 12, -- studs; auto-close the ledger book once the player strays this far from LedgerDesk (B5)
  	},

  	Banish = {
  ```
- **Remotes:** none — reuses `StateChanged`/`GlyphFound`.
- **Tests:** none — `LedgerUI.luau` has no logic under `src/shared/Logic/*.luau`.
- Note: this is a UI-state bug, not map geometry — **not superseded by the map redesign**. `LedgerDesk` is looked up purely by CollectionService tag, so it keeps working unchanged even if the desk's position/room layout changes under a rebuilt `MapBuilder`.

### B6 — Brush button renders as a tofu box (🪮 has no font coverage)

**File(s):** `src/client/Controllers/MinigameController.luau` (icon), `src/client/Theme.luau` (font, read-only reference — no change needed there)

**Current behavior:** The mash-style "Brush the Hair" minigame button's label is the Unicode comb emoji `🪮` (U+1FAAE). In-game it renders as an empty placeholder glyph.

**Root cause:** `Theme.button(...)` draws button text with `Theme.TitleFont = Enum.Font.Garamond`, and Roblox's client-side emoji rendering only substitutes glyph images for a fixed, curated set of older Unicode codepoints. `🪮` is Unicode 14.0 (2022), too recent. This is exactly why the panic button (`😱`) and the debug error-panel toggle (`🐞`) both work fine — both are Unicode 6.0 (2010), safely inside Roblox's supported range.

**Fix — recommendation: draw the brush procedurally, not swap emoji.** The brush icon sits on the single most-tapped button in the entire core loop, so it shouldn't depend on Roblox's emoji-support list not regressing. This codebase already has a working, zero-asset pattern for exactly this (`src/shared/GlyphRender.luau` draws every spirit glyph as small `Frame`+`UICorner` shapes), so drawing the brush the same way is idiomatic, not a new technique.

Replace the current `mashGame` function:

```lua
local function mashGame(dollId: string, stepId: string)
	local panel, arena = makePanel("Brush the Hair", "Tap the brush — smooth every tangle!")
	local _, setProgress = progressBar(panel)
	local progress = 0
	local button = Theme.button(arena, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 160, 0, 120),
		TextSize = 40,
		Text = "🪮",
	})
	button.Activated:Connect(function()
		SoundKit.play("BrushStroke")
		progress += 0.09
		setProgress(progress)
		button.Rotation = (math.random() - 0.5) * 20
		if progress >= 1 then
			finish(dollId, stepId, true)
		end
	end)
end
```

with:

```lua
-- Procedural hairbrush icon (paddle head + bristles + handle), built from Frame/UICorner
-- instances — same zero-asset technique as GlyphRender.luau — so it never depends on
-- Roblox's emoji-glyph font coverage (B6: 🪮 rendered as a tofu box on some clients).
local function drawBrushIcon(parent: GuiObject)
	local canvas = Instance.new("Frame")
	canvas.BackgroundTransparency = 1
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.Parent = parent

	local head = Instance.new("Frame")
	head.AnchorPoint = Vector2.new(0.5, 0.5)
	head.Position = UDim2.fromScale(0.5, 0.36)
	head.Size = UDim2.fromScale(0.62, 0.36)
	head.BackgroundColor3 = Theme.Parchment
	head.BorderSizePixel = 0
	head.Parent = canvas
	local headCorner = Instance.new("UICorner")
	headCorner.CornerRadius = UDim.new(1, 0)
	headCorner.Parent = head

	for i = 1, 5 do
		local bristle = Instance.new("Frame")
		bristle.AnchorPoint = Vector2.new(0.5, 1)
		bristle.Position = UDim2.fromScale(0.19 + (i - 1) * 0.155, 0.2)
		bristle.Size = UDim2.fromScale(0.05, 0.2)
		bristle.BackgroundColor3 = Theme.Bg
		bristle.BorderSizePixel = 0
		bristle.Parent = canvas
		local bristleCorner = Instance.new("UICorner")
		bristleCorner.CornerRadius = UDim.new(1, 0)
		bristleCorner.Parent = bristle
	end

	local handle = Instance.new("Frame")
	handle.AnchorPoint = Vector2.new(0.5, 0.5)
	handle.Position = UDim2.fromScale(0.5, 0.78)
	handle.Size = UDim2.fromScale(0.16, 0.42)
	handle.BackgroundColor3 = Theme.Gold
	handle.BorderSizePixel = 0
	handle.Parent = canvas
	local handleCorner = Instance.new("UICorner")
	handleCorner.CornerRadius = UDim.new(1, 0)
	handleCorner.Parent = handle
end

local function mashGame(dollId: string, stepId: string)
	local panel, arena = makePanel("Brush the Hair", "Tap the brush — smooth every tangle!")
	local _, setProgress = progressBar(panel)
	local progress = 0
	local button = Theme.button(arena, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 160, 0, 120),
		Text = "",
	})
	drawBrushIcon(button)
	button.Activated:Connect(function()
		SoundKit.play("BrushStroke")
		progress += 0.09
		setProgress(progress)
		button.Rotation = (math.random() - 0.5) * 20
		if progress >= 1 then
			finish(dollId, stepId, true)
		end
	end)
end
```

`drawBrushIcon` should be inserted above `mashGame` (e.g. directly below the existing `progressBar` function).

- **Config/Remotes/Tests:** none needed. Not a map-geometry issue; unaffected by the map redesign track.

### B10 — Naming picker can offer the doll's own current/default name as a "new name" choice

**File(s):** `src/client/Controllers/NamingUI.luau` (the actual bug); `src/server/Services/DollService.luau` and `src/server/Services/ShiftManager.luau` read for context only, no changes needed there.

**Current behavior:** The naming picker samples 6 unique random indices straight out of the full `DollNames` list with no awareness of which name the doll already has. A doll auto-named "Momo" at spawn can have "Momo" reappear as one of its own 6 picker buttons.

**Root cause:** `ShiftManager.luau` assigns default names at shift start via `Draw.sample(ctx.rng, DollNames, shiftParams.dollCount)`, broadcast to clients as `ShiftData`'s `dolls[i].name`. `NamingUI.luau` currently never consumes that `name` field at all — its `fillNames()` closure just does `picked[math.random(1, #DollNames)] = true` against the raw `DollNames` list, blind to what the doll is already called. The server's `ChooseName` handler also doesn't reject a same-name pick.

**Fix:** Track each doll's current name client-side (populated from `ShiftData` at shift start, kept fresh from `DollUpdate`'s existing `name` field), then reject that name while sampling.

Add one new module-level state var, next to the existing ones:

```lua
local gui: ScreenGui? = nil
local panel: Frame? = nil
local offeredFor: { [string]: boolean } = {}
local currentDollId: string? = nil
local dollNames: { [string]: string } = {} -- dollId -> current display name, so the picker can exclude it (B10)
```

Replace the whole `offer` function:

```lua
local function offer(dollId: string)
	if panel then
		return
	end
	currentDollId = dollId
	local g = gui
	assert(g)
	local p = Theme.panel(g, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.new(0, 460, 0, 220),
		BackgroundTransparency = 0.06,
	})
	panel = p
	Theme.label(p, {
		Position = UDim2.new(0, 0, 0, 10),
		Size = UDim2.new(1, 0, 0, 28),
		Font = Theme.TitleFont,
		TextSize = 24,
		Text = "Name this doll?",
	})
	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.new(0, 14, 0, 46)
	grid.Size = UDim2.new(1, -28, 0, 118)
	grid.Parent = p
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.333, -8, 0, 52)
	layout.CellPadding = UDim2.new(0, 8, 0, 8)
	layout.Parent = grid

	local function fillNames()
		for _, child in grid:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		-- exclude the doll's own current/default name so tapping a choice always does something (B10)
		local currentName = dollNames[dollId]
		local picked: { [number]: boolean } = {}
		local pickedCount = 0
		local wanted = math.min(6, math.max(0, #DollNames - (if currentName then 1 else 0)))
		local attempts = 0
		local maxAttempts = #DollNames * 20 + 20 -- generous ceiling: a bad roll can never hang the UI (R2)
		while pickedCount < wanted and attempts < maxAttempts do
			attempts += 1
			local index = math.random(1, #DollNames)
			if not picked[index] and DollNames[index] ~= currentName then
				picked[index] = true
				pickedCount += 1
			end
		end
		for index in picked do
			local button = Theme.button(grid, {
				TextSize = 18,
				Text = DollNames[index],
			})
			button.Activated:Connect(function()
				local id = currentDollId
				if id then
					SoundKit.play("UiConfirm")
					Remotes.get(Remotes.Names.ChooseName):FireServer(id, index)
				end
				close()
			end)
		end
	end
	fillNames()

	local shuffle = Theme.button(p, {
		Position = UDim2.new(0, 14, 1, -46),
		Size = UDim2.new(0.5, -22, 0, 36),
		TextSize = 17,
		Text = "↻ other names",
	})
	shuffle.Activated:Connect(fillNames)
	local skip = Theme.button(p, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 1, -46),
		Size = UDim2.new(0.5, -22, 0, 36),
		TextSize = 17,
		Text = "keep current name",
	})
	skip.Activated:Connect(close)

	-- never block the loop: auto-dismiss (R2)
	task.delay(15, function()
		if currentDollId == dollId then
			close()
		end
	end)
end
```

Replace the whole `NamingUI.init` function:

```lua
function NamingUI.init()
	if not Config.Features.Naming then
		return
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local g = Theme.screenGui("PorcelainNaming", 11)
	g.Parent = playerGui
	gui = g

	-- track each doll's current name (default at spawn, then whatever ChooseName lands) so the
	-- picker can filter its own current name out of its option list (B10)
	Remotes.get(Remotes.Names.ShiftData).OnClientEvent:Connect(function(data: any)
		if typeof(data) ~= "table" or typeof(data.dolls) ~= "table" then
			return
		end
		for _, doll in data.dolls do
			if typeof(doll) == "table" and typeof(doll.id) == "string" and typeof(doll.name) == "string" then
				dollNames[doll.id] = doll.name
			end
		end
	end)

	-- offer naming when the local player finishes their first minigame on a doll:
	-- MinigameStart implies this player is working that doll; offer after the step completes (DollUpdate).
	local workingDoll: string? = nil
	Remotes.get(Remotes.Names.MinigameStart).OnClientEvent:Connect(function(dollId: any)
		if typeof(dollId) == "string" then
			workingDoll = dollId
		end
	end)
	Remotes.get(Remotes.Names.DollUpdate).OnClientEvent:Connect(function(dollId: any, update: any)
		if typeof(dollId) ~= "string" or typeof(update) ~= "table" then
			return
		end
		if typeof(update.name) == "string" then
			dollNames[dollId] = update.name
		end
		if update.careDone and dollId == workingDoll and not offeredFor[dollId] then
			offeredFor[dollId] = true
			offer(dollId)
		end
	end)
	Remotes.get(Remotes.Names.StateChanged).OnClientEvent:Connect(function(state: any)
		if state == "LobbyIdle" or state == "RunEnd" then
			offeredFor = {}
			dollNames = {}
			close()
		end
	end)
end
```

- **Config/Remotes/Tests:** none needed. Not a map-geometry issue; unaffected by the map redesign track.
