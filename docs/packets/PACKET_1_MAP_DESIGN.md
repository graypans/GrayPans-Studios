# Packet 1 — Map Design

Source: 3 independent agents, each given the same brief (team's plain-language description of the
Animal Hospital lobby model + the current game's zones), asked to commit fully to one distinct angle
without seeing each other's work. A 4th agent then scored and synthesized a final recommendation.
Produced 2026-08-15 for `CHECKLIST_1.md` §1/§O3. Nobody has written any code yet — this is design only.

**Team decision needed:** read the judge's recommendation (§4) first — it names the winning hub theme
in its first sentence and gives a "ready to build" spec cloud Claude can implement directly. If the team
prefers a different proposal or a different synthesis, say so and this doc gets revised before coding
starts; otherwise §4's "Ready to build" section is what should go into the rewritten `MapBuilder.luau`.

---

## 1. Proposal 1 — "Thimble Row" (grounded horror-realism: dead-end street)

*One of three independent competing proposals for the Lobby Hub + Workshop map. Grounded in the
current `src/server/Services/MapBuilder.luau`, `docs/INTERFACES.md`, and `src/shared/Config.luau` as
they exist today.*

# Lobby Hub + Workshop Redesign — Proposal: "Thimble Row"
### Grounded horror-realism angle — a dead-end street outside the Dollmaker's shopfront

## 1. Pitch

**Thimble Row** is a single dead-end alley at the back of a forgotten notions district — cracked wet
pavement, one flickering sodium streetlamp, a rusted parked delivery van, low fog pooling at ankle
height, and a hand-buzzed neon sign over a shopfront window full of dolls staring out at the street.
Players spawn at the closed end of the alley and walk *toward* the light — the shop is the only warm,
readable thing in the whole scene, which does the job of both a wayfinding beacon and the game's
"come inside" hook. Tone is **liminal urban unease, not fantasy horror**: nothing here is supernatural
to look at — it's just an empty street, too quiet, at an hour nobody should be out. The scares stay
inside the shop, where they belong.

The single biggest structural change from the current build: **the Workshop is no longer walked to.**
Players enter it exclusively via the existing server-side teleport that already fires at `ShiftIntro`
(`docs/INTERFACES.md`: *"teleport participants to workshop spawn (PivotTo)"*). That means the hub and
workshop no longer need a connecting corridor at all — which deletes the entire bug class that broke
the last playtest (gap-prone room-to-room seams along a long connector). The shopfront door in the hub
is decorative only: closed, locked, and never a physical gateway.

## 2. Room-by-room table

All coordinates are **local offsets** from two named origin constants, exactly mirroring the existing
code's `LOBBY`/`SHOP` constant pattern in `MapBuilder.luau`:

- `HUB = Vector3.new(0, 0, 0)` (replaces `LOBBY`)
- `WORKSHOP = Vector3.new(300, 0, 0)` (replaces `SHOP` — exact placement is arbitrary since it's
  teleport-only and never walked to; keep it far enough from `HUB` that nothing visually bleeds
  through fog)

| Zone | Room / Feature | Purpose | Approx. size (studs) | Connects to | Key props / set-dressing |
|---|---|---|---|---|---|
| **HUB** | Dead-End Alley (whole street slab) | Spawn zone, establishing shot | 36 (X) × 72 (Z), one continuous floor, open sky (no ceiling) | Open street — all hub zones below sit on this one slab, no walls between them | Cracked dark asphalt (`Material.Slate`/dark `SmoothPlastic`), 4–6 flat semi-transparent dark-blue "puddle" parts scattered on the ground to fake wet reflections |
| HUB | Spawn point | Default `SpawnLocation`, tag `LobbySpawn` | `HUB + (0, 0.5, -58)`, faces +Z (north, toward shop) | — | — |
| HUB | Dead-end fence/wall | Terminates the space, blocks travel south | `HUB + (0, 5, -65)`, 36×10×1 | South boundary | **Toolbox search: "chain link fence low poly"** or "rusted brick wall"; dumpster prop at `HUB + (-12, 1.5, -61)` — **Toolbox search: "low poly dumpster"** |
| HUB | Flank walls (east + west) | Bound the alley visually, sell "narrow gap between buildings" | Two walls, each 1×16×72, at `HUB.X = -18` and `HUB.X = +18` | Backdrop only, no gameplay function | Dark unlit brick texture, a few blank windows for silhouette interest (non-functional) |
| HUB | Parked delivery van | Mid-alley set piece, west sidewalk | Footprint ~7×16, centered `HUB + (-11, 1.5, -34)`, parked lengthwise | — | **Toolbox search: "low poly delivery van"** or "rusty cargo van model" |
| HUB | Hero streetlamp | The one flickering light per the brief | `HUB + (9, 0, -34)` | — | Reuse existing `lamp()` helper + `Lamp` tag; flicker via existing PointLight pattern, brightness dips ~1×/6s |
| HUB | Secondary steady lamp | Practical light so join squares stay legible in fog | `HUB + (-9, 0, -12)` | — | Same `lamp()` helper, no flicker (this one's just for visibility) |
| HUB | Kiosk Row (4 booths) | Shop / Classes / Journal / Invite | Each ~4×4×6, all at `HUB.X = 14`, spaced along Z: Shop `-48`, Classes `-40`, Journal `-32`, Invite `-24` | East sidewalk, open to street | Small standalone stalls/carts, glowing SurfaceGui icon on top, `ProximityPrompt` each |
| HUB | Join Plaza (6 squares) | The Animal-Hospital-style join tiles | Each tile 6×6, two rows of 3: row A at `Z=-16` (`X = -10, 0, 10`), row B at `Z=-8` (`X = -10, 0, 10`) | Centered in front of the shop steps | Chalk/paint-marked floor tiles (Neon material, idle = dim grey-blue, lit = yellow), small `BillboardGui` above each showing live "1/4" count |
| HUB | Shop stoop | A couple of steps up to the door | `HUB + (0, 0.5, -2)`, 10×1×4 | Leads visually (not mechanically) to the door | — |
| HUB | Shopfront facade | The screenshot moment | Wall at `HUB.Z = 4`, 36×16×1 | North boundary; door is decorative/locked | Buzzing neon sign centered `HUB + (0, 13, 4.5)` reading the shop's name; two display windows either side of the door (`X ≈ ±11`, ~8 wide) — glass pane + interior `PointLight` + 2–3 static doll silhouette props visible behind glass. **Toolbox search: "porcelain doll mannequin" / "creepy doll model, free"** — MUST be audited (no lookalikes of branded horror dolls); "antique shop window trim" for facade molding |
| **WORKSHOP** | Bench Room (entry) | Doll-care bench, 5 care slots, ribbon spool | `WORKSHOP` center, 60 (X) × 26 (Z) | North wall has 2 door gaps → Storage Alcove (west) + Ledger Room (east) | Workbench along west interior wall at `WORKSHOP + (-26, 2, 0)`, size 6×4×20; 5 `BenchSlot` markers along it at `Z = -8,-4,0,4,8`; `RibbonSpool` near south end at `WORKSHOP + (-26, 3, -9)`; **Toolbox search: "sewing / dollmaker tool set prop pack"** for bench clutter |
| WORKSHOP | Workshop spawn (teleport landing) | Where `ShiftIntro` PivotTo's participants | `WORKSHOP + (0, 0.5, -11)` | Sits inside Bench Room, near entrance | Tag `WorkshopSpawn`, `Enabled=false` by default per existing convention |
| WORKSHOP | Storage Alcove | Glyph hunting, decor shelves | `WORKSHOP + (-16, 0, 25)`, 28×24 | Door gap (X≈-16) south → Bench Room; door gap (X≈-16) north → Banish Room; door gap east → Cross Hall | 3 wall shelves along back wall with decor-doll silhouettes (reuse existing `DecorDoll` pattern); 2 `GlyphSpawn` markers; **Toolbox search: "victorian wood shelf low poly"** |
| WORKSHOP | Ledger Room | Ledger desk, detector rack | `WORKSHOP + (16, 0, 25)`, 28×24 | Door gap (X≈16) south → Bench Room; door gap (X≈16) north → Banish Room; door gap west → Cross Hall | `LedgerDesk` + book prop near back wall; `DetectorRack` beside it; 2 `GlyphSpawn` markers; **Toolbox search: "antique leather ledger book prop"** |
| WORKSHOP | Cross Hall | Short direct connector, Storage ↔ Ledger | Gap at `WORKSHOP.X = -2..2`, `Z = 21..29` (4 wide) | Storage Alcove ↔ Ledger Room directly | 1 `GlyphSpawn` tucked here, 1 `HauntDoor` for creak-slam beats |
| WORKSHOP | Banish Room | Win condition room | `WORKSHOP + (0, 0, 48)`, 60×22 | **Two independent entrances**: from Storage (X≈-16) and from Ledger (X≈16) | `BanishBox` model centered `WORKSHOP + (0, 2, 51)`; 2 `HauntDoor`s (one flanking each entrance); 2 `GlyphSpawn` markers near far corners |

Total workshop footprint: **60 × 72 studs**, one continuous floor slab and one continuous ceiling
slab, uniform 12-stud interior height throughout. Total glyph spawns: 9 (meets the "≥8, spread across
all workshop rooms" contract requirement).

## 3. Top-down sketch

The hub and workshop are drawn separately because they are not physically adjacent — the only link
between them is the server teleport, never a walked path.

```
HUB  (origin (0,0,0), north/+Z = toward shop)

 Z=+6  ┌──────────────────────────────────────────────────┐
       │             SHOPFRONT FACADE  (h=16)              │
 Z=+4  │   [window: dolls]   ▓NEON SIGN▓   [window: dolls]  │
       │                    [door, locked/decorative]       │
 Z=0   └───────────────────────▲──────────────────────────┘
                              stoop
 Z=-2..-4                    steps
                     ·lamp(steady)·
 Z=-8    [ JS4 ]        [ JS5 ]        [ JS6 ]     <- join plaza row B
 Z=-16   [ JS1 ]        [ JS2 ]        [ JS3 ]     <- join plaza row A
 Z=-24                                    ▯ Invite kiosk (X=14)
 Z=-32                                    ▯ Journal kiosk
 Z=-34         ▓▓▓▓▓▓ VAN ▓▓▓▓▓▓ (X=-11)    ·lamp(flicker)·(X=9)
 Z=-40                                    ▯ Classes kiosk
 Z=-48                                    ▯ Shop kiosk
 Z=-58                    ⭑ SPAWN (faces north)
 Z=-65   ══════════ dead-end fence + dumpster ══════════
        X: -18        -10        0        10         18
```

```
WORKSHOP  (origin (300,0,0) — reached only by teleport, never walked)

 Z=+59 ┌────────────────────────────────────────────────────┐
       │                    BANISH ROOM                       │
 Z=+51 │      [HauntDoor]   ◆BANISH BOX◆   [HauntDoor]        │
       │                                                        │
 Z=+37 └──────────[door X≈-16]──────────────[door X≈+16]───────┘
                        │                          │
 Z=+13..+37   STORAGE ALCOVE   ‖cross hall‖    LEDGER ROOM
              (shelves, 2 glyph)‖ (1 glyph) ‖   (desk, rack, 2 glyph)
 Z=+13  ┌──────────[door X≈-16]────┴────[door X≈+16]───────────┐
        │                    BENCH ROOM                          │
 Z=-11  │     [teleport landing]   workbench (west wall, 5 slot)  │
        │                          ribbon spool                   │
 Z=-13  └────────────────────────────────────────────────────────┘
        X: -30           -16          0          16            30
```

## 4. Lighting / atmosphere

Hub: `Lighting.ClockTime` deep night (~1:30), cool blue-grey `FogColor`, `FogStart ≈ 15` /
`FogEnd ≈ 110` — close enough that the dead-end fence and van resolve as shapes-in-fog rather than
crisp geometry, but the shop's neon sign, window glow, and the two streetlamps all stay bright enough
to punch through and pull the eye north. The join squares and kiosks sit inside that lit corridor of
visibility on purpose — nothing gameplay-critical is fogged out. Workshop: keep the existing warm
amber `Lamp` palette almost unchanged (it already works), but because the whole workshop is now one
shared ceiling height, add a slight cool-purple accent light source in the Banish Room specifically
(existing `banishGlow` PointLight, just always-dim-on instead of 0-until-unlocked) so that room reads
as psychologically "different" the moment a player rounds the corner into it, without needing separate
room heights to sell the mood shift.

## 5. Why this angle, and the honest tradeoff

**Why it's strong:** this is the most literal, lowest-interpretive-risk reading of the team's own
brief — "creepy parking lot outside the doll repair shop" *is* Thimble Row, not a metaphor for it. It
reuses almost all of the existing warm-lamp/fog/SurfaceGui code as-is (nothing here requires new
rendering techniques), and it produces the single best screenshot in the game for free: fog, neon,
dolls behind glass, one player standing in a lit join square. Most importantly, it fixes the actual
reported bug **by construction, not by careful coordinate-matching**: the workshop's floor and ceiling
are each a *single* part spanning the whole 60×72 footprint, so there is no seam for a player to fall
through, ever — and the Banish Room specifically gets two independent doorways so it can never again
be sealed off by one bad wall segment. That's a structural guarantee, not a promise to be careful.

**Biggest risk / tradeoff, stated plainly:** deleting the walkable corridor is a bigger behavioral
departure than it looks on paper. Today's `WorkshopDoor` mechanic implies players *can* walk into the
workshop when it's unlocked; this proposal removes that path entirely in favor of pure
`ShiftIntro`-triggered teleport, which means `LobbyService`'s current single-`ReadyPad` polling logic
needs to become N-square-aware (manifest field `readyPad: BasePart` becomes `joinSquares: {BasePart}`,
and the `ReadyPad(standing)` remote needs a `squareIndex` added to its payload). Also worth being
upfront about: six join squares read as "six groups can play at once," matching Animal Hospital, but
the current `ShiftManager` is a singleton — only one shift can actually be *active* server-wide at a
time. This proposal assumes that stays true for the beta (extra squares are a queuing/self-assembly UX
win, not true concurrency: a square that finishes its countdown while a shift is already running simply
joins the next `ShiftIntro`, generalizing the existing "standing set merges at the ShiftResult→ShiftIntro
boundary" behavior already described in `docs/INTERFACES.md`). If the team wants genuine concurrent
private shifts later, the fix is mechanical, not a redesign: duplicate the whole Workshop slab at a
second `WORKSHOP_B` offset and run a second `ShiftManager`-equivalent — but that's future scope, not
this proposal. *(See `PACKET_1_LOBBY_SYSTEMS.md` — a different track resolved the true-concurrency
question via `TeleportService:ReserveServer`, which supersedes this "singleton" caveat if that track
is adopted.)*

One more asset-policy reminder that travels with every Toolbox suggestion above (per MASTER.md §3.4):
every inserted free/public asset must be audited before use for (a) hidden scripts/backdoors and
(b) third-party IP that could trigger a DMCA — this applies with extra weight to the "doll model for
the window display" search, since a horror-doll Toolbox search is exactly where a branded lookalike
(no cute Huggy-Wuggy-style character, no recognizable horror-doll IP) is most likely to turn up.

---

## 2. Proposal 2 — "The Hollow Court" (compact vertical/claustrophobic)

# Lobby Hub + Workshop Redesign — "The Hollow Court"
### Angle: Compact vertical/claustrophobic — a tight alley into a wrap-around workshop

## 1. Pitch

**The Hollow Court.** Players spawn at the dead end of a narrow service alley behind the Dollmaker's shop — bins, a rusted fire escape overhead, one bare bulb swinging on a cord, the only warm light in a cold blue corridor. There is nowhere to go but forward. The alley funnels everyone past six join tiles and four kiosk stalls to a single door, which opens into **the Court** — a small, skylit central atrium that every workshop room opens onto directly. Two of those rooms (Ledger and Banish) also connect to *each other*, so the workshop isn't a row of boxes off a hallway, it's a tight loop wrapped around one shared room. Stand in the Court and you can see every doorway in the shift at once; stand almost anywhere in the build and you can hear the other players. The whole thing trades the original's sprawl for pressure: tight going in, small and interconnected once you're inside, nothing more than a few steps from anything else. Tone: cramped, cold, and close — the opposite of lost.

## 2. Room-by-room table

All rooms share **the same floor elevation** (top-of-floor at world Y = 0) and use the codebase's existing `room()` box pattern (floor/ceiling slab + 4 walls with door gaps) — see §5 for the one helper change this layout requires. Sizes are `sizeX × sizeZ`, footprint in world studs; `H` = interior ceiling height.

| Room | Purpose | Approx size (studs) | Connects to | Key props / set-dressing |
|---|---|---|---|---|
| **The Alley** (hub: spawn + join row + kiosk row) | Spawn point; where solo/duo/trio/quad groups form via join squares; shop/classes/journal/invite access | 22 × 74, H 30 (open-air, no ceiling — tall canyon) | Atrium via **Workshop Door** (D1) | Center (0,0,37). 2–3 `SpawnLocation`(s) tag `LobbySpawn` near Z=5; dead-end fence/barrier flavor wall at Z=0 ("NO THROUGH ROAD" sign, reused `surfaceText` pattern); 6 join-square tiles along the west wall; 4 kiosk stalls (Shop, Classes, Journal, Invite) along the east wall; 1 procedural swinging bare bulb (thin "cord" part + sphere + `PointLight`, small `TweenService` swing loop — no asset needed); 2–3 `WindowPane` set high on the canyon walls for moonlight shafts. **Toolbox:** "low poly dumpster" / "overflowing trash bags pack" and "chain link fence low poly" for base clutter (kept off the center walking lane), "rusted fire escape stairs low poly" mounted high overhead as pure backdrop *(audit each per MASTER.md §3.4)* |
| **Atrium / The Court** | Central hub-of-hubs; the "exhale" after the alley; regroup point; every workshop room opens onto it | 24 × 24, H 18, skylight | Alley (D1) · Bench Room (D2) · Storage Alcove (D3) · Ledger Room (D4) · Banish Room (D5) | Center (0,0,86). Glass skylight pane (tag `WindowPane`, face-up) + downward `SpotLight` moonlight shaft as the room's lighting anchor; 1 `GlyphSpawn` floating in the beam; thin ring of low decor (dead vines/potted husks) kept below sightline height so all 5 doorways stay visible from the center. **Toolbox:** "broken skylight glass window low poly" or "victorian greenhouse glass roof" for the skylight frame, "hanging dead vine low poly" for the rim *(audit per §3.4)* |
| **Bench Room** (doll care) | 5 doll bench slots, ribbon spool | 22 × 24, H 14 | Atrium (D2, open archway — always passable) | Center (-23,0,86). Workbench prop along the far (west) wall; 5 `BenchSlot` markers spaced ≥5.5 studs apart; `RibbonSpool` + prompt at one end; 2 `Lamp` fixtures; 2 `GlyphSpawn` (one floor-corner, one shelf-height). **Toolbox:** small "sewing supplies / spool rack" clutter on the bench ends only *(audit per §3.4)* |
| **Storage Alcove** | Decorative dread — spare doll parts, shelving | 24 × 20, H 14 | Atrium (D3, hinged `HauntDoor`) | Center (0,0,108). 2–3 shelf units with spare "DecorDoll" silhouettes (existing procedural pattern); 2 `GlyphSpawn` (shelf-height + floor). **Toolbox:** "low poly Victorian shelf" (matches the team's own example), "antique porcelain doll head prop" for shelf clutter — generic/unbranded only *(audit per §3.4)*. *Stretch goal, explicitly deferred from this proposal's core: a 3-step stair to a small shelf-loft for one extra glyph spawn — cut from the base build so no second floor elevation is introduced (see §6, this is exactly the bug class we're fixing).* |
| **Ledger Room** | Ledger desk, Spirit Compass rack | 20 × 12, H 14 | Atrium (D4, hinged `HauntDoor`) · **Banish Room directly (D6)** | Center (22,0,80). `LedgerDesk` + book prop + prompt (existing procedural pattern); `DetectorRack` beside it; 1 `GlyphSpawn`. **Toolbox:** extra "old leather bound book" stack beside the functional desk (decorative only) *(audit per §3.4)* |
| **Banish Room** | The Banish Box — where the game is won | 20 × 12, H 14 | Atrium (D5, **open archway, no door leaf, ever**) · Ledger Room directly (D6) | Center (22,0,92). `BanishBox` model + deposit prompt (existing procedural pattern); 2 `GlyphSpawn`. **Toolbox:** "candle prop pack low poly" ringed around the box for ritual staging *(audit per §3.4)*. **This room has two independent entrances (D5 + D6) and zero physical door leaves on either — it structurally cannot be sealed, which is the exact failure this redesign exists to fix.** |

Total built footprint: roughly **66 studs (X) × 118 studs (Z)** — versus the original's 240+ stud spawn-to-Banish sprawl.

## 3. Top-down sketch

North (+Z) is "deeper into the building." Not to scale — see the doorway table below the sketch for exact stud numbers.

```
                                    N (+Z)
                                     ▲
                          +--------------------+
                          |  STORAGE ALCOVE    |   center (0,0,108)  24x20 H14
                          |  shelves, decor     |   [G][G]
                          +---------+----------+
                                    | D3 (hinged HauntDoor)
                                    | 10w x H14, world center (0,_,98)
+----------------------+  +--------+--------+  +----------------------+
|     BENCH ROOM        |  |                 |  |     LEDGER ROOM       |
|  center (-23,0,86)    |  |   ATRIUM /      |  |  center (22,0,80)     |
|  22x24 H14             |  |   THE COURT     |  |  20x12 H14             |
|  [S1][S2][S3][S4][S5]  |  |  24x24 H18      |  |  [LedgerDesk][Rack]    |
|  [RibbonSpool]          |  |  skylight, [G] |  |  [G]                   |
|  [Lamp]        [Lamp]   D2 center (0,0,86) D4  +-----------+-----------+
+----------------------+  |                 |  ← 8w H14, (12,_,80)  | D6
      D2: open archway →  |                 |                        | 6w H14
      10w H14, (-12,_,86) |                 |                        | (22,_,86)
                          +--------+--------+  +-----------+-----------+
                                    | D5 → open archway, NEVER a door |
                                    | 8w x H14, world center (12,_,92)|
                                    |                        | BANISH ROOM |
                          +---------+----------+             | center (22,0,92)
                          |    WORKSHOP DOOR   |             | 20x12 H14
                          |   world (0,_,74)    |             | [BanishBox] ★ WIN ★
                          |   10w x H18         |             | [G][G]
                          +---------+----------+             +-----------------+
                                    | D1
     +------------------------------+------------------------------+
     |                    THE ALLEY (hub)                           |
     |   west wall, join squares:   [J1][J2][J3][J4][J5][J6]        |
     |   Z = 20, 27, 34, 41, 48, 55  (X ≈ -8, 5x5 tiles)             |
     |                                                                |
     |   east wall, kiosks:  [SHOP][CLASSES][JOURNAL][INVITE]        |
     |   Z = 24, 34, 44, 54   (X ≈ +8, stall alcoves)                 |
     |                                                                |
     |         (fire escape overhead, bare bulb ~Z=40)               |
     |                                                                |
     |   spawn point(s) ≈ (0,0,5) / (-4,0,5) / (4,0,5)               |
     +------------------------------+------------------------------+
                                    |
                                 S (Z=0, spawn end)
```

**Doorway table** (every entry must exist as a matching gap cut into *both* walls it joins — this is
the exact seam that broke last time):

| ID | Connects | World position (center) | Width | Height | Door type |
|---|---|---|---|---|---|
| D1 | Alley ↔ Atrium | (0, _, 74) | 10 | 18 | open archway |
| D2 | Atrium ↔ Bench Room | (-12, _, 86) | 10 | 14 | open archway (always passable — care happens here continuously) |
| D3 | Atrium ↔ Storage Alcove | (0, _, 98) | 10 | 14 | hinged `HauntDoor` |
| D4 | Atrium ↔ Ledger Room | (12, _, 80) | 8 | 14 | hinged `HauntDoor` |
| D5 | Atrium ↔ Banish Room | (12, _, 92) | 8 | 14 | **open archway, no leaf, ever** |
| D6 | Ledger Room ↔ Banish Room | (22, _, 86) | 6 | 14 | open archway (redundant second entrance to Banish) |

Straight-line spawn → Banish Box ≈ 91 studs ≈ **5.7 seconds** at default WalkSpeed 16. A solo player touching every room (spawn → Bench → Atrium → Storage → Atrium → Ledger → Banish → back) is comfortably a **25–30 second** loop.

## 4. Lighting / atmosphere

The Alley is cold and blue (tight fog, `FogEnd` ≈ 85–90, so the door and far kiosks aren't visible from spawn), with the single bare bulb and the kiosk stall lamps as the *only* warm light sources — they read as literal breadcrumbs pulling players down the tight space, and the join tiles' idle-grey → lit-yellow glow doubles as wayfinding in the gloom. Stepping through the Workshop Door into the Court is the tonal release: a cool moonlight shaft from the skylight against warm practical lamps framing each of the five doorways, so every exit reads clearly even glanced at quickly on a phone screen. The four spoke rooms keep the existing warm/dim `WOOD`/`ACCENT` workshop palette so nothing feels like a different game; the existing per-client Presence-tier lighting lerp (warm → sick green) layers on top of this base exactly as it does today.

## 5. Structural implementation notes for MapBuilder

**Floor rule (the actual fix):** every `room()` call in this layout uses `center.Y = 0` — one shared floor plane, no exceptions, no elevation changes anywhere in the base build (the deferred Storage loft in §2 is the only place that would need a second elevation, and it's cut from this proposal precisely to avoid reintroducing the bug class that broke the last build).

**Doorway-pairing rule:** `MapBuilder.luau`'s current `room()`/`wall()` helper only supports one *centered*, hardcoded-8-stud gap per side (`gaps: {[string]: boolean}`). This layout needs (a) doorways of different widths (6/8/10), (b) doorways *off-center* on a wall (D4/D5 on the Atrium's east wall aren't centered on the full 24-stud wall), and (c) two independent doorways on the same wall (Atrium's east wall carries both D4 and D5). Recommend generalizing the gap spec before building this:

```lua
-- CURRENT: room(center, sizeX, sizeZ, height, { N = true, E = true }) -- one 8-wide centered gap, or none
-- PROPOSED: each side takes a LIST of gap specs (possibly empty), so a wall can carry
-- zero, one, or several doorways, each with its own width/offset/height.
type DoorGap = { width: number, offset: number?, height: number? } -- offset in studs from the wall's own center; height caps the opening below the room's own ceiling
room(center, sizeX, sizeZ, height, {
	E = {
		{ width = 8, offset = -6, height = 14 }, -- D4, toward the Alley/south side
		{ width = 8, offset = 6, height = 14 },  -- D5, toward the north side
	},
})
```
Whichever side of a shared wall is *taller* (e.g. Atrium H18 meeting a spoke room's H14) gets the doorway capped at the shorter height, with a solid lintel filling the remainder above — the existing `lintel` box in `wall()` already does roughly this for a single centered gap; it just needs to accept an explicit height per gap now.

**Cross-check requirement, called out explicitly because it's the exact class of bug being fixed:** for every ID in the doorway table above, confirm *both* rooms' walls at that shared plane actually carry a gap at the same width/offset — a mismatch (or one side simply omitting the gap, as the original Bench↔Banish wall did) reproduces the original sealed-Banish-room bug. This is a single-purpose QA pass worth doing by hand in Studio before playtesting: walk through all six doorways, both directions.

**New CollectionService tags this proposal needs** (flagging per R4 rather than assuming): `JoinSquare` (×6), `ShopKiosk`, `ClassesKiosk`, `JournalKiosk`, `InviteKiosk`. The Atrium's skylight can reuse the existing `WindowPane` tag (manifest already carries a `windowPanes: {BasePart}` array; a face-up pane fits without a contract change).

**Manifest diff:** `MapBuilder.build()`'s returned manifest currently has a single `readyPad: BasePart`. This layout replaces that with `joinSquares: {BasePart}` (6 entries) plus `shopKiosk`, `classesKiosk`, `journalKiosk`, `inviteKiosk: BasePart` fields. That's a real change to the contract in `docs/INTERFACES.md` §MapBuilder and to `LobbyService`'s ready-pad polling logic. *(See `PACKET_1_LOBBY_SYSTEMS.md`'s join-square track, which independently specs the service side of this exact manifest change.)*

**Explicitly out of scope here, flagged for the rest of the packet:** the physical join-square parts and kiosk stalls are ready to be wired up, but the *systems* behind them — per-square player roster + 30s countdown + 4-player cap, private per-group shift instancing, Shop/Classes coin economy, Journal quest list — need new remotes and new `Config.Lobby.*` keys (`JoinSquareCount = 6`, `JoinSquareCap = 4`, `JoinCountdownSeconds = 30` — added alongside, not replacing, the existing `ReadyCountdownSeconds`/`BillboardMaxDistance` per R3's never-rename-existing-keys rule). This section only claims the map geometry and tags; the economy/concurrency logic belongs to `PACKET_1_LOBBY_SYSTEMS.md`.

## 6. Why this angle, and its honest biggest risk

This design wins on the brief's own terms: the atrium-as-hub topology makes the whole shift's geography readable from one standing point (five doorways visible at once), the Ledger↔Banish loop delivers "wraps tightly around a central atrium" literally rather than just spatially, every doorway is either an always-open archway or a hinged door with a *second* independent entrance behind it (Banish specifically can never again be sealed by one wrong wall), and the tight-alley-then-release pacing beat gives the "compact vertical/claustrophobic" angle real emotional shape instead of just small dimensions. It also stays close to the existing `room()`/`lamp()`/`prompt()` code patterns, so the implementation lift is a helper generalization plus new coordinates, not a rewrite.

The honest biggest risk is that the brief's join-square mechanic implies **4–6 concurrent, private shift instances running off one shared hub** — and that's a server-architecture change (either N parallel `ShiftManager` instances, or `TeleportService` reserved servers), not a map change. This proposal deliberately makes that cheap to build on top of — the Workshop is small and fully self-contained specifically so `MapBuilder` could stamp out N copies of it, or a private-server teleport could target a matching copy — but it does not solve concurrency itself. *(Resolved in `PACKET_1_LOBBY_SYSTEMS.md` via `TeleportService:ReserveServer` — see that packet's §2.)*

---

## 3. Proposal 3 — "Hollow Square" (wide theatrical town square)

# Lobby Hub + Workshop Redesign — Proposal: "Hollow Square"

*One of three independent competing proposals for the Lobby Hub + Workshop map. Grounded in the
current `src/server/Services/MapBuilder.luau`, `docs/INTERFACES.md`, and `src/shared/Config.luau` as
they exist today.*

## 1. Pitch

**Hollow Square** is a dead Victorian town square at midnight, built around the ruins of a fountain, with the Dollmaker's shop looming as the one lit, occupied building on the block. Two of its boarded-up neighbors have been repurposed as the physical Classes shopfront and a pinned-up Journal noticeboard, so the left-side HUD kiosks read as *places*, not menu buttons. Players arrive down a narrow dead-end alley, pass a rusted postbox (the Invite kiosk — "send for a friend" made literal), and step into the open plaza where the join squares fan out around the fountain like the last five working streetlamps in a town that lost the rest. Tone: quiet-before-the-storm, picture-postcard-creepy — the kind of establishing shot that reads as "wrong" in a screenshot before a single doll shows up. Once the 30-second countdown fires, players teleport (not walk) into a **compact, single-slab Workshop** — one continuous floor/ceiling footprint shaped like a plus sign, so the doorway-gap and sealed-room bugs that broke the last build are structurally impossible to reproduce, not just carefully avoided.

## 2. Room-by-room table

All coordinates are **local to two separate origins** — `HUB` (world origin, e.g. `(0,0,0)`) and `WS` (Workshop origin, placed far away, e.g. `(0,0,600)`, purely so the two zones never visually or physically overlap; since `Config` keeps `StreamingEnabled=false` per R8, the distance costs nothing at runtime). Players never walk between them — `ShiftManager.ShiftIntro` already does a `PivotTo` teleport per `docs/INTERFACES.md`, so this design leans on that instead of rebuilding the old 240-stud corridor.

### Hub ("Hollow Square")

| Room / Zone | Purpose | Approx. size (studs) | Connects to | Key props / set-dressing |
|---|---|---|---|---|
| **Entry Alley** | Dead-end back-street; player spawn | 10 (X) × 24 (Z), `HUB + (0,0,-42)` center, spans Z −54..−30 | Opens north into the Plaza at Z=−30 | `SpawnLocation` (keep tag `LobbySpawn`) at `HUB+(0,0.5,-50)` facing north; cracked cobblestone, one dim lamp, a leaning "NO ADMITTANCE" sign for flavor |
| **Invite Postbox** | Invite kiosk | 2×2×4 prop | Sits at the Plaza mouth, `HUB+(4,0,-26)` | Rusted red postbox, `ProximityPrompt` "Send for a Friend" → fires Roblox's native invite prompt. New tag: `InviteKiosk` |
| **The Plaza** | Open outdoor hub; holds the join squares + fountain | 70 (X) × 60 (Z), center `HUB+(0,0,0)`, spans X −35..35, Z −30..30 | Alley (south), north frontage buildings, Journal noticeboard | Cobblestone/Slate floor, low iron edge fencing (not full walls — sky stays open), 4 corner `Lamp`-style posts |
| **Fountain & Statue** | Centerpiece landmark; camera anchor; spreads the join squares out attractively | radius ≈9, basin height 2, statue pedestal to height 10, center `HUB+(0,1,14)` | Freestanding in Plaza | Dry cracked basin (Concrete material), a small chipped porcelain-doll statue on top — a quiet visual pun the team can play up or cut |
| **Join Squares (×5)** | The "blue circles" — step in, countdown starts, up to 4 players/square | 7×7 each; arc south of the fountain: `(-24,0.1,-6) (-12,0.1,2) (0,0.1,5) (12,0.1,2) (24,0.1,-6)` (all `HUB`-relative) | Plaza floor | Idle = pale stone-grey `Neon` ring at 0.6 transparency; lit = warm yellow, `Transparency 0`; `BillboardGui` "1/4" counter above each. New tag: `JoinSquare`, named `JoinSquare1..5` |
| **Dollmaker's Shop** | Centerpiece building; **Shop kiosk** (sells Classes) | 26 (X, −13..13) × 16 (Z, 30..46) footprint, height 20 (+ non-collide roof cap to ~26 for skyline), `HUB+(0,·,38)` | Faces Plaza across a small stoop at `HUB+(0,3,29)` | Tallest building on the block, warm window-glow (lit `SurfaceGui`/`PointLight` behind glass), hanging sign; `ProximityPrompt` "Enter the Shop" → Shop/class-purchase UI. New tag: `ShopKiosk` |
| **Classes Shopfront** | Classes kiosk (equip owned loadouts) | 16×12, `HUB+(-28,·,36)` | West of the Shop, same frontage line | Boarded windows (crossed plank parts over a window frame — cheap and procedural), faded "TAILOR" ghost-sign; `ProximityPrompt` "Browse Classes". New tag: `ClassesKiosk` |
| **Apothecary Shopfront** | Pure backdrop dressing — sells nothing | 16×12, `HUB+(28,·,36)` | East of the Shop, mirrors Classes for a balanced skyline | Boarded windows, cracked apothecary jars painted onto a `SurfaceGui`, no prompt at all |
| **Journal Noticeboard** | Journal kiosk (quest/checklist) | 4×0.5×7 post-and-board | Freestanding, `HUB+(18,0,6)`, east side of Plaza near the walking path | Cork-board look via `SurfaceGui` with pinned-paper `Frame`s; `ProximityPrompt` "Read the Journal". New tag: `JournalKiosk` |
| **Chalkboard** *(kept from current build)* | Teaches the loop | 18×9, mounted on the Entry Alley's north-facing wall so it's read on the walk in | Alley → Plaza threshold | Same house-rules text as today's `Chalkboard` (tag kept) |
| **Leaderboard Board** *(kept)* | Top-8 best-shift display | 12×9, mounted on the Dollmaker's Shop facade beside the stoop | On Shop building | Tag `LeaderboardBoard` kept, just relocated |

### Workshop (single teleport destination — one continuous slab, four "wings")

| Room / Zone | Purpose | Approx. size (studs) | Connects to | Key props / set-dressing |
|---|---|---|---|---|
| **Foyer** | Central junction; teleport landing point | 16 (X −8..8) × 18 (Z −9..9), `WS+(0,·,0)` | Open (wall-less) archways to all three wings | `WorkshopSpawn` (kept, `Enabled=false` until `LobbyService.setShiftSpawnActive`) at `WS+(0,0.5,0)`; repurposed "Shift N in progress" plaque on the Foyer's one true wall (south, Z=9) — now decorative only |
| **Bench Wing** | Doll care | 26 (X −34..−8) × 18 (Z −9..9) | Open archway east to Foyer (X=−8 line, 18 studs wide) | Workbench along north wall (Z≈−8), 5 `BenchSlot`s at `WS+(-30,4.6,-6)` through `WS+(-10,4.6,-6)`, `RibbonSpool` + prompt at `WS+(-10,4.8,-6)`; shelf decor (former "Storage Alcove") built into the west end wall instead of a separate room — spare-doll silhouettes on 2 shelves; one `WindowPane` on the west outer wall for moonlight |
| **Ledger Nook** | Spirit matching | 16 (X −8..8) × 18 (Z −27..−9) | Open archway south to Foyer (Z=−9 line, 16 studs wide) | `LedgerDesk` + book prompt at `WS+(0,2,-20)`, `DetectorRack` beside it at `WS+(6,3,-20)` |
| **Banish Wing** | Where the game is won | 26 (X 8..34) × 18 (Z −9..9) | Open archway west to Foyer (X=8 line, 18 studs wide) | `BanishBox` model at `WS+(26,2.2,0)`, deposit prompt on it, plenty of open floor for a 4-player confirm huddle; one `WindowPane` on the east outer wall |
| **Closet nooks (×2)** | Anchors for `HauntService`'s `DoorCreakSlam` — kept off the main floor deliberately | ~3×0.5×4 insets, one in Bench Wing's north wall, one in Ledger Nook's west wall | Set into outer walls only, never a walkway | Two small hinged `HauntDoor` props — this is the direct fix for the old bug: last time a *load-bearing* doorway got plugged solid; these doors are decorative closets that were never load-bearing to begin with |
| **Glyph spawns (×9)** | Spirit Compass hunt targets | scattered 3 per wing, e.g. Bench: `(-30,5,4) (-14,2,-6) (-24,7,6)`; Ledger: `(-4,2,-14) (5,6,-22) (0,2,-25)`; Banish: `(28,2,-6) (14,6,5) (30,7,2)` (all `WS`-relative) | — | Invisible `GlyphSpawn`-tagged markers, unchanged from current pattern |

Full Workshop bounding box: **68 studs (X) × 36 studs (Z)** — noticeably smaller than the old bench+storage+ledger+hallway+banish spread, and with zero internal walls to misalign.

## 3. Top-down sketch

### Hub — "Hollow Square"

```
                                   +Z  (north, toward the Shop)
                                    ^
      ┌────────────┐      ┌──────────────────┐      ┌────────────┐
      │ APOTHECARY │      │  DOLLMAKER'S SHOP │      │  CLASSES   │
      │  (decor)   │      │   == Shop kiosk == │      │ shopfront  │
      │ X 20..36   │      │  X -13..13, Z30..46│      │ X -36..-20 │
      │ Z 30..42   │      └─────────┬──────────┘      │ Z 30..42   │
      └────────────┘             stoop/prompt          └────────────┘
                                 (0,3,29)
                          ╭──────────────────────╮
                          │  dry fountain+statue  │
                          │     (0,1,14) r≈9      │
                          ╰──────────────────────╯
        [Sq1]        [Sq2]        [Sq3]        [Sq4]        [Sq5]
      (-24,-6)       (-12,2)       (0,5)       (12,2)       (24,-6)
             join squares — idle grey, yellow-lit when occupied

     [JOURNAL]                                                
    board (18,0,6)  ---------------- OPEN PLAZA ----------------
                                  X -35..35, Z -30..30
                              [POSTBOX] Invite kiosk
                                  (4,0,-26)
                          ┌──────────────────────┐
                          │      ENTRY ALLEY      │
                          │  10 wide, Z -54..-30  │
                          │                       │
                          │    SPAWN (0,0,-50)    │
                          └──────────────────────┘
```

### Workshop — single continuous slab, plus-shaped footprint

```
                    ┌───────────────────────────┐
                    │        LEDGER NOOK         │   Z -27..-9
                    │  LedgerDesk + DetectorRack │   X  -8..8
                    │  + closet HauntDoor #2     │
                    └─────────────┬───────────────┘
                        (open archway, no wall — Z=-9 line)
┌───────────────────────────────┬─┴─┬───────────────────────────────┐
│          BENCH WING           │ F │          BANISH WING           │
│  Workbench + 5 BenchSlots      │ O │  BanishBox + deposit prompt    │
│  + RibbonSpool + shelf decor   │ Y │  open floor for 4p confirm     │
│  + closet HauntDoor #1         │ E │                                │
│  Z -9..9, X -34..-8            │ R │  Z -9..9, X 8..34              │
└───────────────────────────────┴───┴───────────────────────────────┘
   (open archway, X=-8 line)    WorkshopSpawn   (open archway, X=8 line)
                                  (0,0.5,0)
```

Both floor + ceiling for the whole plus-shape are built as **two overlapping full-footprint slabs** before any wall goes up — a horizontal bar (`X -34..34, Z -9..9`) and a vertical bar (`X -8..8, Z -27..9`, which fully swallows the Foyer band so the seam is a guaranteed 18-stud overlap, not a touching edge). Walls are added only on the four wings' *outer* perimeter; the boundaries between wings get **no wall instanced at all** — not a wall-with-a-gap-cut-out (that pattern is exactly what plugged last time's Banish room), just genuinely nothing there. Illustrative pattern for cloud Claude to adapt into `MapBuilder`:

```lua
-- Replaces room() for the Workshop only (the Hub's buildings are outdoor/discrete —
-- no floor-seam risk there, since it's open sky, not sealed rooms).
local function slab(originCf: CFrame, footprint: Vector3, yOffset: number, color: Color3)
	box(originCf * CFrame.new(0, yOffset, 0), footprint, color, Enum.Material.Wood, "Floor")
end

local function workshopShell(WS: Vector3, height: number)
	-- Horizontal arm: Bench Wing + Foyer + Banish Wing
	slab(CFrame.new(WS), Vector3.new(68, 1, 18), -0.5, FLOOR)
	slab(CFrame.new(WS), Vector3.new(68, 1, 18), height + 0.5, WOOD_DARK)
	-- Vertical arm: Ledger Nook — deliberately overlaps the ENTIRE Foyer band (Z -9..9),
	-- not just an edge, so the two slabs share a solid seam.
	slab(CFrame.new(WS - Vector3.new(0, 0, 9)), Vector3.new(16, 1, 36), -0.5, FLOOR)
	slab(CFrame.new(WS - Vector3.new(0, 0, 9)), Vector3.new(16, 1, 36), height + 0.5, WOOD_DARK)
	-- Perimeter walls go on the OUTER edges only, per wing, below. Interior "doorways"
	-- are simply absent walls — never a full wall with a gap subtracted out of it.
end
```

## 4. Structure vs. Decoration

**STRUCTURE (procedural Luau — code-controlled, rebuilt every Rojo sync):** every floor/ceiling slab, every outer wall, the fountain basin, both slabs of the plus-shaped Workshop, all room-defining geometry in the table above, all `ProximityPrompt`-bearing parts, all tagged manifest instances. None of this should ever be a Toolbox mesh — it must stay rebuildable.

**DECORATION (free Creator Store / Toolbox — searched and inserted live by the local-Studio-MCP session, not coded):**
- *"low poly Victorian street lamp"* — swap in for a couple of the Plaza's four corner posts to sell the "dead town" silhouette better than a bare `PointLight` part.
- *"cracked stone fountain"* or *"broken angel statue"* — could directly replace/dress the procedural fountain basin+statue if a good creepy-cute one turns up.
- *"low poly Victorian shelf"* (team's own example) — for the Bench Wing decor shelves and Ledger Nook dressing.
- *"free rigged raven crow model"* (team's own example) — perched on the Shop's roofline or the fountain's edge; cheap, silent "something's off" cue for a screenshot.
- *"vintage mailbox low poly"* — direct upgrade for the Invite postbox prop.
- *"wooden crate barrel prop pack"* — scatter a handful around the Plaza edges and the boarded shopfronts' stoops to kill the "empty baseplate" read cheaply.
- *"creepy porcelain doll mesh"* / *"victorian bisque doll model"* — if the team wants a stronger mascot presence, one or two placed in the Classes/Apothecary shopfront windows (visible through gaps in the boarding) sells "cute-but-wrong" without touching gameplay geometry.

**Compliance reminder (MASTER.md §3.4), repeated here per policy:** every one of the above must be audited before use for (a) hidden scripts/backdoors and (b) third-party/branded IP that could trigger a DMCA, before it goes in the place file. Nothing above is a specific asset ID — these are search terms only.

## 5. Manifest, tag, and Config notes (for whoever wires this into `MapBuilder`/`LobbyService`)

- **Breaking manifest change, flagged loudly:** this design replaces `manifest.readyPad` (single `BasePart`) with `manifest.joinSquares` (`{BasePart}`, 5 entries, tag `JoinSquare`). *(See `PACKET_1_LOBBY_SYSTEMS.md` — a separate track independently specs the service side of exactly this change.)*
- New tags to add to the CollectionService list (R4): `JoinSquare`, `ShopKiosk`, `ClassesKiosk`, `JournalKiosk`, `InviteKiosk`. `HauntDoor`, `WindowPane`, `BenchSlot`, `GlyphSpawn`, `LedgerDesk`, `DetectorRack`, `RibbonSpool`, `BanishBox`, `LobbySpawn`, `WorkshopSpawn`, `Chalkboard`, `LeaderboardBoard` are all **kept as-is**, just relocated.
- **Lamp-tag split, please don't skip this:** `HauntService`'s `LightsOutBeat` toggles every instance under `CollectionService:GetTagged("Lamp")`. If the Plaza's decorative lamp posts also carry the `Lamp` tag, a haunt firing during someone else's active shift would plunge the *entire shared server's Hub* into darkness for players still waiting at the join squares. Recommend the Hub's lamps use a separate, untagged (or `HubLamp`-tagged) light so `manifest.lamps` stays Workshop-only.
- **`WorkshopDoor` is repurposed, not removed.** With entry now via `PivotTo` teleport instead of a walked corridor, there's nothing left to physically block — the tag/manifest field is kept for compatibility but should become a static "Shift N in progress" wall plaque in the Foyer rather than a `CanCollide` slab. Flagging this as an explicit choice this section is making, not assuming away — whoever owns `ShiftManager`/`LobbyService` should confirm they're fine dropping the physical lock in favor of the join-square countdown gating entry instead.
- **New Config keys this design assumes** (proposed, not renaming anything existing): `Config.Lobby.JoinSquareCount = 5`, `Config.Lobby.JoinSquarePlayerCap = 4`, `Config.Lobby.JoinSquareCountdownSeconds = 30`. Existing `Config.Lobby.ReadyCountdownSeconds = 10` is left untouched but is likely now dead code if the join-square system fully replaces the single ready pad — flagging for the team to confirm rather than deleting it myself.
- **Future-proofing note:** the Workshop is built off one clean origin vector (`WS`). If the team later wants each join square to send its group into a truly separate private instance (concurrent shifts), `MapBuilder` can stamp out N copies of the exact same plus-shape by calling the shell builder at `WS + i * offset` — no layout redesign needed, just a loop.

## 6. Lighting / atmosphere

The Plaza runs a touch brighter and less fogged than the Workshop — `Lighting.ClockTime` around midnight, cool blue `Ambient`, but `Atmosphere.Density` kept lower than the interior (roughly half) so mobile players can actually see the fountain-to-shop sightline in one frame; a few warm lamp posts break up the blue without washing out the "postcard-creepy" read. The Workshop keeps the current build's warm/dim wood-and-lamp palette (`WOOD`/`WOOD_DARK`/`WALL`/`FLOOR`/`ACCENT` constants, unchanged) but nudge lamp `Brightness` up slightly from today's values — with four wings sharing one open floor instead of five separate boxed rooms, over-dimming would make the wings blur together on a phone screen.

## 7. Why this angle, and its biggest risk

This angle earns its "theatrical hub" brief by making every left-side HUD action a *place* a player walks past rather than a menu they open blind — the postbox, the boarded Classes front, and the Journal corkboard all sit on the route from spawn to the join squares, so the tutorial-by-osmosis the chalkboard already tries to do gets reinforced by the geometry itself. The fountain-and-statue centerpiece does triple duty: it's the thumbnail-worthy grandeur the brief asked for, it's the thing that naturally spreads five join squares into an attractive arc instead of a flat row, and it's a stable landmark for a mobile 3rd-person camera to frame against. And critically, the Workshop redesign doesn't just re-place the same five rooms more carefully — building it as one continuous floor/ceiling slab with wall-less archways between wings makes the exact failure mode from the first playtest (misaligned room floors, a doorway plugged solid) structurally impossible to reproduce, not just something a future edit could re-break.

The honest biggest risk: three full building facades on the Plaza's north side (Shop + two shopfronts, each with boarded-window crosshatching, a roof cap, and signage) is real part-count and art-direction work for a 2-person no-code team to tune procedurally — it's the single piece of this proposal most likely to look "blocky" without a couple of well-chosen free Toolbox props (lamps, crates, a raven) to soften it, and if the team's Studio-MCP session doesn't get to that decoration pass, the Hub will read as flatter than the sketch promises. A secondary, smaller risk: dropping the walked hub→workshop corridor in favor of a straight `PivotTo` teleport is a real deviation from today's literal walk-through architecture (even though it matches the brief's own "reached only after the 30s countdown/teleport" wording) — it needs an explicit yes from whoever owns `ShiftManager`/`LobbyService`, not a silent assumption.

---

## 4. Judge/synthesis pass — the recommendation

*Grounded directly against the current repo: `docs/INTERFACES.md` (MapBuilder contract), `src/server/Services/MapBuilder.luau` (the actual `room()`/`wall()` helper and today's layout), and `docs/PLAYTEST_REPORT_2026-08-15.md` items A1/A2 (the real bug this redesign exists to fix). All three proposals correctly target that bug class; they differ in how directly their construction technique avoids it.*

**Hub/spawn theme, stated plainly:** the hub should be a dead Victorian town square built around a broken fountain, facing the Dollmaker's one lit shopfront — an open, iconic "postcard-creepy" establishing shot, not a back-alley or a tight corridor.

### 1. Scoring table

| Proposal | Mobile readability | Walk-distance / pacing | Clip-worthiness / thumbnail appeal | Build feasibility (2-person team) | Fit to "spooky-not-scary, kid-friendly" |
|---|---|---|---|---|---|
| **P1 — Thimble Row** (dead-end alley) | **4/5** — one continuous street slab, wide sightlines toward the lit shop, join plaza legible; van + flank walls add some visual clutter on a narrow phone frame | **4/5** — compact ~56-stud spawn→shop walk, teleport-only workshop keeps hub-side pacing tight, no hard numbers given | **4/5** — the fog/neon/dolls-behind-glass shot is genuinely strong, but a back-alley-behind-a-shop is a smaller, more mundane establishing shot than a town square | **3/5** — Bench Room's north wall needs *two* door gaps (to Storage + to Ledger) at once, which today's `room()` helper (single centered 8-stud gap per side) cannot do — and P1 never flags this, unlike P2/P3 | **3/5** — dumpster/delivery-van/chain-link-fence urban-decay aesthetic reads more "liminal creepypasta" than the "cute-but-wrong porcelain doll" kid-friendly brief |
| **P2 — Hollow Court** (claustrophobic atrium) | **5/5** — explicitly designed so all 5 workshop doorways are visible from one standing point in the atrium; smallest, most legible footprint of the three | **5/5** — the only proposal with hard numbers (≈91 studs / 5.7s spawn→Banish straight-line, 25–30s full loop) and the smallest total footprint (66×118 studs) | **3/5** — the skylight-atrium beat is a nice tonal release, but a tight alley into a boxy atrium has no big iconic landmark, so it's the weakest "thumbnail" of the three | **3/5** — honestly flags that it needs a real generalization of `room()`/`wall()` (offset, multi-width, multiple gaps per wall) and ships a concrete `DoorGap` type for it — most code-touching option, but the most self-aware about the cost | **3/5** — cold, tight, a single swinging bare bulb — this is the proposal most likely to read as genuinely tense/scary rather than spooky-cute for a kid audience |
| **P3 — Hollow Square** (town square + fountain) | **4/5** — open plaza with a strong central landmark (fountain) anchors camera framing well; the three north-side building facades risk looking "blocky" without a decoration pass (flagged by the proposal itself) | **3/5** — largest hub footprint of the three (70×60 plaza + 24-long alley), no hard walk-time numbers given, likely the slowest hub traversal of the three | **5/5** — fountain + statue + three-building skyline is the clearest single "screenshot" composition, explicitly built for a picture-postcard establishing shot | **5/5** — the Workshop is a plus-shaped footprint with **zero interior walls** (open archways = missing wall segments, not gaps cut into walls), which sidesteps the exact gap-matching bug class (playtest A1/A2) entirely rather than carefully avoiding it; Hub buildings are freestanding facades, not nested rooms | **5/5** — "picture-postcard-creepy," a chipped porcelain-doll statue as a quiet visual pun, no claustrophobia — the best match for spooky-not-scary and the doll-shop aesthetic |

### 2. Final recommendation

**Winner: Proposal 3, "Hollow Square," as the base — synthesized with three concrete grafts from the other two.** P3 wins outright on tone fit and clip-worthiness (the two axes closest to the team's own stated brief — "thumbnail-worthy," "spooky-not-scary, kid-friendly"), and it wins build feasibility for a structural reason that matters more than any aesthetic preference: its Workshop is built from two overlapping full-footprint slabs with genuinely absent interior walls, which makes the *exact* bug reported in `docs/PLAYTEST_REPORT_2026-08-15.md` (A1: sealed Banish room via a solid "doorway connector" plug; A2: void gaps where adjacent room floors don't overlap) structurally impossible to reproduce — not just carefully avoided, the way P1 and P2 both still avoid it by careful gap-matching. P2 is the strongest on raw pacing/legibility numbers and Thimble Row's urban aesthetic is well-executed, but neither offsets P3's advantage on the axis that actually broke the last build.

Grafts onto the P3 base, named explicitly:

1. **From Proposal 1 — the two-tier lamp technique.** P1's Plaza/Alley uses one flickering "hero" lamp for atmosphere plus one steady, non-flickering lamp purely for legibility near player-critical areas. P3's own lighting section doesn't make this distinction. Graft it onto Hollow Square's Plaza: keep the four corner lamp posts steady/non-flickering (they're wayfinding for the join-square arc), and reserve any flicker behavior for the Entry Alley lamp only, so a `LightsOutBeat` haunt firing mid-countdown never makes the join squares unreadable on a phone screen.

2. **From Proposal 1 — the lit-shop-window technique.** P1 specifies the exact construction: glass pane + interior `PointLight` + 2–3 static doll-silhouette props visible behind glass. P3's decoration list mentions a doll mesh "in the Classes/Apothecary shopfront windows" but doesn't specify how the window itself should be lit. Graft P1's exact technique onto all three of Hollow Square's north-side facades (Shop, Classes, Apothecary) — it's cheap, reuses the existing `WindowPane` tag pattern already in `MapBuilder.luau`'s Corridor segment, and is the single best contributor to the "wrong sky, all the light I need is coming from that shop" screenshot the team wants.

3. **From Proposal 2 — explicit doorway/gap discipline, applied where P3 still needs it.** P3's Workshop needs no gap-matching QA (there are no interior walls to mismatch). But P3's **Hub facades** (Shop entrance stoop, boarded Classes/Apothecary window cutouts, postbox alcove) *do* cut openings into solid walls, and today's `room()` helper only supports one centered 8-stud gap per side — the same limitation P2 diagnosed and fixed with its `DoorGap` type. Graft P2's discipline, not its atrium layout: use an explicit, named gap list for every Hub facade opening (window cutout width/offset, door width/offset), and run P2's "confirm both sides of every shared plane carry a matching gap" QA pass specifically on the Hub facades before playtesting — this is exactly where the playtest-report bug class could reappear in the synthesized design, since it's the one place this design still has walls-with-gaps rather than walls-with-nothing.

Everything else in the "ready to build" section below is P3's own design, restated standalone.

### 3. Ready to build — final spec

*Two separate origins, exactly as P3 defined: `HUB = Vector3.new(0,0,0)` (world origin) and `WS = Vector3.new(0,0,600)` (Workshop, placed far away purely so the two zones never overlap — costs nothing at runtime since `Config.StreamingEnabled` stays `false` per R8). Players never walk between them: `ShiftManager`'s `ShiftIntro` state already does a `PivotTo` teleport to `manifest.workshopSpawn` per `docs/INTERFACES.md` §ShiftManager, so this design relies on that instead of rebuilding the ~240-stud corridor that exists in the current `MapBuilder.luau` (`Corridor` segment, lines 232–258) — that segment is deleted entirely by this redesign.*

#### 3.1 Hub — "Hollow Square"

| Room / Zone | Purpose | Approx. size (studs) | Connects to | Key props / set-dressing |
|---|---|---|---|---|
| **Entry Alley** | Dead-end back-street; player spawn | 10 (X) × 24 (Z), `HUB+(0,0,-42)` center, Z −54..−30 | Opens north into the Plaza at Z=−30 | `SpawnLocation` (tag `LobbySpawn`) at `HUB+(0,0.5,-50)` facing north; cracked cobblestone; **one flickering lamp only** (graft #1 — flicker stays confined to the alley, never the Plaza); leaning "NO ADMITTANCE" sign |
| **Invite Postbox** | Invite kiosk | 2×2×4 prop | Plaza mouth, `HUB+(4,0,-26)` | Rusted red postbox, `ProximityPrompt` "Send for a Friend" → native invite prompt. New tag: `InviteKiosk`. **Toolbox search: "vintage mailbox low poly"** *(audit per §3.2 below)* |
| **The Plaza** | Open outdoor hub; join squares + fountain | 70 (X) × 60 (Z), center `HUB+(0,0,0)`, X −35..35, Z −30..30 | Alley (south) · north frontage buildings · Journal noticeboard | Cobblestone/Slate floor, low iron edge fencing (not full walls — sky stays open); **four corner lamp posts, all steady/non-flickering** (graft #1) |
| **Fountain & Statue** | Centerpiece landmark, camera anchor, spreads the join squares into an arc | radius ≈9, basin height 2, statue to height 10, center `HUB+(0,1,14)` | Freestanding in Plaza | Dry cracked basin (Concrete); small chipped porcelain-doll statue on top (whimsical, not gorey). **Toolbox search: "cracked stone fountain" / "broken angel statue"** *(audit per §3.2)* |
| **Join Squares (×5)** | Step in, countdown starts, up to 4 players/square | 7×7 each; arc south of fountain: `(-24,0.1,-6) (-12,0.1,2) (0,0.1,5) (12,0.1,2) (24,0.1,-6)` (`HUB`-relative) | Plaza floor | Idle = pale stone-grey `Neon` ring, 0.6 transparency; lit = warm yellow, 0 transparency; `BillboardGui` "1/4" counter above each. New tag: `JoinSquare`, named `JoinSquare1..5` |
| **Dollmaker's Shop** | Centerpiece building; **Shop kiosk** | 26 (X −13..13) × 16 (Z 30..46), height 20 (+ non-collide roof cap ~26), `HUB+(0,·,38)` | Faces Plaza across a stoop at `HUB+(0,3,29)` | Tallest building on the block; **lit window technique (graft #2): glass pane (tag `WindowPane`) + interior `PointLight` + 2–3 static doll-silhouette props behind the glass**, on both flanking windows; hanging sign; `ProximityPrompt` "Enter the Shop" → Shop UI. New tag: `ShopKiosk`. **Toolbox search: "porcelain doll mannequin" / "creepy doll model, free"** for the window silhouettes *(audit per §3.2 — no branded/recognizable horror-doll lookalikes)* |
| **Classes Shopfront** | Classes kiosk | 16×12, `HUB+(-28,·,36)` | West of the Shop, same frontage line | Boarded windows (crossed plank parts over a frame — procedural, cheap); faded "TAILOR" ghost-sign; **same lit-window technique (graft #2)** through a gap in the boarding; `ProximityPrompt` "Browse Classes". New tag: `ClassesKiosk` |
| **Apothecary Shopfront** | Pure backdrop dressing | 16×12, `HUB+(28,·,36)` | East of the Shop, mirrors Classes | Boarded windows, cracked-jar `SurfaceGui`, no prompt. Same lit-window treatment optional here purely for symmetry |
| **Journal Noticeboard** | Journal kiosk | 4×0.5×7 post-and-board | Freestanding, `HUB+(18,0,6)` | Cork-board `SurfaceGui` with pinned-paper `Frame`s; `ProximityPrompt` "Read the Journal". New tag: `JournalKiosk` |
| **Chalkboard** *(kept)* | Teaches the loop | 18×9, on the Entry Alley's north-facing wall (read on the walk in) | Alley → Plaza threshold | Same house-rules text as today's `Chalkboard` (tag kept) |
| **Leaderboard Board** *(kept)* | Top-8 best-shift display | 12×9, on the Shop facade beside the stoop | On Shop building | Tag `LeaderboardBoard` kept, relocated |

**Hub facade gap discipline (graft #3 — do this by hand in Studio before playtesting):** every window cutout, door stoop, and postbox alcove above is an opening cut into an otherwise-solid wall. Today's `room()` helper (`MapBuilder.luau` lines 51–82) only supports one centered 8-stud gap per side — it cannot express an off-center window cutout next to a door. Build these facade walls with an explicit, named list of gaps (width + offset + height per opening, not a single centered constant), and for every opening, walk through it and confirm the opening exists and is walkable/see-through from both sides before calling the Hub done. This is exactly the bug class from `docs/PLAYTEST_REPORT_2026-08-15.md` A1/A2 (solid plug where a doorway should be) — it will not happen in the Workshop (see §3.2, which has no interior walls at all), but it can still happen here.

#### 3.2 Workshop — single continuous slab, plus-shaped footprint

| Room / Zone | Purpose | Approx. size (studs) | Connects to | Key props / set-dressing |
|---|---|---|---|---|
| **Foyer** | Central junction; teleport landing point | 16 (X −8..8) × 18 (Z −9..9), `WS+(0,·,0)` | Open (wall-less) archways to all three wings | `WorkshopSpawn` (tag kept, `Enabled=false` until `LobbyService.setShiftSpawnActive`) at `WS+(0,0.5,0)`; repurposed "Shift N in progress" plaque on the Foyer's one true wall (south, Z=9) — decorative only now, since entry is teleport-gated, not door-locked |
| **Bench Wing** | Doll care | 26 (X −34..−8) × 18 (Z −9..9) | Open archway east to Foyer (X=−8 line, 18 studs wide) | Workbench along north wall (Z≈−8); 5 `BenchSlot`s at `WS+(-30,4.6,-6)` .. `WS+(-10,4.6,-6)`; `RibbonSpool` + prompt at `WS+(-10,4.8,-6)`; shelf decor (spare-doll silhouettes, reuse existing `DecorDoll` pattern) built into the west end wall; one `WindowPane` on the west outer wall. **Toolbox search: "sewing / dollmaker tool set prop pack"** for bench clutter *(audit per below)* |
| **Ledger Nook** | Spirit matching | 16 (X −8..8) × 18 (Z −27..−9) | Open archway south to Foyer (Z=−9 line, 16 studs wide) | `LedgerDesk` + book prompt at `WS+(0,2,-20)`; `DetectorRack` beside it at `WS+(6,3,-20)` |
| **Banish Wing** | Win condition room | 26 (X 8..34) × 18 (Z −9..9) | Open archway west to Foyer (X=8 line, 18 studs wide) | `BanishBox` model at `WS+(26,2.2,0)` + deposit prompt; open floor for a 4-player confirm huddle; one `WindowPane` on the east outer wall |
| **Closet nooks (×2)** | Anchors for `HauntService`'s `DoorCreakSlam` | ~3×0.5×4 insets, one in Bench Wing's north wall, one in Ledger Nook's west wall | Set into outer walls only, never a walkway | Two small hinged `HauntDoor` props — these are decorative closets that were never load-bearing, so they can never reproduce the A1 sealed-room bug |
| **Glyph spawns (×9)** | Spirit Compass hunt targets | 3 per wing, e.g. Bench: `(-30,5,4) (-14,2,-6) (-24,7,6)`; Ledger: `(-4,2,-14) (5,6,-22) (0,2,-25)`; Banish: `(28,2,-6) (14,6,5) (30,7,2)` (`WS`-relative) | — | Invisible `GlyphSpawn`-tagged markers, unchanged from current pattern; meets the "≥8 markers spread across all workshop rooms" contract line in `docs/INTERFACES.md` §MapBuilder |

Full Workshop bounding box: **68 × 36 studs**.

**The actual A1/A2 fix, stated as code for whoever implements this in `MapBuilder.luau`:**

```lua
-- Replaces room() for the Workshop only. The Hub's buildings are freestanding facades
-- (no floor-seam risk there — see §3.1's separate gap-discipline note instead).
local function slab(originCf: CFrame, footprint: Vector3, yOffset: number, color: Color3)
    box(originCf * CFrame.new(0, yOffset, 0), footprint, color, Enum.Material.Wood, "Floor")
end

local function workshopShell(WS: Vector3, height: number)
    -- Horizontal arm: Bench Wing + Foyer + Banish Wing
    slab(CFrame.new(WS), Vector3.new(68, 1, 18), -0.5, FLOOR)
    slab(CFrame.new(WS), Vector3.new(68, 1, 18), height + 0.5, WOOD_DARK)
    -- Vertical arm: Ledger Nook — deliberately overlaps the ENTIRE Foyer band (Z -9..9),
    -- not just an edge, so the two slabs share a solid seam, not a touching one.
    slab(CFrame.new(WS - Vector3.new(0, 0, 9)), Vector3.new(16, 1, 36), -0.5, FLOOR)
    slab(CFrame.new(WS - Vector3.new(0, 0, 9)), Vector3.new(16, 1, 36), height + 0.5, WOOD_DARK)
    -- Perimeter walls go on the OUTER edges of each wing only. The boundaries between
    -- wings get NO wall instanced at all — not a wall-with-a-gap (that pattern is what
    -- produced the A1 sealed-Banish-room bug), just genuinely nothing there.
end
```

Build order matters: both slabs (all four `slab()` calls) must exist **before** any wing's perimeter walls are added, and the vertical arm's Z-range (−27..9) must be checked to fully contain the Foyer's own Z-range (−9..9) — an 18-stud overlap, not an edge-touch. This is the one place a build-order mistake could silently reproduce the A2 void-gap bug even in this design.

#### 3.3 Top-down sketches

**Hub:**
```
                                   +Z  (north, toward the Shop)
                                    ^
      ┌────────────┐      ┌──────────────────┐      ┌────────────┐
      │ APOTHECARY │      │  DOLLMAKER'S SHOP │      │  CLASSES   │
      │  (decor)   │      │   == Shop kiosk == │      │ shopfront  │
      │ X 20..36   │      │  X -13..13, Z30..46│      │ X -36..-20 │
      │ Z 30..42   │      │  lit windows (g#2)  │      │ Z 30..42   │
      └────────────┘      └─────────┬──────────┘      └────────────┘
                                 stoop/prompt          lit windows (g#2)
                                 (0,3,29)
                          ╭──────────────────────╮
                          │  dry fountain+statue  │
                          │     (0,1,14) r≈9      │
                          ╰──────────────────────╯
        [Sq1]        [Sq2]        [Sq3]        [Sq4]        [Sq5]
      (-24,-6)       (-12,2)       (0,5)       (12,2)       (24,-6)
             join squares — idle grey, yellow-lit when occupied
       ● steady corner lamps (graft #1 — never flicker)

     [JOURNAL]
    board (18,0,6)  ---------------- OPEN PLAZA ----------------
                                  X -35..35, Z -30..30
                              [POSTBOX] Invite kiosk
                                  (4,0,-26)
                          ┌──────────────────────┐
                          │      ENTRY ALLEY      │
                          │  10 wide, Z -54..-30  │
                          │   ◑ flicker lamp only  │
                          │    SPAWN (0,0,-50)    │
                          └──────────────────────┘
```

**Workshop:**
```
                    ┌───────────────────────────┐
                    │        LEDGER NOOK         │   Z -27..-9
                    │  LedgerDesk + DetectorRack │   X  -8..8
                    │  + closet HauntDoor #2     │
                    └─────────────┬───────────────┘
                        (open archway, no wall — Z=-9 line)
┌───────────────────────────────┬─┴─┬───────────────────────────────┐
│          BENCH WING           │ F │          BANISH WING           │
│  Workbench + 5 BenchSlots      │ O │  BanishBox + deposit prompt    │
│  + RibbonSpool + shelf decor   │ Y │  open floor for 4p confirm     │
│  + closet HauntDoor #1         │ E │                                │
│  Z -9..9, X -34..-8            │ R │  Z -9..9, X 8..34              │
└───────────────────────────────┴───┴───────────────────────────────┘
   (open archway, X=-8 line)    WorkshopSpawn   (open archway, X=8 line)
                                  (0,0.5,0)
```

#### 3.4 Structure vs. decoration

**STRUCTURE (procedural Luau — code-controlled, rebuilt every Rojo sync):** every floor/ceiling slab, every outer wall, the fountain basin, both slabs of the plus-shaped Workshop, all room-defining geometry above, all `ProximityPrompt`-bearing parts, all tagged manifest instances. None of this should ever be a Toolbox mesh — it must stay rebuildable.

**DECORATION (free Creator Store / Toolbox — searched and inserted live by the local-Studio-MCP session):**
- *"low poly Victorian street lamp"* — for the Plaza's corner posts (graft #1 keeps these non-flickering regardless of the model used)
- *"cracked stone fountain"* / *"broken angel statue"* — could replace/dress the procedural fountain basin+statue
- *"low poly Victorian shelf"* — Bench Wing decor shelves
- *"free rigged raven crow model"* — perched on the Shop's roofline or fountain edge, a cheap "something's off" cue
- *"vintage mailbox low poly"* — Invite postbox upgrade
- *"wooden crate barrel prop pack"* — scatter around Plaza edges / shopfront stoops
- *"porcelain doll mannequin" / "creepy doll model, free"* — for the shop-window silhouettes (graft #2)
- *"sewing / dollmaker tool set prop pack"* — Bench Wing clutter

**Compliance reminder (MASTER.md §3.4), repeated here per policy:** every one of the above must be audited before use for (a) hidden scripts/backdoors and (b) third-party/branded IP that could trigger a DMCA — this applies with extra weight to the doll-model searches, since a horror-doll Toolbox search is exactly where a branded lookalike (no cute Huggy-Wuggy-style character, no recognizable horror-doll IP) is most likely to turn up. Nothing above is a specific asset ID — these are search terms only.

#### 3.5 Manifest, tag, and Config notes for integration

- **Breaking manifest change, flagged loudly:** this design replaces `manifest.readyPad` (single `BasePart`, current shape per `MapBuilder.luau` line 192) with `manifest.joinSquares` (`{BasePart}`, 5 entries, tag `JoinSquare`). *(See `PACKET_1_LOBBY_SYSTEMS.md`'s join-square track for the service-side implementation of exactly this change — `LobbyService`'s `workspace:GetPartBoundsInBox` polling needs to go from one pad to five, and the `ReadyPad(standing)` remote needs a `squareIndex` field, or use the join-square track's own `JoinSquareUpdate`/`JoinSquareAction` remotes instead of extending the old one — see that packet.)*
- New CollectionService tags to add (R4): `JoinSquare`, `ShopKiosk`, `ClassesKiosk`, `JournalKiosk`, `InviteKiosk`. Kept as-is, just relocated: `HauntDoor`, `WindowPane`, `BenchSlot`, `GlyphSpawn`, `LedgerDesk`, `DetectorRack`, `RibbonSpool`, `BanishBox`, `LobbySpawn`, `WorkshopSpawn`, `Chalkboard`, `LeaderboardBoard`.
- **Lamp-tag split, do not skip:** `HauntService`'s `LightsOutBeat` toggles every instance tagged `Lamp`. If the Plaza's four corner lamp posts also carry the `Lamp` tag, a haunt firing during someone else's active shift plunges players still waiting at the join squares into darkness. Give the Hub's lamps a separate, untagged (or `HubLamp`-tagged) light so `manifest.lamps` stays Workshop-only.
- **`WorkshopDoor` is repurposed, not removed.** With entry now via `PivotTo` teleport instead of a walked corridor, there's nothing left to physically block — keep the tag/manifest field for compatibility but make it a static "Shift N in progress" plaque in the Foyer, not a `CanCollide` slab. This is an explicit choice this section is making, not an assumption — confirm with whoever owns `ShiftManager`/`LobbyService` that dropping the physical lock in favor of join-square countdown gating is acceptable.
- **New Config keys this design assumes** (proposed additions, nothing renamed — R3): `Config.Lobby.JoinSquareCount = 5`, `Config.Lobby.JoinSquarePlayerCap = 4`, `Config.Lobby.JoinSquareCountdownSeconds = 30`. Existing `Config.Lobby.ReadyCountdownSeconds = 10` (confirmed present in `src/shared/Config.luau` line 24) is left untouched but is likely dead code once the join-square system replaces the single ready pad — flag for the team to confirm rather than deleting. *(Note: `PACKET_1_LOBBY_SYSTEMS.md`'s join-square track independently proposes its own `Config.JoinSquares.*` table with slightly different key names — reconcile the two Config proposals into one when implementing; see that packet's integration notes.)*
- **Future-proofing:** the Workshop is built off one clean origin vector (`WS`). If the team later wants each join square to send its group into a genuinely separate private instance (true concurrent shifts), `MapBuilder` can stamp out N copies of the exact same plus-shape at `WS + i * offset` — no layout redesign needed, just a loop. *(`PACKET_1_LOBBY_SYSTEMS.md`'s join-square track resolves this via `TeleportService:ReserveServer` rather than N map copies — read that packet before deciding which approach to build; they are alternatives, not both needed.)*

### 4. Risk list — what to watch during implementation

1. **Hub facade wall gaps are the one place this design can still reproduce the reported bug.** Unlike the Workshop (zero interior walls, see §3.2), the Shop/Classes/Apothecary window cutouts, the Shop's entrance stoop, and the postbox alcove are all openings cut into otherwise-solid walls — exactly the pattern that produced playtest report items A1 (solid plug in a doorway) and A2 (void gap between rooms). Use an explicit named gap list per facade wall (not the current single-centered-gap `room()` helper) and walk through every opening by hand before calling the Hub done.
2. **Workshop slab build order.** The two overlapping full-footprint slabs (horizontal arm + vertical arm) must both exist before any wing's perimeter walls go up, and the vertical arm's Z-range must fully contain the Foyer's Z-range (18-stud overlap, not an edge-touch). Getting this backwards silently reintroduces the exact A2 void-gap bug even inside this "structurally safe" design.
3. **`manifest.readyPad` → `manifest.joinSquares` is a breaking contract change**, not additive. If the join-square service ships without this map change landing in the same integration pass (or vice versa), the Hub will build and look correct but no one will be able to start a shift — this needs to land together, not "whenever." See `PACKET_1_LOBBY_SYSTEMS.md`'s integration notes for the service side.
4. **Asset sourcing risk on the doll-model searches specifically.** The shop-window doll silhouettes and the fountain statue are the highest-DMCA-risk Toolbox searches in this spec (horror-doll search terms are exactly where branded lookalikes surface) — audit before insertion per MASTER.md §3.4, and budget real art-direction time for the three north-side building facades, which the base proposal itself flags as likely to look "blocky" without a decoration pass from the local-Studio-MCP session.

---

## 5. Addendum — reference screenshots reviewed 2026-08-15

The team's Drive folder (9 Animal Hospital screenshots) was private when the 3 proposals and the judge
pass above were drafted, so all three were written from the team's own text description alone. The
folder is now shared and has been reviewed. Nothing above needed to change structurally — the winning
"Hollow Square" synthesis already independently landed close to the real thing — but several concrete
visual/layout details are worth folding in before implementation:

- **The reference's own hub is a dead-end road/parking area behind the hospital building**, not a town
  square — closer to Proposal 1 ("Thimble Row") than to the winning Proposal 3: a striped road
  barrier blocking a tunnel/dead-end, chain-link fencing, a parked ambulance/van near the spawn, and
  actual highway/road signage (the source game reads as a small Korean/Asian city street, matching the
  team's own original "small Korean city area" description). **This does not overturn the judge's
  recommendation** — Proposal 3's fountain-square is a stronger clip-worthy establishing shot and its
  Workshop is structurally safer (see §4 above) — but if the team would rather match the reference's
  literal "dead-end alley behind a building" framing instead of a town square, Proposal 1's full
  layout (§1 above) is the closer match and is still fully specced and ready to build as an alternative.
- **Two SEPARATE leaderboard boards**, not one combined "Night Shift Records" board — the reference
  flanks its dead-end with a "PATIENTS TREATED" board (our `dollsCleared`) on one side and a "HIGHEST
  SHIFT" board (our `bestShift`) on the other, each showing a ranked list. Recommend the Hub's single
  `Leaderboard Board` row in §3.1's table become two boards, e.g. flanking the Shop's stoop or the
  Entry Alley mouth — one tagged `LeaderboardBoard` (kept, `bestShift`, as already speced) plus a new
  second tag `PatientsBoard` (`dollsCleared`). See `PACKET_1_PATCHES.md`'s B1 fix for the
  `LobbyService.refreshLeaderboard` code this touches — that fix only corrects facing direction for
  the single existing board; splitting it into two is a small follow-up on top of that fix, not
  required for B1 itself to land.
- **Join squares are a hollow neon diamond OUTLINE** (a rotated square traced by a thin glowing
  border, like a picture frame on the ground), not a filled tile — idle = cyan-blue, occupied =
  bright yellow, with a plain "N/4" label floating above. `PACKET_1_LOBBY_SYSTEMS.md`'s Join Squares
  track has been updated with the corrected idle/occupied colors and a construction note for whoever
  builds the physical tiles.
- **Shop and Classes are ALSO physical, round-glow `ProximityPrompt` kiosks** near the spawn/parking
  area (each with a floating name label and an "[E] Open Shop"-style prompt) — confirms the
  `ShopKiosk`/`ClassesKiosk` tags already planned in §3.1's Hub table are worth keeping as real,
  separate world objects, not just HUD-button decoration.
- **The left-side HUD button order is confirmed: Shop, Invite, Classes, Journal**, top to bottom —
  matches the team's own original text description exactly. `PACKET_1_LOBBY_SYSTEMS.md`'s `LobbyHud`
  spec has been corrected to this order (an earlier draft of that packet had briefly dropped the
  Classes button and reordered the rest — the team confirmed keeping all 4 as separate screens).
- **The bottom join-square action bar is EXIT (red) / Skip Tutorial (greyed out when locked) / START
  NOW (green)**, left to right, exactly as speced in `PACKET_1_LOBBY_SYSTEMS.md`'s `JoinSquareUI.luau` —
  now updated there with matching button colors.
- **Player billboards show "Top Shift: N" plus the player's equipped class name** underneath, in
  place of a second numeric stat — a small, cheap `LobbyService` addition noted in
  `PACKET_1_LOBBY_SYSTEMS.md`'s Track A §6b.
- **Not folded in — a bigger mechanic, flagged for a future checklist, not this batch:** the
  reference's Classes screen also shows a per-class outfit/skin (worn by a live 3D preview model) and
  a per-class level/XP system (Lv.1/2/3 tabs, each unlocking a bigger version of the same buff), plus
  a wholly separate "Skins" tab. The team's own original text description of classes ("a specific
  buff, like extra sanity or extra money") matches the simpler single-tier system already fully
  specced in `PACKET_1_LOBBY_SYSTEMS.md`, which is what's shipping in this batch — the richer
  leveling/outfit system is real and worth doing later, but is a materially bigger scope (per-class
  XP tracking, outfit assets, a Skins economy) than what was briefed for this pass.
