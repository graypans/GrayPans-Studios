# Project Porcelain — Integration Contract (build-internal)

This is the binding contract for every module in the beta. Build agents implement EXACTLY these
APIs/payloads for their assigned files and touch nothing outside them. Loose typing at module
boundaries (`ctx: any`), strict inside. Deviations = integration failures.

## Global rules

- `--!strict` at top of every file. Pass `luau-lsp analyze --definitions=/usr/local/lib/porcelain-tools/globalTypes.d.luau --sourcemap=sourcemap.json <your files>` with **zero errors** (regenerate sourcemap first: `rojo sourcemap default.project.json -o sourcemap.json`).
- Read `src/shared/` foundation before writing: Config, Util, Remotes, SoundKit, SoundConfig, Defs/*, Logic/*. Use them; never duplicate their logic. Use `Util.log/warn/safeCall/waitForChild`. No bare `WaitForChild` without timeout (R4). No magic numbers — read Config; you MAY append new Config keys (never rename/remove existing).
- Use ONLY remotes defined in `src/shared/Remotes.luau` via `Remotes.get(Remotes.Names.X)`. If one seems missing, implement around it and note it in your final report — do NOT edit Remotes.luau.
- Kill switches: honor `Config.Features.*` and `Config.Haunts.*` (R3). Wrap risky externals in `pcall`/`Util.safeCall`.
- Zero asset uploads exist: no Animation assets (procedural TweenService only), no Decals/Textures (SurfaceGui Frames/TextLabels for drawings), no catalog sound ids (SoundKit handles unset cues — always tolerate `nil`).
- Server is authoritative: validate EVERY client remote (sender identity, distance where relevant, state legality). Never trust client-sent ids blindly.
- All world instances you create that others must find get CollectionService tags (list below) AND sensible names.

## Server architecture

`src/server/init.server.luau` (integration-owned, do not write it) requires every service module in
`src/server/Services/`, then calls `Service.init(ctx)` on each in this order:
MapBuilder (build first), DataService, WatchService, DollService, GlyphService, TellService,
PresenceService, HauntService, BanishService, **ClassService** (needs DataService + DollService
already up, for the `StartWithRibbon` buff), LobbyService, ShiftManager, **JoinSquareService**
(additive; only calls into ShiftManager from event handlers, never at init), **QuestService** (needs
`ShiftManager.onShiftCleared` + `DollService.onRibbonTied` registerable), DebugService.

`ctx` (type `any`) fields available to every service after wiring:
```
ctx.services = { MapBuilder=..., DataService=..., WatchService=..., DollService=..., GlyphService=...,
                 TellService=..., PresenceService=..., HauntService=..., BanishService=...,
                 ClassService=..., LobbyService=..., ShiftManager=..., JoinSquareService=...,
                 QuestService=..., DebugService=... }
ctx.manifest  -- MapBuilder's world manifest (below)
ctx.rng       -- Random.new() (Roblox Random; matches Draw.RngLike)
```
Every service module returns a table. `Service.init(ctx)` stores ctx; services call each other ONLY
via `ctx.services.X.fn(...)` at runtime (never `require` another service — prevents cycles).

### MapBuilder — `src/server/Services/MapBuilder.luau`
`MapBuilder.build(): (manifest: any, failures: {string})` — called before init wiring; builds the whole
world under `workspace.PorcelainMap` (a Folder). Each room in its own pcall'd builder function; a
failed room appends its name to `failures` and the rest still build (plan review: one typo can't
blank the world). Low-poly parts + built-in materials only.

**Superseded 2026-08-15 by the "Hollow Square" redesign** (`docs/packets/PACKET_1_MAP_DESIGN.md` §4):
a dead Victorian town square (**Hub**, around world origin) facing the Dollmaker's shop, with a
plus-shaped **Workshop** (built far away, at `Vector3.new(0,0,600)`, reached only via ShiftManager's
existing ShiftIntro teleport, never walked to) whose floor/ceiling are two overlapping full-footprint
slabs with walls ONLY on the plus-shape's outer perimeter — no interior wall exists anywhere, which
makes the old sealed-room/void-gap bug class (A1/A2) structurally impossible rather than just
carefully avoided. The Hub's Shop/Classes/Apothecary buildings are solid closed facades (mounted
decorative windows/signs + a ProximityPrompt, no interior) for the same reason. Full room-by-room
detail lives in that packet doc, not duplicated here.

`MapBuilder.build()` conditionally builds the Hub and/or the Workshop depending on `ServerKind`
(`src/shared/ServerKind.luau`): both always build in Studio / same-server mode; a live public lobby
server builds Hub only, a live reserved shift server builds Workshop only (Join Squares track, one
Place + `TeleportService:ReserveServer` topology).

- ≥9 glyph spawn markers spread across all 3 Workshop wings (invisible parts, tag `GlyphSpawn`).
- All ProximityPrompts everywhere: `RequiresLineOfSight=false`, `MaxActivationDistance=Config.Care.PromptDistance`, `Exclusivity=Enum.ProximityPromptExclusivity.OnePerButton`.
- Manifest returned (fields the old design no longer has are removed; `readyPad` is gone, superseded
  by Join Squares — `LobbyService`'s ready-pad poll loop stays nil-safe on its absence):
  `{ root: Folder, lobbySpawn, workshopSpawn, workshopDoor, workshopDoorSign (Sign-only plaque, no
  Slab — setDoorLocked's CanCollide toggle silently no-ops), chalkboard, joinSquares: {BasePart}
  (tag JoinSquare, one recolorable Neon diamond per square), inviteKiosk, shopKiosk, classesKiosk,
  journalKiosk, leaderboardBoard (tag LeaderboardBoard, "Highest Shift"), patientsBoard (tag
  PatientsBoard, "Patients Treated" — TWO separate boards per the reference screenshots, not one),
  benchSlots: {BasePart}, glyphSpawns: {BasePart}, banishBox: Model, banishLid, banishGlow,
  banishPrompt: ProximityPrompt, detectorRack: BasePart, ledgerDesk: BasePart, ledgerPrompt:
  ProximityPrompt, ribbonSpool: BasePart, ribbonPrompt: ProximityPrompt, lamps: {BasePart} (Workshop
  only — Hub lamps are deliberately untagged so HauntService's LightsOutBeat can't darken the Hub),
  hauntDoors: {Model}, windowPanes: {BasePart} }`.

### DollService — `src/server/Services/DollService.luau`
Doll rig (built in code, per variant palette — define ≥6 palettes):
Model "Doll" (tag `Doll`), attributes `DollId: string`, `DisplayName: string`, `Variant: number`.
NEVER store marked/care state in attributes (replication leaks) — server tables only.
Parts (all Anchored, CanCollide=false): `Root` (transparent), `Body`, `Head` (SurfaceGui face: two eye
Frames with dark pupil Frames — pupils movable for EyesFollow), `ArmL`, `ArmR`, `MusicBox` on lap with
child `Crank` part. One ProximityPrompt "CarePrompt" on Body (see flow). Motion = TweenService on part
CFrames / PivotTo relative to bench slot; always return to rest pose ≤2s (unwatched moves excepted).
API:
- `init(ctx)`
- `spawnShift(shiftParams: any, names: {string}, markedIndex: number, rng: any): {any}` — spawns
  `shiftParams.dollCount` dolls onto manifest benchSlots; returns DollInfo list `{ {id, name, variant} }`.
  Fires `ShiftData` is NOT yours — ShiftManager broadcasts; just return the list.
- `getDollIds(): {string}` · `getDisplayName(dollId): string`
- `isMarked(dollId): boolean` (server-only truth) · `getMarkedId(): string?`
- `nextStepFor(dollId): string?` (next incomplete listed step id, order-gated)
- `completeStep(player: Player, dollId, stepId): boolean` — legal only if it IS the next step and a
  minigame lock was held (see flow); updates state, fires `DollUpdate` `{careDone = {stepIds...}, done = bool}`;
  invokes `onStepCompleted` callbacks.
- `allListedCareDone(): boolean` (every doll's 5 steps)
- `tieRibbon(player, dollId): boolean` — legal when player has a ribbon (see ribbon flow); marks ribbonTied;
  fires `DollUpdate` `{ribbon = true}` ONLY to the tying player (others must not get UI hints; it's memory-based dread).
- `hasRibbon(dollId): boolean`
- `setName(player, dollId, choiceIndex: number?, freeText: string?)` — Config.Features.Naming;
  curated list index, or filtered free text when Features.FreeTextNames (pcall FilterStringAsync +
  GetNonChatStringForBroadcastAsync, fallback keeps current name); updates attribute + fires `DollUpdate` `{name=...}`.
- Care/minigame flow (server-auth): prompt Triggered → if next step & no lock: create lock (player, dollId,
  stepId, expiry = now + Config.Care.MinigameSeconds), disable that doll's prompt, fire `MinigameStart`
  (to that player, with seed) → client plays minigame → `MinigameDone` (success) → validate lock holder →
  completeStep; on failure or lock expiry: release lock, re-enable prompt, fire `MinigameCancel` (R2).
- Ribbon flow: `ribbonPrompt` Triggered → player "holds a ribbon" (server table; max 1; a small part
  welded to their hand is a nice-to-have, skip if fiddly). Doll CarePrompt when doll's 5 steps done AND
  player holds ribbon → ActionText "Tie Silver Ribbon" → `tieRibbon`. When 5 steps done and player has
  NO ribbon and banish is unlocked → ActionText "Pick Up".
- Carry (R6): `pickup(player, dollId)` — only when BanishService unlocked; hide real doll (transparency 1,
  prompts off), attach visual-only clone (all parts Massless, CanCollide/CanQuery/CanTouch=false,
  WeldConstraint to HumanoidRootPart, offset in front of chest). `drop(player)` restores. `getCarried(player): string?`.
  On death/leave: drop automatically (PlayerGlue in your file: hook Players.PlayerRemoving + Humanoid.Died
  for carriers).
- `performTell(dollId, tellId): boolean` — implement all 6 Defs/Tells motions procedurally (HeadTurn:
  head yaw 20° 1.5s then back; EyesFollow: pupils track nearest character 4s; Scoot: PivotTo ±1.5 studs
  along bench — ONLY while unwatched (caller checks); MusicBoxTurn: crank rotates 5s; Slump: lean body 12°
  persist until next tell; StitchMark: add a dark zigzag SurfaceGui line on ArmL — permanent, real-marked only).
- `consume(dollId)` — doll sinks into banish box / vanishes (tween down + destroy), state removed;
  also fires `DollUpdate {removed = true}` first (B8) so the client checklist stops showing it as
  still-in-play.
- `returnToBench(dollId): boolean` — A4: companion to `consume()` that undoes a deposit WITHOUT
  destroying the doll (moves it back to its bench slot, restores visibility). Used for the
  "right doll, ribbon not tied yet" wrong-banish outcome, so the only doll that can ever win the
  shift is never permanently destroyed by an incomplete attempt.
- `giveRibbon(player): boolean` — grants a ribbon outside the spool-prompt flow; used by
  ClassService's `StartWithRibbon` buff at ShiftIntro.
- `onRibbonTied(fn(player, dollId))` — register callback, fired from inside `tieRibbon()`; used by
  QuestService's ribbon-tie quest counter.
- `clearShift()` — destroy all dolls/locks (idempotent; used on abort + run end).
- `onStepCompleted(fn(player, dollId, stepId))` — register callback (multiple allowed).

### WatchService — `src/server/Services/WatchService.luau`
Consumes `CameraReport` (UnreliableRemoteEvent, client streams Camera CFrame at Config.Tells.WatchReportHz).
Sanity check: camera pos within 25 studs of that player's head, else ignore report (stale/spoof).
`isWatched(model: Model): boolean` — true if ANY player's validated recent camera (< 1s old) has the
model's Head/PrimaryPart inside a Config.Tells.WatchFovDegrees cone, within WatchMaxDistance, AND an
occlusion raycast (params excluding characters + the doll itself) reaches it. Fallback (no report yet /
Features gate): use the player's character HumanoidRootPart LookVector cone instead. Also expose
`watchedMap(): {[string]: boolean}` keyed by doll id for the debug overlay (query via ctx.services.DollService).

### TellService — `src/server/Services/TellService.luau`
`startShift(shiftParams: any, rng: any)` / `stopShift()`. Loop (task.spawn, guard with a generation
counter so stale loops die): every rng interval in [tellIntervalMin, tellIntervalMax] → REAL tell on the
marked doll: weighted Draw from Defs/Tells (respect `unwatchedOnly` → skip Scoot/Slump while watched,
re-draw); StitchMark only from tier ≥ 2 (query PresenceService) and at most once per shift. Then, with
`shiftParams.fakeTellChance` (Features.FakeTells): FAKE tell on a random innocent — only `fakeable` defs,
never StitchMark. All executions via `Util.safeCall` + `ctx.services.DollService.performTell`.

### GlyphService — `src/server/Services/GlyphService.luau`
`startShift(spiritCode: {string}, rng)` — spawn one floating glyph token per code glyph (3) at distinct
random manifest glyphSpawns: small dark part, tag `GlyphToken`, attribute `GlyphId`, slow spin+bob tween,
faint PointLight, ProximityPrompt "Collect Glyph" (RequiresLineOfSight=false). Maintain detector Tool at
the rack: Tool named "Spirit Compass" (Handle part + welded massless bits, `CanBeDropped=false`,
RequiresHandle default) placed at manifest.detectorRack; inside the Tool a Folder `GlyphTargets` holding
one `Vector3Value` per UNCOLLECTED token (server updates on collect; DetectorClient reads — R6 passive).
Collect (server validates distance ≤ Config.Glyphs.CollectDistance): destroy token, remove Vector3Value,
add to found set, fire `GlyphFound` (glyphId, foundListArray, finderDisplayName) to ALL (shared state —
plan review fix). `SlotGlyph` (slotIndex 1..3, glyphId or nil to clear): only found glyphs slottable;
slots are SHARED; broadcast the new slots to all via `GlyphFound` with a `slots` field:
payload contract for `GlyphFound`: `(glyphId: string?, data: {found: {string}, slots: {string?}, finder: string?})` —
fire with glyphId=nil for slot-only changes.
`getSlots(): {string?}` · `getFound(): {string}` · `stopShift()` (destroy tokens/tool state; re-rack detector).
If a carried detector's character dies/leaves, respawn the Tool at the rack (hook inside this service).

### PresenceService — `src/server/Services/PresenceService.luau`
Wraps Logic/PresenceMath with a Heartbeat loop (10 Hz). `startShift(rateMultiplier)` resets state;
`stop()` halts; `surge(amount)`; `notifyStepCompleted()` (call PresenceMath.onStepCompleted with os.clock());
`setAllDollsDone(bool)`; `getTier(): number`; `getValue(): number`; `onMaxed(fn)` (fires once per shift max).
Broadcast `PresenceTier` to all on tier change. Notify `ctx.services.HauntService.setTier(tier)`.

### HauntService — `src/server/Services/HauntService.luau`
`startShift(rng)` / `stopShift()` / `setTier(n)`. Scheduler loop: at most one event per
Config.Haunts.MinSecondsBetween (plus per-event cooldowns), draw via Logic/Draw.weighted from Defs/Haunts
where `def.tier <= currentTier` AND `Config.Haunts.Events[id] ~= false`; skip entirely if
`Config.Haunts.Enabled == false`. Never fire while any minigame lock is active (ask DollService — add
`hasActiveLock(): boolean` to its API). Each event pcall'd (R3). World-scope implementations here:
- `BenchRattle`: shake bench props ±0.15 studs 1.5s + SoundKit.play("BenchRattle", benchPart)
- `DoorCreakSlam`: swing a random hauntDoor open slowly 3s then slam shut 0.1s + "DoorSlam" cue
- `MusicBoxSwell`: pick a doll, crank turns + (cue "MusicBoxLoop" attach/play 6s then stop)
- `SilhouetteDoorway`: spawn a black translucent humanoid-shaped part group in a doorway for 1.2s facing a random player, then remove
- `WindowFigure`: dark figure outside a random windowPane for 1.5s
- `DollHeadSnap`: random doll head snaps 40° toward nearest player + back (works on innocents too — it's a haunt, not a tell)
- `LightsOutBeat`: all lamp lights Enabled=false for 2.5s + "LightsOut" cue, then restore
Client-scope events (`WhisperPass`, `Taken`): just fire remote `HauntFired` (hauntId, params) to one
random shift participant (Taken: respect Config.Features.Taken=false default AND never solo).

### BanishService — `src/server/Services/BanishService.luau`
`setUnlocked(bool)` (ShiftManager calls when allListedCareDone flips) — toggles manifest.banishPrompt.Enabled
+ box lid glow. Deposit flow: banishPrompt Triggered → player must be carrying a doll (DollService.getCarried) →
doll into box (drop+position), state `awaitingConfirm`, fire `BanishPrompt` (dollId, dollName) to ALL.
Confirm (`ConfirmBanish` remote, confirm=true/false): quorum = players currently in the shift participant
set AND in server (recompute on PlayerRemoving — plan review fix). Resolve BANISH when: all confirmed true,
OR majority true and Config.Banish.MajorityTimerSeconds elapsed (broadcast countdown via `BanishPrompt`
with `{countdown = n}` updates), OR solo after SoloConfirmSeconds. Any `confirm=false` → cancel: doll
returns to bench slot, fire `BanishPrompt` with `{cancelled = true}`.
On resolve: call `ctx.services.ShiftManager.onBanishResolved(dollId)`. This service does NOT decide
correctness — ShiftManager does. Also `reset()` for shift/run cleanup.

### ClassService — `src/server/Services/ClassService.luau`
Purchasable classes: ownership + one-equipped-at-a-time model + buff folding into shift params.
Ownership/equip state lives in DataService (R5); this service is validation + the buff-application
hook ShiftManager calls once per ShiftIntro. Zero world `Instance`s, zero physics (R6) — pure data +
two remotes (`BuyClass`, `EquipClass`).
- `isOwned(player, classId): boolean` — free classes (`price <= 0`) are always owned, never persisted.
- `getEquippedId(player): string` — defensive fallback to `Classes.starterId` if the stored id is
  invalid or no longer owned.
- `getEquippedBuff(player): ClassBuff` · `getCoinMultiplier(player): number` (1 unless the equipped
  buff is `CoinMultiplier`; convenience read used at every coin-award call site).
- `buyClass(player, classId): (ok: boolean, message: string)` — validates price/ownership, spends
  coins via DataService, grants ownership, pushes `ClassesData`, returns a Toast-ready message.
- `equipClass(player, classId): (ok: boolean, message: string)`.
- `applyBuffs(shiftParams, participants): any` — called once per shift from ShiftManager's ShiftIntro
  branch. Returns `{strikeLimitBonus, careSpeedMultiplier, tellDurationMultiplier}`: `ExtraStrike`/
  `TellDurationMultiplier` take the most-generous value across ALL equipped participants (shift-wide
  state, not per-player); `StartWithRibbon` is applied directly as a side effect
  (`DollService.giveRibbon`); `CoinMultiplier` is deliberately NOT folded in here — it's read
  per-player at each award call site instead.
- Pushes `ClassesData {owned: {[classId]: bool}, equipped: classId}` on PlayerAdded + DataService.onStatsChanged.

### DataService — `src/server/Services/DataService.luau`
R5 exactly. `init(ctx)` probes availability ONCE (pcall GetDataStore + a GetAsync on a probe key, deferred
in task.spawn — never blocks init). Per player, `getStats(player): Stats` where `Stats` now also
carries the Economy/Social fields merged in during the map-redesign batch: `bestShift, dollsCleared,
perfectShifts, runs, coins, ownedClasses: {[classId]: bool}, equippedClass: string,
ribbonsTiedTotal, tutorialDone: boolean, claimedQuestIds: {[questId]: bool}, questFlags:
{[flagId]: bool}, loaded: boolean` (zeros/empty until async load lands). `loadPlayer` fires
`CoinsUpdate` immediately on load plus a 3s-delayed resend (covers clients that finish connecting
Remotes late). `recordRun(player, {shiftReached, dollsCleared, perfect})` — merge into cache
(bestShift=max, sums), mark dirty. Merge semantics by field shape: numbers sum or max (existing
pattern), sets (`ownedClasses`, `claimedQuestIds`, `questFlags`) union/OR-merge per key, scalars
(`equippedClass`) last-write-wins, booleans (`tutorialDone`) one-way OR-merge (never flips back to
false). Flush gate is a `dirty: {[Player]: boolean}` table (replaces the old "did runs/bestShift
change" check, which used to silently skip flushing a player whose only changes were coin/class/quest
updates). Flush: UpdateAsync with merge semantics against the CURRENT stored value (safe
snapshot-then-clear-only-sent-keys for set-valued fields, since UpdateAsync's retry can yield) — NEVER
SetAsync — on PlayerRemoving + BindToClose (flush all, inside the 30s budget) + every 120s autosave.
Retries per Config.Data. Everything pcall'd; failures log once, never throw.
Public API additions: `addCoins(player, amount)` (clamps the balance to never go below 0 via
`math.max(amount, -stats.coins)`; fires `CoinsUpdate`), `spendCoins(player, amount): boolean` (fails
if insufficient), `grantClassOwnership(player, classId)`, `setEquippedClass(player, classId)`,
`addRibbonTied(player, n)`, `setTutorialDone(player)`, `setQuestFlag(player, flagId)`,
`markQuestClaimed(player, questId): boolean` (false = race, another claim already landed),
`onStatsChanged(fn(player, stats))` (fires on every mutation — the existing callback name, kept as-is
since ClassService/LobbyService/QuestService all hook it).

### LobbyService — `src/server/Services/LobbyService.luau`
- Billboards: on every CharacterAdded, BillboardGui on Head (Adornee), two lines — the player's
  display name, then (per the Animal Hospital reference screenshots) `"Top Shift: N"` plus the
  player's **currently equipped class name** underneath (`ClassService.getEquippedId` →
  `Classes.byId[id].name`), in place of a second numeric stat. MaxDistance
  Config.Lobby.BillboardMaxDistance, AlwaysOnTop=false; `Humanoid.DisplayDistanceType = None`; update
  on DataService.onStatsChanged.
- Leaderboard: **TWO separate boards** (B1's follow-up, not one combined board) — `leaderboardBoard`
  ("HIGHEST SHIFT", top 8 by `bestShift`) and `patientsBoard` ("PATIENTS TREATED", top 8 by
  `dollsCleared`), both tag-found via the manifest. `SurfaceGui.Face = Enum.NormalId.Front` (B1 fix —
  verified against the Hollow Square Hub's actual geometry: both boards sit at Hub Z=29.4 unrotated,
  and every Plaza player position is south of that, so Front is the correct outward-facing side for
  THIS map, not a blind copy of the old Lobby layout's fix). Refresh on stats changes + player
  add/remove.
- Ready pad: poll workspace:GetPartBoundsInBox over `manifest.readyPad` 2 Hz for characters; when ≥1
  player stands on it and state is LobbyIdle → call `ctx.services.ShiftManager.requestStart(playersOnPad)`.
  **Superseded by Join Squares** — `manifest.readyPad` no longer exists in the Hollow Square map, so
  this loop's `if not pad then continue end` guard makes it a permanent, harmless no-op; kept for
  `ShiftManager.requestStart`/the countdown machinery, which Join Squares' `beginShiftFor` reuses.
- Spawn management: `setShiftSpawnActive(bool)` — toggles which SpawnLocation is Enabled; nil-safe if
  either spawn is missing from the manifest (relevant to the live Lobby-only/Workshop-only server split).

### ShiftManager — `src/server/Services/ShiftManager.luau`
Owns: state machine, participants (Set<Player>), shiftNumber, strikes, chosen spirit, run stats
(dollsCleared, perfectSoFar), watchdogs, plus (as of the A4/B7/B9/B11 fixes and the
Economy/Social/Join-Squares tracks) `markedDollName` (mark-time name snapshot), `lastBanishOutcome`
(`nil | "wrongDoll" | "incomplete"`), `runEndReason` (`"presence" | "watchdog"`), `coinAwardedDolls`
(per-shift double-award guard), and `shiftClearedCallbacks`.
States & transitions (broadcast `StateChanged` `{state, shift, strikes, objective}` on every change):
- `LobbyIdle`: workshop door locked. Run-scoped state (strikes, spirit, markedDollName,
  lastBanishOutcome, runStats, participants) resets BEFORE `broadcastState()` fires (B4 — the lobby
  HUD must never show the just-ended run's strike count). `requestStart(playersOnPad)` begins
  countdown (Config.Lobby.ReadyCountdownSeconds, broadcast `ReadyCountdown`; recall with current
  standing set each poll — empty set cancels, broadcast nil). Countdown end → participants = standing
  set → `ShiftIntro`. `beginShiftFor(occupants): boolean` (Join Squares) does the same
  `participants = ...; transition("ShiftIntro")` pair directly, skipping the countdown — returns
  false if not currently LobbyIdle.
- `ShiftIntro` (Config.Shift.IntroSeconds): resets `coinAwardedDolls`/`lastBanishOutcome`, picks
  spirit (Draw.one of Spirits.list), computes `Escalation.forShift(cfgFromConfig, shiftNumber,
  #participants)`, then folds `shiftParams.classBuffs = ClassService.applyBuffs(shiftParams,
  participants)` (shift-wide, most-generous-wins aggregate: `strikeLimitBonus`,
  `careSpeedMultiplier`, `tellDurationMultiplier`; `StartWithRibbon` applied as a side effect via
  `DollService.giveRibbon`). names = Draw.sample(DollNames, count), markedIndex = rng int,
  DollService.spawnShift, snapshots `markedDollName` from the returned DollInfo (A4/B7 — recap must
  never depend on the doll's server record still existing later), GlyphService.startShift(spirit.code,
  rng), unlock workshop door, teleport participants to workshop spawn (PivotTo), broadcast `ShiftData`
  `{shift, dolls, glyphTotal}`. → `ShiftActive`.
- `ShiftActive`: TellService/PresenceService/HauntService started. Wire DollService.onStepCompleted →
  PresenceService.notifyStepCompleted + Economy's per-doll coin award (`Config.Economy.CoinsPerDoll *
  ClassService.getCoinMultiplier(participant)`, once per doll via `coinAwardedDolls`) + objective
  refresh. When allListedCareDone → PresenceService.setAllDollsDone(true) +
  BanishService.setUnlocked(true) + objective update. PresenceService.onMaxed → tags
  `runEndReason = "presence"` → `RunEnd`. BanishService resolution → `onBanishResolved(dollId)`:
  `correct = (dollId == marked) AND GlyphMatch.matches(spirit.code, GlyphService.getSlots()) AND
  DollService.hasRibbon(dollId)`.
  - **Correct**: `DollService.consume(dollId)`, broadcast `BanishResult {correct=true, ...,
    spiritName}` (spiritName only when correct). `dollsCleared += dollCount`; `perfect += 1` if no
    strikes this shift. Social's `shiftClearedCallbacks` fire here (participants snapshot BEFORE
    `shiftNumber` increments — a player who wins shift 1 then quits still gets credit; this is NOT
    hooked at RunEnd). Economy's perfect/late-shift coin bonus pays out here too (pre-increment
    `shiftNumber`). `shiftNumber += 1` → `ShiftResult`.
  - **Not correct** (A4 fix — the two non-correct outcomes are no longer treated identically):
    strikes+1, `PresenceService.surge(Config.Presence.WrongBanishSurge)`. If `isMarked` (right doll,
    ribbon just not tied) → `lastBanishOutcome = "incomplete"`, `DollService.returnToBench(dollId)`
    (doll survives — the shift stays winnable), `BanishResult {correct=false, incomplete=true, ...}`.
    Else (genuinely wrong doll) → `lastBanishOutcome = "wrongDoll"`, `DollService.consume(dollId)`,
    `BanishResult {correct=false, ...}`. If
    `strikes >= Config.Shift.StrikeLimit + (shiftParams.classBuffs.strikeLimitBonus or 0)` (Economy's
    SteadyNerves buff) → `RunEnd`, else stay `ShiftActive` (objective text branches on
    `lastBanishOutcome`, see below).
- `ShiftResult` (ResultSeconds): win → stop tell/haunt/presence, DollService.clearShift,
  GlyphService.stopShift → next `ShiftIntro` (same participants ∩ still-in-server).
- `RunEnd`: stop everything. `runEndReason == "watchdog"` (B9: a ShiftActive timeout is NOT a
  possession scare) → calm `Toast` + `HauntFired("ShiftTimeout", {})`, no scare, lights stay on.
  Otherwise (genuine Presence-maxed ending) → THE scare: `HauntFired("DollmakerReveal", {})` + lamps
  off. 4s later broadcast `Recap {shiftReached (= shiftNumber itself, NOT shiftNumber-1 — B7),
  dollsCleared, perfect, traitorName (markedDollName snapshot, never a live doll lookup — B7),
  bestShift, isNewBest, reason ("presence"|"watchdog" — B9, recap must not always claim "the Presence
  got you")}`; DataService.recordRun for each participant; hand the group home — Join Squares: a live
  reserved shift server has no `lobbySpawn` to PivotTo, so `ServerKind.isReservedShiftServer()`
  branches to `JoinSquareService.sendGroupHome(participants)` (real cross-server teleport) instead of
  the normal in-place `teleportTo(lobbySpawn, ...)`; lock door, reset run state → `LobbyIdle`.
- Watchdogs (R2): every non-idle state arms `task.delay(Config.Shift.Watchdog[state])`; if still in that
  state when it fires → `Util.warn` + force the default transition. `ShiftActive`'s watchdog tags
  `runEndReason = "watchdog"` before forcing `RunEnd` (no generic toast for this one case — see the
  calm ShiftTimeout beat above); the other 3 cases still fire the generic
  `Toast("watchdog: forcing past <state>")`.
- Participants: PlayerRemoving prunes; empty participants during any shift state → abort silently to
  `LobbyIdle` (full cleanup, no recap). Mid-shift joiners: NOT added to participants; they stay in lobby
  (door locked) and auto-join at the `ShiftResult→ShiftIntro` boundary if standing on the pad / in a
  join square. Public API: `onBanishResolved`, `requestStart`, `beginShiftFor(occupants): boolean`
  (Join Squares, additive), `getState()`, `getParticipants()`, `getSpirit()`, `getShiftNumber()`,
  `refreshObjective()` (B2 — lightweight objective-only recompute+rebroadcast for services whose state
  change affects the objective string without warranting a full transition; called by
  `GlyphService.collect`/its `SlotGlyph` handler), `onShiftCleared(fn(participants, shiftNumber))`
  (Social/Journal hook registration; fired inside `onBanishResolved`'s correct branch, see above).
  Objective strings: care remaining → glyphs → ledger → banish ("Bring the WRONG doll to the Banish
  Box", intentionally misleading pre-attempt copy, unchanged) → **B11**: after an actual wrong banish
  THIS shift, the final line branches on `lastBanishOutcome` instead of repeating the same
  now-answered instruction ("That wasn't it. Find the REAL one." / "You had the right one —
  something's still missing. Try again.").
- Debug hooks for DebugService: `debugForceState(name)`, `debugSetShift(n)`, `debugReveal(): {marked, spirit,
  code}`, `debugStrike(delta)`, `debugEndRun()`.

### JoinSquareService — `src/server/Services/JoinSquareService.luau`
Lobby floor-tile "join squares" (Animal-Hospital-style party assembly). Each `JoinSquare`-tagged
`BasePart` fills with 1..`Config.JoinSquares.MaxGroupSize` players (poll loop, `LobbyService`'s
ready-pad idiom generalized to N squares), runs a `Config.JoinSquares.CountdownSeconds` countdown
once the first player steps on (collapses early on full if `AutoStartOnFull`), then hands the group
off to a shift — either `ShiftManager.beginShiftFor` in-place (Studio, or the live emergency kill
switch `Config.Features.PrivateShiftServers = false`) or a real
`TeleportService:TeleportAsync(..., {ShouldReserveServer = true})` to a fresh private server (live).
Idle/occupied/locking phases recolor the tile (`Config.JoinSquares.IdleColor/OccupiedColor/LockingColor`)
and drive a `"N/4"` BillboardGui. `JoinSquareAction(squareId, "Exit"|"StartNow"|"SkipTutorial")` is
server-authoritative — rejects actions from players not actually standing in that square.
Also owns the RECEIVING side of the handoff: in a live reserved shift server (`ServerKind.isReservedShiftServer()`,
no lobby, no squares exist there), `init()` instead waits for the expected `TeleportData.expectedUserIds`
to arrive (R2 watchdog: starts with whoever actually made it after `Config.JoinSquares.ArrivalWatchdogSeconds`,
even short of the full group) and calls `ShiftManager.beginShiftFor` itself.
- `sendGroupHome(players)` — called from ShiftManager's RunEnd branch when a live reserved shift
  server's run ends, to hand the group back to the public lobby via a real teleport (no-op in
  same-server mode, where ShiftManager's own in-place teleport-to-lobbySpawn already covers it).
- Kill switches: `Config.Features.JoinSquares` (false disables the whole subsystem; the old single
  ReadyPad flow keeps working untouched) and `Config.Features.PrivateShiftServers` (false forces
  everything in-place even live — the emergency escape hatch, same flag `ServerKind`/`MapBuilder` read).

### QuestService — `src/server/Services/QuestService.luau`
Journal/quests: tracks progress toward `Defs/Quests.luau` (7 milestone + 3 hidden easter-egg quests)
and pays out coin rewards. Progress is derived at read-time from `DataService`'s stats via pure
`Logic/QuestProgress.luau` (`compute`/`isComplete`, mirrors `Logic/GlyphMatch.luau`'s
client/server-shared split) — QuestService holds no separate progress cache, it's a thin authority
layer over DataService.
- `claim(player, questId): boolean` — validates completion + not-already-claimed via
  `DataService.markQuestClaimed` (race-safe), then `addCoins`.
- Easter eggs: 3 hidden `ProximityPrompt`-triggered world props (`QuestTrigger` tag), built
  independently of MapBuilder and parented under `ctx.manifest.root` (safe because MapBuilder always
  finishes before any service's `init()`) — a loose floorboard, a hidden note near the ribbon spool,
  and a stillness-detection spot (stand still `Config.Quests.StillnessSeconds` to trigger).
- Behind `Config.Features.TutorialGate`: hooks `ShiftManager.onShiftCleared` to call
  `DataService.setTutorialDone` for every participant the instant their first shift clears (design
  decision: guided one-time hints on shift 1 only, suppressed once `stats.tutorialDone` is true — no
  separate skippable tutorial flow).
- Behind `Config.Features.Quests`: hooks `DollService.onRibbonTied` to increment
  `ribbonsTiedTotal`; handles `ClaimQuest` remote; wires the easter eggs.
- Pushes `PlayerStats` (the full `Stats` snapshot) on PlayerAdded + DataService.onStatsChanged. This
  is also how `JoinSquareUI.luau`'s Skip Tutorial button visibility and Shop/Journal's coin displays
  ultimately get their data.

### DebugService — `src/server/Services/DebugService.luau`
Only active when Config.DebugMode. Player.Chatted commands (allowlist: Config.DebugAllowlist empty = all):
`/skipstate` (force default transition), `/shift N`, `/reveal` (Toast the marked doll + spirit + code to
sender), `/completedoll` (finish all steps on all dolls), `/strike +1|-1`, `/presence N` (set value),
`/haunt <id>` (force event), `/endrun`, `/resetrun`, `/ribbon` (give self ribbon). Each maps onto public
service APIs (add tiny debug setters where needed on YOUR OWN assigned services only — otherwise route
through ShiftManager's debug hooks). Feed `DebugInfo` remote at 2 Hz to DebugMode clients:
`{presence, tier, state, shift, watched: {[dollId]: bool}, marked: dollId?, spirit: id?, locks: n}`.

## Client architecture

`src/client/init.client.luau` (integration-owned) requires all controllers in `src/client/Controllers/`
and calls `Controller.init()` on each. Controllers are independent; they talk to the server ONLY via
Remotes and read `workspace` for tagged instances (CollectionService:GetTagged + GetInstanceAddedSignal).
Build ALL UI in code under a single ScreenGui per controller (ResetOnSpawn=false, IgnoreGuiInset=true where
fullscreen). Mobile-first: buttons ≥ 64px, bottom-half anchored interactions, no keyboard-only input.

- **Hud** (`Hud.luau`): top-center shift banner ("SHIFT 3" — big), objective line under it, strike pips,
  version stamp bottom-right (`Config.Version .. " " .. Config.BuildStamp`), doll checklist panel (right
  side, one row per doll: name + 5 step ticks — driven by `ShiftData`/`DollUpdate`; NO ribbon row).
  Listens: StateChanged, ShiftData, DollUpdate, ReadyCountdown (lobby countdown overlay), Toast (skip if
  Toast controller owns it — Toast is its own controller; Hud ignores Toast). **B4**: strike pips are
  defensively forced to 0 on `LobbyIdle` client-side regardless of the payload's `strikes` value.
  **B8**: `DollUpdate {removed = true}` greys the row out ("<name> — gone") instead of leaving a
  consumed doll's checklist reading as still-in-play.
- **Toast** (`Toast.luau`): queue of transient bottom-center messages from `Toast` remote (and a local
  `Toast.show(msg)` other controllers may call via a BindableEvent named `PorcelainToast` in
  ReplicatedStorage created lazily client-side — keep simple: export module function; controllers may
  require Toast directly for local toasts).
- **RecapUI** (`RecapUI.luau`): full-screen card on `Recap` payload — shift reached (huge), a **B9**
  reason-aware line under it ("The Presence caught up with you." vs. "The night ran long. The shop had
  to close before the Presence ever caught you." when `data.reason == "watchdog"`), dolls cleared,
  perfect badge, "The traitor was <traitorName>" line, NEW BEST flare, [Return] button (just closes;
  server already teleported). Also renders `BanishResult` staging: on receipt, 0.4s black flash + freeze
  frame vignette + reveal line (correct: "<NAME> WAS <SPIRIT>", gold text + SoundKit "StingReveal";
  wrong-and-innocent: "<NAME> WAS INNOCENT.", sickly green + "StingWrong"; **A4** `incomplete=true`:
  "THE BOX WOULD NOT CLOSE ON <NAME>… SOMETHING IS MISSING.", Accent-colored — never claims the marked
  doll "was innocent"), 3s, then dissolve.
- **DebugOverlay** (`DebugOverlay.luau`): Config.DebugMode only — left panel rendering `DebugInfo`.
- **ErrorPanel** (`ErrorPanel.luau`): Config.DebugMode only — collect last 10 client errors
  (ScriptContext.Error) + server messages via LogService.MessageOut filtered to Error/Warning containing
  "[Porcelain]"… client LogService only sees client logs; server errors arrive via Toast? Keep client-side
  only (last 10 client errors) + note in panel "server errors: see Output". Toggle visible with a small 🐞 button.
- **MinigameController** (`MinigameController.luau`): on `MinigameStart(dollId, stepId, seed,
  speedMultiplier?)` open the minigame for CareSteps.byId[stepId].minigame kind; on finish fire
  `MinigameDone(dollId, stepId, success)`; close on `MinigameCancel`. Implement 4 kinds, all
  touch-first, each ~Config.Care.StepSeconds:
  `mash` (tap the brush button repeatedly to fill a bar — icon is procedurally drawn Frames/UICorner,
  **B6**: not the 🪮 emoji, which renders as a tofu box — no font coverage for that codepoint),
  `hold` (press-and-hold inside a drifting circle — release outside = pause; fill to complete),
  `sequence` (5 paint dots appear in order on a doll face sketch; tap in order; wrong tap = one redo),
  `timing` (a needle sweeps a bar; tap in the green zone 3 times; zone shrinks). All success-only-hard:
  failure just retries within the lock window — the TIME is the cost (Presence keeps filling).
  `mash`/`hold` scale their fill rate by `speedMultiplier` (SwiftHands class buff, `<1` = faster;
  `sequence`/`timing` are accuracy-based and don't consume it).
- **NamingUI** (`NamingUI.luau`): first CarePrompt on an unnamed doll ALSO fires… simpler: after
  `ShiftData`, if any doll name is a default AND Features.Naming, show a compact top-half picker once per
  doll when the local player first completes a step on it (track via DollUpdate): 6 random curated names
  as big buttons + shuffle + skip; fires `ChooseName(dollId, choiceIndex)`. (Free text hidden behind
  Features.FreeTextNames=false.) **B10**: tracks each doll's current name (from `ShiftData` +
  `DollUpdate`) and excludes it from the 6 offered choices, so a doll's own default/current name can
  never appear as a "new name" option.
- **LedgerUI** (`LedgerUI.luau`): opens on ProximityPromptService.PromptTriggered (client-side signal)
  for the LedgerDesk prompt. Book UI: left page lists 6 spirits (name + flavor + its 3 glyph code rendered
  via GlyphRender); right page: 3 slot squares + found-glyph tray (from `GlyphFound` state). Tap glyph →
  tap slot = `SlotGlyph(slotIndex, glyphId)`; tap filled slot clears. Slots shared server-side; live-update
  from `GlyphFound`. Close button. A "MATCHED: <spirit>" banner client-computes via Logic/GlyphMatch for
  feedback (server stays authoritative). **B5**: closes automatically on `StateChanged` →
  `LobbyIdle`/`RunEnd`/`ShiftResult`/`ShiftIntro` (not just Lobby/RunEnd — the shift→shift boundary
  fires BEFORE the workshop teleport, confirmed against ShiftManager's own state ordering), AND on
  walking more than `Config.Ledger.AutoCloseDistance` studs from the LedgerDesk (Heartbeat watch,
  fails open — never traps the player with an unclosable book, R2).
- **BanishConfirmUI** (`BanishConfirmUI.luau`): on `BanishPrompt(dollId, dollName, extra)` show center
  modal "Banish <NAME>?" with CONFIRM / REFUSE, live countdown when `extra.countdown`, close on
  `{cancelled=true}` or `BanishResult`. Fires `ConfirmBanish(bool)`. **B3**: also closes on
  `StateChanged` → `RunEnd`/`LobbyIdle` as a belt-and-suspenders fallback — `BanishService.reset()`
  now always broadcasts `{cancelled=true}` too, but the state-transition listener covers any path that
  somehow misses that broadcast.
- **GlyphRender** (`src/shared/GlyphRender.luau`, shared): `render(glyphId, parent: GuiObject, color: Color3?)`
  — draws Defs/Glyphs strokes as rotated Frames filling parent; used by LedgerUI (and future chalk).
- **PresenceClient** (`PresenceClient.luau`): on `PresenceTier` — LOCAL Lighting lerps (tier 0 warm →
  3 sick green-dark: Ambient/OutdoorAmbient/lamp flicker), flicker loop scales with tier (client-local,
  review fix), ambience cue crossfade via SoundKit attach/volume (tolerate nil), music detune at tier 3
  (swap MusicBoxLoop→MusicBoxDetuned if present).
- **HauntClient** (`HauntClient.luau`): `HauntFired` handlers: `WhisperPass` (SoundKit play + brief
  directional camera nudge + faint vignette), `Taken` STUB (screen darkens 80%, "wake up… (tap)" — tap 5×
  or any other player within 5 studs auto-wakes… client-side stub: just tap-to-wake + hard 20s auto-clear),
  `DollmakerReveal` (run-end scare: 0.5s black, then a towering shadow face — assembled from Frames — lunges
  with camera shake + "DollmakerScream" cue, 2.5s), **`ShiftTimeout`** (**B9**: the watchdog-timeout
  RunEnd's calm "closing time" beat — deliberately NOT a scare: a soft dim + "The shop is closing for
  the night…" text fade, "DoorSlam" cue, no camera shake, no shadow face). Unknown haunt ids: ignore
  silently.
- **DetectorClient** (`DetectorClient.luau`): while local character has the "Spirit Compass" Tool equipped —
  Heartbeat: min distance to GlyphTargets Vector3Values → rattle: Handle vibrate (tiny CFrame jitter via
  a local Motor/weld offset is server-owned; instead jitter a HANDLE HIGHLIGHT + play "DetectorTick" cue at
  rate 0.2–5 Hz by proximity + Handle PointLight brightness). Equipped tool access via Character.ChildAdded.
- **CameraReporter** (`CameraReporter.luau`): stream workspace.CurrentCamera.CFrame via `CameraReport` at
  Config.Tells.WatchReportHz (RenderStepped throttled).
- **PanicEmote** (`PanicEmote.luau`): Features.PanicEmote — a corner 😱 button (+ E key on PC): character
  jumps + camera shake + "PanicBark" cue + a "!!" BillboardGui over head 2s (visible to others? billboard
  created client-side is local-only — acceptable for the beta stub; note it).
- **SoundClient**: not a separate controller — controllers use SoundKit directly.
- **Shop** (`Shop.luau`): coin balance + BUY flow, full-screen panel toggled by
  `ReplicatedStorage.PorcelainOpenPanel:Fire("Shop")` (the canonical cross-controller panel-open
  convention — see below) or `Shop.open()/close()/toggle()`. One card per `Defs/Classes` entry:
  name, description, price, BUY (or EQUIP if owned, or a disabled EQUIPPED pip). Listens
  `CoinsUpdate`, `ClassesData`, closes automatically on any non-`LobbyIdle` `StateChanged`.
- **Classes** (`Classes.luau`): the dedicated, separate class-browsing/EQUIP screen (Animal Hospital
  reference screenshots show this as distinct from the buy-flow Shop) — scrollable list (locked
  classes show a 🔒, Unicode 6.0, safe from B6's tofu-box risk) + a detail pane with description and
  an EQUIP button (reads "BUY IN SHOP" if not owned). Same `PorcelainOpenPanel("Classes")` convention,
  same `ClassesData`/`CoinsUpdate` remotes as Shop — no new remotes needed.
- **Journal** (`Journal.luau`): quest/checklist list with coin rewards, driven by `PlayerStats` +
  pure `Logic/QuestProgress`. Hidden (easter-egg) quests show "???" until their `questFlags` entry is
  set. Claim button fires `ClaimQuest(questId)`; a gold flash + chime plays when a diff against the
  previous `claimedQuestIds` set reveals a newly-claimed id (covers claims that happen while the panel
  is already open). Opens via `PorcelainOpenPanel("Journal")`, `Journal.open()/close()/toggle()`
  (cross-controller export, mirrors `Toast.show`), or the desktop `J` key.
- **InviteButton** (`InviteButton.luau`): native Roblox friend-invite via `SocialService`
  (`CanSendGameInviteAsync` → `PromptGameInvite`, both `Util.safeCall`-wrapped). Wires to any
  `GuiButton` tagged `"InviteButtonTag"` — `LobbyHud`'s Invite button is the real one; an optional
  same-file fallback button ships behind `Config.Features.InviteFallbackButton` (default off). A
  player-initiated native prompt only — nothing sent on anyone's behalf without an explicit tap.
- **JoinSquareUI** (`JoinSquareUI.luau`): bottom-anchored EXIT / SKIP TUTORIAL / START NOW action bar,
  visible only while the local player stands in a `JoinSquareUpdate`-reported occupant list. Skip
  Tutorial's visibility is driven by the real `PlayerStats.tutorialDone` flag (not a stub). Fires
  `JoinSquareAction(squareId, action)`; live countdown text from `JoinSquareCountdown`; plays
  `SquareLockIn` once when the local player's square enters the `"Locking"` phase.
- **LobbyHud** (`LobbyHud.luau`): left-side, bottom-anchored vertical button column — SHOP, INVITE,
  CLASSES, JOURNAL (exact order from the reference screenshots), visible only during `LobbyIdle`. A
  pure `ScreenGui`, not a 3D kiosk — the physical Shop/Classes kiosk `ProximityPrompt`s in the world
  are complementary, not exclusive. Shop/Classes/Journal buttons fire `PorcelainOpenPanel(name)`;
  Invite just tags itself `"InviteButtonTag"` and defers to `InviteButton.luau` (the two tracks that
  originally specced this button independently invented incompatible invite implementations — resolved
  in favor of `InviteButton.luau`'s `SocialService` API, the more current one).
- **`PorcelainOpenPanel`** (`ReplicatedStorage` `BindableEvent`, lazily created client-side by whichever
  controller inits first): the standardized cross-controller "open this panel" convention —
  `Fire(panelName: "Shop" | "Classes" | "Journal")`. Shop/Classes/Journal all listen on this SAME
  bindable; do not invent a second one.

## Payload quick-reference (client⇄server)

- `StateChanged (state: string, data: {shift: number, strikes: number, objective: string})`
- `ShiftData (data: {shift: number, dolls: {{id: string, name: string, variant: number}}, glyphTotal: number})`
- `DollUpdate (dollId: string, update: {careDone: {string}?, done: boolean?, name: string?, ribbon: boolean?, removed: boolean?})`
  — `removed` added by **B8**: fired from `DollService.consume()` so the client checklist stops
  reading a consumed doll as still-in-play.
- `GlyphFound (glyphId: string?, data: {found: {string}, slots: {string?}, finder: string?})`
- `PresenceTier (tier: number)` · `HauntFired (hauntId: string, params: {}?)` — `hauntId` now also
  takes `"ShiftTimeout"` (**B9**, the calm watchdog-timeout closing beat).
- `BanishPrompt (dollId: string?, dollName: string?, extra: {countdown: number?, cancelled: boolean?}?)`
- `BanishResult (data: {correct: boolean, dollId: string, dollName: string, spiritName: string?, strikes: number, incomplete: boolean?})`
  — `incomplete` added by **A4**: true when the banished doll WAS the marked one but its ribbon
  wasn't tied yet (doll survives via `returnToBench`, not consumed).
- `Recap (data: {shiftReached: number, dollsCleared: number, perfect: boolean, traitorName: string, bestShift: number, isNewBest: boolean, reason: "presence" | "watchdog"})`
  — `reason` added by **B9** (recap must not always claim "the Presence got you"); `shiftReached`
  fixed by **B7** to mean "the shift number the player was on when the run ended" (matches the HUD's
  live banner), not `shiftNumber - 1`.
- `Toast (message: string, seconds: number?)` · `ReadyCountdown (seconds: number?)`
- `MinigameStart (dollId, stepId, seed: number, speedMultiplier: number?)` — `speedMultiplier` is the
  SwiftHands class buff (`<1` = faster; `MinigameController`'s `mash`/`hold` games consume it).
  `MinigameCancel (dollId, stepId)`
- Server → Client (Economy / Social / Join Squares — added in the map-redesign batch):
  `CoinsUpdate (coins: number)` — pushed on every balance change + once near PlayerAdded.
  `ClassesData (data: {owned: {[classId]: boolean}, equipped: string})` — pushed per-player on
  join/buy/equip.
  `PlayerStats (stats: DataService.Stats)` — full per-player stats snapshot, fired on load + every
  change; drives Journal's progress bars, JoinSquareUI's Skip Tutorial gate, and (indirectly, via
  ClassService reading the same DataService cache) the lobby billboard's class-name line.
  `JoinSquareUpdate (squareId: string, data: {count: number, max: number, occupantUserIds: {number}, phase: "Idle"|"Waiting"|"Locking"})`
  — fired only when a square's occupant set actually changes.
  `JoinSquareCountdown (squareId: string, secondsLeft: number?)` — mirrors `ReadyCountdown`, `nil` cancels.
- C→S: `RequestMinigame(dollId, stepId)` (optional pre-request; prompt flow may bypass), `MinigameDone(dollId, stepId, success)`,
  `ChooseName(dollId, choiceIndex?, freeText?)`, `PickupDoll(dollId)` *(fired by prompt server-side instead — clients need not send; keep handler tolerant)*,
  `DropDoll()`, `DepositDoll()` *(same note)*, `ConfirmBanish(confirm)`, `SlotGlyph(slotIndex, glyphId?)`,
  `CollectGlyph(tokenId)` *(prompt server-side handles; handler tolerant)*, `TieRibbon(dollId)` *(prompt-driven server-side)*, `Panic()`, `ReadyPad(standing)`, `CameraReport(cframe)`
- Client → Server (Economy / Social / Join Squares): `BuyClass(classId)`, `EquipClass(classId)`,
  `ClaimQuest(questId)`, `JoinSquareAction(squareId: string, action: "Exit" | "StartNow" | "SkipTutorial")`
  (folds three buttons into one remote, mirrors the existing `ConfirmBanish(bool)` idiom; server
  validates the sender is actually an occupant of that square before doing anything).

Where marked *prompt-driven*, the server ProximityPrompt.Triggered is the real path; the remote exists as
a fallback and must validate identically. Prompts are the mobile-native path (plan review).
