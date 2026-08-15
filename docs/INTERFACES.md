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
PresenceService, HauntService, BanishService, LobbyService, ShiftManager, DebugService.

`ctx` (type `any`) fields available to every service after wiring:
```
ctx.services = { MapBuilder=..., DataService=..., WatchService=..., DollService=..., GlyphService=...,
                 TellService=..., PresenceService=..., HauntService=..., BanishService=...,
                 LobbyService=..., ShiftManager=..., DebugService=... }
ctx.manifest  -- MapBuilder's world manifest (below)
ctx.rng       -- Random.new() (Roblox Random; matches Draw.RngLike)
```
Every service module returns a table. `Service.init(ctx)` stores ctx; services call each other ONLY
via `ctx.services.X.fn(...)` at runtime (never `require` another service — prevents cycles).

### MapBuilder — `src/server/Services/MapBuilder.luau`
`MapBuilder.build(): (manifest: any, failures: {string})` — called before init wiring; builds the whole
world under `workspace.PorcelainMap` (a Folder). Each room in its own pcall'd builder function; a
failed room appends its name to `failures` and the rest still build (plan review: one typo can't
blank the world). Low-poly parts + built-in materials only. Rooms & contents:
- **Lobby** (separate area ~200 studs from workshop): floor/walls, `SpawnLocation` (tag `LobbySpawn`, Neutral=true, this is the default spawn), ready-up pad zone part (tag `ReadyPad`, semi-transparent glowing floor circle), leaderboard board (tag `LeaderboardBoard`, SurfaceGui filled by LobbyService), chalkboard (tag `Chalkboard`) with SurfaceGui TextLabels teaching: "1. CARE for every doll 2. WATCH for the wrong one 3. FIND the glyphs, match the ledger 4. BANISH it" + smaller aged note: "...and always tie the silver ribbon before a banishing. Always. — The Dollmaker".
- **Workshop** connected rooms, dim/warm: **Bench room** — long workbench, 5 bench slot markers (invisible parts, tag `BenchSlot`, name BenchSlot1..5, ≥5 studs apart), lamps (PointLight parts, tag `Lamp`), ribbon spool prop on the bench (tag `RibbonSpool`) with ProximityPrompt ActionText "Take Silver Ribbon" (ObjectText "Ribbon Spool"); **Storage alcove** — shelves, spare doll silhouettes (decor); **Ledger desk room** — desk with big book prop (tag `LedgerDesk`) + ProximityPrompt ActionText "Open Ledger"; **Hallway** — doors (tag `HauntDoor`, hinged via CFrame pivot for creak-slam), window panes with moonlight SpotLights (tag `WindowPane`); **Banish room** — the Banish Box: coffin-sized ornate box (Model, tag `BanishBox`, PrimaryPart set) with lid, deposit ProximityPrompt (ActionText "Place the doll inside", Enabled=false until unlocked), all-players-confirm handled by BanishService; detector rack (tag `DetectorRack`) near ledger desk; workshop spawn (SpawnLocation, tag `WorkshopSpawn`, Enabled=false — LobbyService/ShiftManager toggle which spawn is active); workshop entry door (Model, tag `WorkshopDoor`) with a lock billboard ("Shift in progress — Shift N" filled by ShiftManager) that physically blocks entry when locked (CanCollide door slab).
- ≥8 glyph spawn markers spread across ALL workshop rooms (invisible parts, tag `GlyphSpawn`).
- All ProximityPrompts everywhere: `RequiresLineOfSight=false`, `MaxActivationDistance=Config.Care.PromptDistance`, `Exclusivity=Enum.ProximityPromptExclusivity.OnePerButton`.
- Manifest returned: `{ root: Folder, lobbySpawn, workshopSpawn, readyPad, workshopDoor, benchSlots: {BasePart}, glyphSpawns: {BasePart}, banishBox: Model, banishPrompt: ProximityPrompt, detectorRack: BasePart, ledgerDesk: BasePart, ledgerPrompt: ProximityPrompt, ribbonSpool: BasePart, ribbonPrompt: ProximityPrompt, lamps: {BasePart}, hauntDoors: {Model}, windowPanes: {BasePart}, leaderboardBoard: BasePart, chalkboard: BasePart }`.

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
- `consume(dollId)` — doll sinks into banish box / vanishes (tween down + destroy), state removed.
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

### DataService — `src/server/Services/DataService.luau`
R5 exactly. `init(ctx)` probes availability ONCE (pcall GetDataStore + a GetAsync on a probe key, deferred
in task.spawn — never blocks init). Per player: `getStats(player): {bestShift: number, dollsCleared: number,
perfectShifts: number, runs: number, loaded: boolean}` from cache (zeros until async load lands; fire
callback `onStatsLoaded(fn(player, stats))`). `recordRun(player, {shiftReached, dollsCleared, perfect})` —
merge into cache (bestShift=max, sums), mark dirty. Flush: UpdateAsync with merge semantics (max/sums vs
stored — NEVER SetAsync), on PlayerRemoving + BindToClose (flush all, inside the 30s budget) + every 120s
autosave. Retries per Config.Data. Everything pcall'd; failures log once, never throw.

### LobbyService — `src/server/Services/LobbyService.luau`
- Billboards: on every CharacterAdded, BillboardGui on Head (Adornee), two lines "Best Shift: N" /
  "Dolls Cleared: M", MaxDistance Config.Lobby.BillboardMaxDistance, AlwaysOnTop=false; set
  `Humanoid.DisplayDistanceType = None`; update on DataService.onStatsLoaded + after each recordRun.
- Leaderboard board SurfaceGui: top 8 best-shift of players currently in server; refresh on stats
  changes + player add/remove.
- Ready pad: poll workspace:GetPartBoundsInBox over the pad zone 2 Hz for characters; when ≥1 player
  stands on it and state is LobbyIdle → call `ctx.services.ShiftManager.requestStart(playersOnPad)`;
  broadcast `ReadyCountdown` seconds; leaving the pad mid-countdown cancels (ShiftManager owns the countdown,
  LobbyService just reports the standing set each poll via requestStart/updateStanding — see ShiftManager API).
- Spawn management: `setShiftSpawnActive(bool)` — toggles which SpawnLocation is Enabled (workshop during
  ShiftActive so mid-shift respawns land inside — plan review fix).

### ShiftManager — `src/server/Services/ShiftManager.luau`
Owns: state machine, participants (Set<Player>), shiftNumber, strikes, chosen spirit, run stats
(dollsCleared, perfectSoFar, traitorNameLog, closestCall), watchdogs.
States & transitions (broadcast `StateChanged` `{state, shift, strikes, objective}` on every change):
- `LobbyIdle`: workshop door locked. `requestStart(playersOnPad)` begins countdown
  (Config.Lobby.ReadyCountdownSeconds, broadcast `ReadyCountdown`; recall with current standing set each
  poll — empty set cancels, broadcast nil). Countdown end → participants = standing set → `ShiftIntro`.
- `ShiftIntro` (Config.Shift.IntroSeconds): pick spirit (Draw.one of Spirits.list), compute
  `Escalation.forShift(cfgFromConfig, shiftNumber, #participants)`, names = Draw.sample(DollNames, count),
  markedIndex = rng int, DollService.spawnShift, GlyphService.startShift(spirit.code, rng), unlock workshop
  door, teleport participants to workshop spawn (PivotTo), broadcast `ShiftData` `{shift, dolls, glyphTotal}`.
  → `ShiftActive`.
- `ShiftActive`: TellService/PresenceService/HauntService started. Wire DollService.onStepCompleted →
  PresenceService.notifyStepCompleted + objective refresh. When allListedCareDone → PresenceService.
  setAllDollsDone(true) + BanishService.setUnlocked(true) + objective update. PresenceService.onMaxed →
  `RunEnd(scare)`. BanishService resolution → `onBanishResolved(dollId)`:
  correct = (dollId == marked) AND GlyphMatch.matches(spirit.code, GlyphService.getSlots()) AND
  DollService.hasRibbon(dollId). Broadcast `BanishResult` `{correct, dollName, dollId, spiritName?, revealLine,
  strikes}` (spiritName only when correct — wrong banishes don't leak the answer). Correct → `ShiftResult(win)`.
  Wrong → strikes+1, PresenceService.surge(Config.Presence.WrongBanishSurge), DollService.consume(dollId)
  (innocent is gone — review decision), if strikes ≥ Config.Shift.StrikeLimit → `RunEnd(scare)` else stay
  `ShiftActive` (objective: "That wasn't it. Find the REAL one.").
- `ShiftResult` (ResultSeconds): win → dollsCleared += dollCount, shiftNumber += 1, stop tell/haunt/presence,
  DollService.clearShift, GlyphService.stopShift → next `ShiftIntro` (same participants ∩ still-in-server).
- `RunEnd`: stop everything; scare beat: broadcast `HauntFired("DollmakerReveal", {})` (client renders the
  placeholder true-face + shake; lights out via lamp toggle here too), 4s later broadcast `Recap`
  `{shiftReached, dollsCleared, perfect, traitorName (this shift's marked doll name), bestShift, isNewBest}`;
  DataService.recordRun for each participant; teleport everyone to lobby, lock door, reset run state → `LobbyIdle`.
- Watchdogs (R2): every non-idle state arms `task.delay(Config.Shift.Watchdog[state])`; if still in that
  state when it fires → `Util.warn` + broadcast `Toast` ("watchdog: forcing past <state>") + force the
  default transition (ShiftActive's watchdog forces RunEnd).
- Participants: PlayerRemoving prunes; empty participants during any shift state → abort silently to
  `LobbyIdle` (full cleanup, no recap). Mid-shift joiners: NOT added to participants; they stay in lobby
  (door locked) and auto-join at next ShiftIntro IF standing on pad… no — simpler per plan: joiners wait in
  lobby; at `ShiftResult→ShiftIntro` boundary, current lobby players standing on the pad are merged into
  participants. `onBanishResolved`, `requestStart`, `getState()`, `getParticipants()`, `getSpirit()`,
  `getShiftNumber()` are the public API. Objective strings: care remaining ("Care for the dolls — X tasks left") →
  glyphs ("Find the glyphs — X of 3 found") → ledger ("Match the spirit in the ledger") → banish
  ("Bring the wrong doll to the Banish Box"). Recompute + broadcast on every relevant event.
- Debug hooks for DebugService: `debugForceState(name)`, `debugSetShift(n)`, `debugReveal(): {marked, spirit,
  code}`, `debugStrike(delta)`, `debugEndRun()`.

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
  Toast controller owns it — Toast is its own controller; Hud ignores Toast).
- **Toast** (`Toast.luau`): queue of transient bottom-center messages from `Toast` remote (and a local
  `Toast.show(msg)` other controllers may call via a BindableEvent named `PorcelainToast` in
  ReplicatedStorage created lazily client-side — keep simple: export module function; controllers may
  require Toast directly for local toasts).
- **RecapUI** (`RecapUI.luau`): full-screen card on `Recap` payload — shift reached (huge), dolls cleared,
  perfect badge, "The Hollow One was <traitorName>" line, NEW BEST flare, [Return] button (just closes;
  server already teleported). Also renders `BanishResult` staging: on receipt, 0.4s black flash + freeze
  frame vignette + reveal line "<NAME> WAS THE HOLLOW ONE" (correct: gold text + SoundKit "StingReveal";
  wrong: sickly green + "StingWrong"), 3s, then dissolve.
- **DebugOverlay** (`DebugOverlay.luau`): Config.DebugMode only — left panel rendering `DebugInfo`.
- **ErrorPanel** (`ErrorPanel.luau`): Config.DebugMode only — collect last 10 client errors
  (ScriptContext.Error) + server messages via LogService.MessageOut filtered to Error/Warning containing
  "[Porcelain]"… client LogService only sees client logs; server errors arrive via Toast? Keep client-side
  only (last 10 client errors) + note in panel "server errors: see Output". Toggle visible with a small 🐞 button.
- **MinigameController** (`MinigameController.luau`): on `MinigameStart(dollId, stepId, seed)` open the
  minigame for CareSteps.byId[stepId].minigame kind; on finish fire `MinigameDone(dollId, stepId, success)`;
  close on `MinigameCancel`. Implement 4 kinds, all touch-first, each ~Config.Care.StepSeconds:
  `mash` (tap the brush button repeatedly to fill a bar; taps also nudge a hair tangle sprite),
  `hold` (press-and-hold inside a drifting circle — release outside = pause; fill to complete),
  `sequence` (5 paint dots appear in order on a doll face sketch; tap in order; wrong tap = one redo),
  `timing` (a needle sweeps a bar; tap in the green zone 3 times; zone shrinks). All success-only-hard:
  failure just retries within the lock window — the TIME is the cost (Presence keeps filling).
- **NamingUI** (`NamingUI.luau`): first CarePrompt on an unnamed doll ALSO fires… simpler: after
  `ShiftData`, if any doll name is a default AND Features.Naming, show a compact top-half picker once per
  doll when the local player first completes a step on it (track via DollUpdate): 6 random curated names
  as big buttons + shuffle + skip; fires `ChooseName(dollId, choiceIndex)`. (Free text hidden behind
  Features.FreeTextNames=false.)
- **LedgerUI** (`LedgerUI.luau`): opens on ProximityPromptService.PromptTriggered (client-side signal)
  for the LedgerDesk prompt. Book UI: left page lists 6 spirits (name + flavor + its 3 glyph code rendered
  via GlyphRender); right page: 3 slot squares + found-glyph tray (from `GlyphFound` state). Tap glyph →
  tap slot = `SlotGlyph(slotIndex, glyphId)`; tap filled slot clears. Slots shared server-side; live-update
  from `GlyphFound`. Close button. A "MATCHED: <spirit>" banner client-computes via Logic/GlyphMatch for
  feedback (server stays authoritative).
- **BanishConfirmUI** (`BanishConfirmUI.luau`): on `BanishPrompt(dollId, dollName, extra)` show center
  modal "Banish <NAME>?" with CONFIRM / REFUSE, live countdown when `extra.countdown`, close on
  `{cancelled=true}` or `BanishResult`. Fires `ConfirmBanish(bool)`.
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
  with camera shake + "DollmakerScream" cue, 2.5s). Unknown haunt ids: ignore silently.
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

## Payload quick-reference (client⇄server)

- `StateChanged (state: string, data: {shift: number, strikes: number, objective: string})`
- `ShiftData (data: {shift: number, dolls: {{id: string, name: string, variant: number}}, glyphTotal: number})`
- `DollUpdate (dollId: string, update: {careDone: {string}?, done: boolean?, name: string?, ribbon: boolean?})`
- `GlyphFound (glyphId: string?, data: {found: {string}, slots: {string?}, finder: string?})`
- `PresenceTier (tier: number)` · `HauntFired (hauntId: string, params: {}?)`
- `BanishPrompt (dollId: string?, dollName: string?, extra: {countdown: number?, cancelled: boolean?}?)`
- `BanishResult (data: {correct: boolean, dollId: string, dollName: string, spiritName: string?, strikes: number})`
- `Recap (data: {shiftReached: number, dollsCleared: number, perfect: boolean, traitorName: string, bestShift: number, isNewBest: boolean})`
- `Toast (message: string, seconds: number?)` · `ReadyCountdown (seconds: number?)`
- `MinigameStart (dollId, stepId, seed: number)` · `MinigameCancel (dollId, stepId)`
- C→S: `RequestMinigame(dollId, stepId)` (optional pre-request; prompt flow may bypass), `MinigameDone(dollId, stepId, success)`,
  `ChooseName(dollId, choiceIndex?, freeText?)`, `PickupDoll(dollId)` *(fired by prompt server-side instead — clients need not send; keep handler tolerant)*,
  `DropDoll()`, `DepositDoll()` *(same note)*, `ConfirmBanish(confirm)`, `SlotGlyph(slotIndex, glyphId?)`,
  `CollectGlyph(tokenId)` *(prompt server-side handles; handler tolerant)*, `TieRibbon(dollId)` *(prompt-driven server-side)*, `Panic()`, `ReadyPad(standing)`, `CameraReport(cframe)`

Where marked *prompt-driven*, the server ProximityPrompt.Triggered is the real path; the remote exists as
a fallback and must validate identically. Prompts are the mobile-native path (plan review).
