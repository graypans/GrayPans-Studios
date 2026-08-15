# Packet 1 — Lobby Systems (Coins/Classes/Shop, Journal/Quests, Join Squares)

Source: 3 independent agents, each assigned one track (Economy, Social, Join Squares), each told the
same shared brief (the team's Animal-Hospital-style lobby description) but unable to see each other's
output. Produced 2026-08-15 for `CHECKLIST_1.md` §2/§O4. **No code in this file has been applied to
the repo** — everything below is a spec for the cloud Claude session to review and implement.

All three tracks independently proved thorough enough to catch real conflicts with each other's
(invisible-to-them) work. Read the section below **before** implementing anything in this packet.

---

## READ THIS FIRST — integration conflicts between the 3 tracks

### 1. `DataService.luau` — two independent full-file rewrites need merging into one

Both the Economy track and the Social track propose a **full replacement** of
`src/server/Services/DataService.luau`, each adding different new fields:

- **Economy's version** adds: `coins: number` (sum-merge), `ownedClasses: {[string]: boolean}`
  (union-merge), `equippedClass: string` (last-write-wins). Also adds `DataService.addCoins`,
  `spendCoins`, `grantClassOwnership`, `setEquippedClass`, and a `CoinsUpdate` remote push on load.
- **Social's version** adds: `coins: number` (sum-merge — **same field, same merge rule, this one is
  compatible**), `ribbonsTiedTotal: number` (sum-merge), `tutorialDone: boolean` (OR-merge),
  `claimedQuestIds: {[string]: boolean}` (union-merge), `questFlags: {[string]: boolean}`
  (union-merge). Also adds `DataService.addCoins` (**same name, compatible signature**),
  `addRibbonTied`, `setTutorialDone`, `setQuestFlag`, `markQuestClaimed`. Also fixes a real latent bug:
  the existing `flushPlayer` early-return gate (`if delta.runs == 0 and delta.bestShift == 0 then
  return end`) would silently skip flushing a player whose only changes were coin/ribbon/quest
  updates — Social's version replaces it with an explicit `dirty: {[Player]: boolean}` table.

**Both agents independently flagged this exact collision themselves** ("needs human reconciliation to
one canonical field," "the human integrator should reconcile ... before handing off to cloud Claude").

**What to do:** write ONE final `DataService.luau` containing the union of every field from both
lists above (`coins`, `ownedClasses`, `equippedClass`, `ribbonsTiedTotal`, `tutorialDone`,
`claimedQuestIds`, `questFlags`), ONE `addCoins` function (the two proposed signatures are
compatible — Economy's clamps the balance to never go below 0 via `math.max(amount, -stats.coins)`,
which is the safer of the two and should win), all public functions from both lists, and Social's
`dirty`-table fix to `flushPlayer`'s gating (a real correctness fix, keep it regardless of which
version of the file you start from). Both full-file listings are below in §1/§2 of the two tracks —
diff them side by side rather than applying either wholesale.

### 2. `ShiftManager.luau` — FOUR different contributors touch the same functions

In addition to `PACKET_1_PATCHES.md`'s own internal merge (P2 + P3, covered in that document's
"READ THIS FIRST" section), **this packet's three tracks add a third and fourth layer on top**:

- **Economy** inserts: (a) `ShiftIntro` branch — `coinAwardedDolls = {}` reset + `shiftParams.classBuffs
  = ClassService.applyBuffs(...)`; (b) inside the existing `DollService.onStepCompleted` callback
  (registered in `ShiftManager.init`) — a per-doll coin award; (c) `onBanishResolved`'s `correct`
  branch — a perfect/late-shift coin bonus, inserted **before** `shiftNumber += 1`; (d) the strike-limit
  check (`if strikes >= Config.Shift.StrikeLimit then`) extended with `+ (shiftParams.classBuffs and
  shiftParams.classBuffs.strikeLimitBonus or 0)`.
- **Social** inserts: inside `onBanishResolved`'s `correct` branch — a `shiftClearedCallbacks` loop,
  inserted **after** the `runStats.perfect` bump and **before** `shiftNumber += 1` — i.e. the *same*
  neighborhood as Economy's (c) above. Also adds `ShiftManager.onShiftCleared(fn)` as new public API.
- **Join Squares** inserts: a brand-new `ShiftManager.beginShiftFor(occupants)` function (does not
  touch any existing function — safe, additive), and replaces the `RunEnd` branch's unconditional
  `teleportTo(ctx.manifest.lobbySpawn, participants)` with a `ServerKind.isReservedShiftServer()`
  branch that calls `JoinSquareService.sendGroupHome(participants)` instead when running in a live
  reserved shift server.

**Correct final order inside `onBanishResolved`'s `correct` branch** (all four contributors' pieces,
assembled — this is the one function every track touches):

```lua
	if correct then
		DollService.consume(dollId)
		Remotes.get(Remotes.Names.BanishResult):FireAllClients({ correct = true, dollId = dollId, dollName = dollName, spiritName = spirit.name, strikes = strikes })
		runStats.dollsCleared += shiftParams.dollCount
		if runStats.strikesThisShift == 0 then
			runStats.perfect += 1
		end
		-- Social: onShiftCleared hook (participants snapshot BEFORE shiftNumber increments)
		pruneParticipants()
		for _, cb in shiftClearedCallbacks do
			Util.safeCall("shiftClearedCallback", cb, table.clone(participants), shiftNumber)
		end
		-- Economy: perfect-shift + late-shift coin bonus (uses PRE-increment shiftNumber = the
		-- shift that was just cleared)
		local lateBonusShifts = math.min(shiftNumber - 1, Config.Economy.LateShiftBonusCapShifts)
		local flatBonus = (if runStats.strikesThisShift == 0 then Config.Economy.PerfectShiftBonus else 0)
			+ lateBonusShifts * Config.Economy.LateShiftBonusPerShift
		if flatBonus > 0 then
			for _, participant in participants do
				local mult = ctx.services.ClassService.getCoinMultiplier(participant)
				ctx.services.DataService.addCoins(participant, math.floor(flatBonus * mult))
			end
		end
		shiftNumber += 1
		transition("ShiftResult")
		return
	end
```

And the strike-limit check (also inside `onBanishResolved`, the wrong-doll path — see
`PACKET_1_PATCHES.md`'s A4 fix for the surrounding code) becomes:

```lua
	if strikes >= Config.Shift.StrikeLimit + (shiftParams.classBuffs and shiftParams.classBuffs.strikeLimitBonus or 0) then
		transition("RunEnd")
```

The `ShiftIntro` branch (Economy's classBuffs line) and the `RunEnd` branch (Join Squares'
teleport-vs-sendGroupHome swap) don't collide with anything else and can be inserted at the exact
points each track's own section describes below, on top of `PACKET_1_PATCHES.md`'s already-merged
base.

**Net effect: `ShiftManager.luau` needs ONE deliberate, careful pass touching `transition()`
(3 branches), `onBanishResolved()`, `armWatchdog()`, and `init()`, folding in P2 + P3 from
`PACKET_1_PATCHES.md` and Economy + Social + Join-Squares from this packet — 5 independent sources
in total. Do not apply any of them as sequential full-file pastes.**

### 3. Panel-open interop: two different, incompatible conventions were invented

- **Economy's `Shop.luau`** listens for a no-argument `ReplicatedStorage.PorcelainOpenShop`
  `BindableEvent`.
- **Join Squares' `LobbyHud.luau`** (the actual left-nav HUD button bar) fires
  `ReplicatedStorage.PorcelainOpenPanel:Fire("Shop" | "Classes" | "Journal")` — a *different* bindable
  name, with an argument.
- **Social's `Journal.luau`** exposes `Journal.open()`/`.close()`/`.toggle()` as a direct
  `require()`-able API (mirroring `Toast.show()`), and separately says the HUD should call
  `Journal.open()` directly — a third, incompatible pattern from the same packet.

**Recommendation: standardize on Join Squares' `PorcelainOpenPanel(panelName)` convention**, since it's
the one actually built into the real HUD button bar (3 of the button bar's 4 buttons already fire it)
and it scales to more panels later without new bindable names. Concretely:
- Change `Shop.luau` to listen on `ReplicatedStorage:WaitForChild("PorcelainOpenPanel").Event` and
  check `panelName == "Shop"`, not `PorcelainOpenShop`.
- Change `Journal.luau` to also listen on `PorcelainOpenPanel` and check `panelName == "Journal"`
  (in addition to keeping its own `.open()`/`.close()`/`.toggle()` exports, which are harmless to
  keep for other callers, e.g. the desktop `J` keyboard shortcut it already wires).
- **RESOLVED 2026-08-15 — team confirmed a separate Classes screen** after reviewing the actual
  Animal Hospital reference screenshots (the Drive folder was private when this packet was first
  drafted; it's now shared). The reference shows Classes as a genuinely distinct screen from Shop —
  a scrollable list of every class (locked ones greyed with a padlock icon, the equipped one
  highlighted) next to a preview/description pane and an Equip button — not a buy-flow. `Shop.luau`
  (§6 below) stays the BUY surface exactly as already specced (no changes needed to it — letting it
  also equip is harmless redundancy, not a conflict). **New: Track A §6b below adds a dedicated
  `Classes.luau` client Controller** styled after that reference layout, reusing the exact same
  `ClassesData`/`CoinsUpdate` remotes Shop.luau already uses — no new remotes needed. `LobbyHud.luau`
  (Track C §5) keeps all 4 buttons, restored to the team's own original order — **Shop, Invite,
  Classes, Journal** — which also matches the reference screenshots exactly.

### 3a. What the reference screenshots additionally showed (folded in below; bigger items deliberately deferred)

Reviewed 2026-08-15, all 9 screenshots. Cheap, concrete details already folded into this packet:
- Join squares are **hollow neon diamond outlines** (a rotated square wireframe, not a filled tile) —
  idle/empty = cyan-blue, occupied = yellow, with a plain "N/4" label floating above. Noted in
  `PACKET_1_MAP_DESIGN.md`'s addendum and Track C §1/§4 below.
- The bottom join-square action bar is exactly **EXIT (red) / Skip Tutorial (greyed out, visibly
  disabled when locked) / START NOW (green)**, left to right — matches `JoinSquareUI.luau`'s button
  order in §4 below; color specifics noted there.
- Shop and Classes are ALSO physical round-glow `ProximityPrompt` kiosks in the world near the
  spawn/parking area (each with a floating name label and an "[E] Open Shop"-style prompt), in
  addition to the HUD buttons — confirms the `ShopKiosk`/`ClassesKiosk` world-prop tags already
  planned in `PACKET_1_MAP_DESIGN.md` are worth keeping, not redundant with the HUD.
- Two SEPARATE leaderboard boards flank the reference hub's dead-end (one titled "Patients Treated"
  — our `dollsCleared`, one titled "Highest Shift" — our `bestShift`), not one combined board. See
  `PACKET_1_MAP_DESIGN.md`'s addendum for the map-side note and `PACKET_1_PATCHES.md`'s B1 section
  for the `LobbyService.refreshLeaderboard` follow-up note.
- Per-player billboards show "Top Shift: N" plus the player's **currently equipped class name**
  underneath, in place of a second numeric stat. Small, cheap, high-value addition — see the
  `LobbyService` integration note under Track A §6b below.

**Deliberately NOT folded in — bigger mechanic, flagging as a CHECKLIST_2 candidate, not part of this
batch:** the reference's actual Classes screen also shows each class has its own **outfit/visual skin**
(the preview pane renders the character wearing it) and a **per-class level/XP progression** (Lv.1/2/3
tabs, each unlocking a bigger version of the same buff, e.g. "Lv.2: start with 15 bonus sanity"), plus
a separate top-level "Skins" tab entirely apart from Classes. The team's own original text description
of classes ("buy with coins, equip one, it just gives a passive buff like extra sanity or extra money")
matches the simpler single-tier system already fully specced in this packet, which is what's shipping
in this batch. The richer leveling/outfit/skins system is real, proven-fun, and worth doing — but it's
a materially bigger scope (per-class XP tracking, outfit assets, a Skins economy) than what was briefed
here, so it's flagged for a future checklist rather than silently built now.

### 4. `DollService.luau` — 3 additive edits, apply together

- **A4 patch** (`PACKET_1_PATCHES.md`) adds `DollService.returnToBench(dollId)`.
- **Economy** adds `DollService.giveRibbon(player)` (for the `StartWithRibbon` class buff).
- **Social** adds a `ribbonCallbacks` list + `DollService.onRibbonTied(fn)`, plus a 2-line insertion
  into the existing `tieRibbon` function to fire those callbacks.

These three are independent, non-overlapping additions to different parts of the file — no real
conflict, just apply all three in one pass rather than three separate diffs against a file that keeps
shifting line numbers.

### 5. Join Squares' `SkipTutorial` action references a service that doesn't exist as specced

`JoinSquareService.onJoinSquareAction`'s `"SkipTutorial"` branch calls
`ctx.services.TutorialService.setSkipped(player)` — but no track in this packet builds a
`TutorialService`. The Social track's tutorial-gate design (§6 of that track, below) deliberately
recommends **not** building a separate skippable tutorial at all — just guided one-time hints on shift
1, suppressed once `stats.tutorialDone` is true. Given that design, there is no separate "tutorial
flow" to skip, which raises a real question for the team: **does a "Skip Tutorial" button make sense
at all under the Social track's recommended design?**

Two ways to resolve this (team's call):
- (a) **Keep the button, repurpose it.** Since `tutorialDone` already gates the button's visibility in
  `JoinSquareUI.luau` (it only shows once `stats.tutorialDone == true`), and a player only reaches
  that state by already having completed shift 1's hints once, the button is arguably redundant —
  hints won't show again regardless. Consider removing the button entirely and simplifying
  `JoinSquareUI.luau`.
- (b) **Build a real skip.** Add a `skipHints: boolean` per-player flag (new `DataService` field, same
  merge-rule shape as `tutorialDone`) that the guided-hint code checks alongside `shiftNumber == 1`,
  and wire `JoinSquareService`'s `SkipTutorial` action to set it via `DataService.setSkipHints(player)`
  (or fold into `QuestService`, which already owns the tutorial-gate wiring in the Social track).

If the team picks (b), the exact wiring is: `JoinSquareService.onJoinSquareAction`'s `SkipTutorial`
branch should call into `QuestService` (which the Social track builds and which already owns
`Config.Features.TutorialGate`), not a nonexistent `TutorialService` — rename that call site
accordingly whichever way the team decides.

---

## Track A — Economy: Coins + Classes + Shop

**Scope of this section:** the earned-coin currency, the persisted per-player coin/class data, the coin-award wiring into `ShiftManager`'s existing win-path, the purchasable-class roster (`Defs/Classes.luau`), the new `ClassService.luau`, the new `Shop.luau` client Controller, and the Remotes/Config additions all of that needs. This does **not** cover the join-squares/private-shift-instance flow, the left-side HUD shell itself, Invite, or the Journal/quest system — those are other sections of this packet (see the integration notes above for exactly where they connect).

Grounded against the current repo: `src/server/Services/DataService.luau`, `src/server/Services/ShiftManager.luau`, `src/server/Services/DollService.luau`, `src/shared/Remotes.luau`, `src/shared/Config.luau`, `src/shared/Defs/Tells.luau` / `Haunts.luau`, `src/client/Theme.luau`, `src/client/Controllers/RecapUI.luau` / `LedgerUI.luau`, `src/shared/SoundConfig.luau` / `SoundKit.luau`, `docs/INTERFACES.md`, `PLAN.md` §3 (R1–R8), `MASTER.md` §3.3/3.4.

### 1. Data model (extend `DataService.luau`)

**See "READ THIS FIRST" §1 above — this section's `DataService` changes must be merged with the
Social track's, not applied as an independent full-file replacement.**

Three new fields on the persisted `Stats` record, three different merge rules:

| Field | Type | Merge rule | Why |
|---|---|---|---|
| `coins` | `number` | **SUM** (existing pattern) | Same shape as `dollsCleared`/`runs`, but deltas can be *negative* (spending). |
| `ownedClasses` | `{[classId: string]: true}` | **UNION per key** (NEW) | Ownership only ever grows. |
| `equippedClass` | `string` | **LAST-WRITE-WINS** (NEW) | A preference, not fairness-critical. |

**On the `coins` sum-merge generalization:** existing counters only ever increase; `coins` breaks that assumption because spending is a **negative** delta. This still works correctly under sum-merge as long as `cache[player].coins` is always the authoritative *current balance*, `sessionDelta[player].coins` always tracks the *net* change since the last flush, and **every** coin mutation routes through `DataService.addCoins`/`spendCoins` so nothing bypasses delta tracking.

#### 1.1 Stats type + defaults

```lua
type Stats = {
	bestShift: number,
	dollsCleared: number,
	perfectShifts: number,
	runs: number,
	coins: number, -- NEW
	ownedClasses: { [string]: boolean }, -- NEW: classes with price > 0 this player has bought. Free classes (price == 0) are never stored here — ClassService treats price<=0 as always-owned.
	equippedClass: string, -- NEW: currently-active class id; "" / unrecognized / not-owned all fall back to the free starter class at read time
	loaded: boolean,
}

local function defaultStats(): Stats
	return {
		bestShift = 0,
		dollsCleared = 0,
		perfectShifts = 0,
		runs = 0,
		coins = 0,
		ownedClasses = {},
		equippedClass = "",
		loaded = false,
	}
end
```

`DataService.luau` also needs a new require at the top: `local Remotes = require(Shared:WaitForChild("Remotes")) :: any`.

#### 1.2 `loadPlayer` — parse the new fields + push an initial balance

Fires `CoinsUpdate` immediately so the Shop/HUD have *something* to show without waiting on the DataStore round-trip (R5), mirroring the exact late-joiner resend pattern `ShiftManager.init` already uses for `StateChanged`:

```lua
local function loadPlayer(player: Player)
	cache[player] = defaultStats()
	sessionDelta[player] = {
		dollsCleared = 0, perfectShifts = 0, runs = 0, bestShift = 0,
		coins = 0, -- NEW: signed net delta (earn positive, spend negative) since last flush
		newlyOwnedClasses = {}, -- NEW: set of classIds bought this session, not yet flushed
		equippedClassDirty = false, equippedClass = "", -- NEW: last-write-wins scalar
	}

	Remotes.get(Remotes.Names.CoinsUpdate):FireClient(player, cache[player].coins)
	task.delay(3, function()
		if player.Parent and cache[player] then
			Remotes.get(Remotes.Names.CoinsUpdate):FireClient(player, cache[player].coins)
		end
	end)

	if not available then
		return
	end
	task.spawn(function()
		for attempt = 1, Config.Data.ReadRetries do
			local ok, result = pcall(function()
				return store:GetAsync(keyFor(player))
			end)
			if ok then
				local stats = cache[player]
				if stats and typeof(result) == "table" then
					stats.bestShift = tonumber(result.bestShift) or 0
					stats.dollsCleared = tonumber(result.dollsCleared) or 0
					stats.perfectShifts = tonumber(result.perfectShifts) or 0
					stats.runs = tonumber(result.runs) or 0
					stats.coins = tonumber(result.coins) or 0 -- NEW
					stats.ownedClasses = if typeof(result.ownedClasses) == "table" then result.ownedClasses else {} -- NEW
					stats.equippedClass = if typeof(result.equippedClass) == "string" then result.equippedClass else "" -- NEW
				end
				if stats then
					stats.loaded = true
					Remotes.get(Remotes.Names.CoinsUpdate):FireClient(player, stats.coins) -- NEW: correct the pre-load guess
					for _, cb in loadedCallbacks do
						Util.safeCall("statsLoaded", cb, player, stats)
					end
				end
				return
			end
			task.wait(Config.Data.RetryBackoffSeconds * attempt)
		end
		Util.warn("DataService: load failed for " .. player.Name .. " (memory-only this session)")
	end)
end
```

#### 1.3 New public API on `DataService`

```lua
-- Signed delta: positive = earn, negative = spend. Clamps so the balance never goes below 0.
function DataService.addCoins(player: Player, amount: number): number
	local stats = cache[player]
	local delta = sessionDelta[player]
	if not stats or not delta then
		return 0
	end
	local applied = math.max(amount, -stats.coins)
	stats.coins += applied
	delta.coins += applied
	Remotes.get(Remotes.Names.CoinsUpdate):FireClient(player, stats.coins)
	for _, cb in loadedCallbacks do
		Util.safeCall("statsChanged", cb, player, stats)
	end
	return stats.coins
end

-- Server-authoritative spend: fails closed (false) if the player can't afford it.
function DataService.spendCoins(player: Player, amount: number): boolean
	local stats = cache[player]
	if not stats or amount <= 0 or stats.coins < amount then
		return false
	end
	DataService.addCoins(player, -amount)
	return true
end

function DataService.grantClassOwnership(player: Player, classId: string)
	local stats = cache[player]
	local delta = sessionDelta[player]
	if not stats or not delta or stats.ownedClasses[classId] then
		return
	end
	stats.ownedClasses[classId] = true
	delta.newlyOwnedClasses[classId] = true
end

function DataService.setEquippedClass(player: Player, classId: string)
	local stats = cache[player]
	local delta = sessionDelta[player]
	if not stats or not delta then
		return
	end
	stats.equippedClass = classId
	delta.equippedClassDirty = true
	delta.equippedClass = classId
end
```

#### 1.4 `flushPlayer` — needs care around concurrent mid-flight mutations

**Why this needs care, not just "add two fields to the returned table":** `UpdateAsync`'s transform function can yield internally, and other coroutines on the same server (e.g. a `BuyClass` handler) run concurrently while it's yielded. The existing numeric counters dodge this because their delta always resets to `0` after a flush. A **set**-valued delta (`newlyOwnedClasses`) can't be blindly wiped the same way: if you snapshot-then-clear-the-whole-table, a class bought *during* the in-flight `UpdateAsync` call gets silently dropped. The fix: snapshot only what you're about to send, and after a successful flush, clear only those specific keys.

```lua
local function flushPlayer(player: Player)
	if not available then
		return
	end
	local delta = sessionDelta[player]
	if not delta then
		return
	end
	local hasNumericDelta = delta.runs ~= 0 or delta.bestShift ~= 0 or delta.coins ~= 0
	local ownedSnapshot = table.clone(delta.newlyOwnedClasses)
	local hasOwnedDelta = next(ownedSnapshot) ~= nil
	local equipDirty = delta.equippedClassDirty
	local equipSnapshot = delta.equippedClass
	if not hasNumericDelta and not hasOwnedDelta and not equipDirty then
		return
	end
	local snapshot = {
		bestShift = delta.bestShift,
		dollsCleared = delta.dollsCleared,
		perfectShifts = delta.perfectShifts,
		runs = delta.runs,
		coins = delta.coins,
	}
	local ok = pcall(function()
		store:UpdateAsync(keyFor(player), function(old: any)
			old = if typeof(old) == "table" then old else {}
			local mergedOwned = if typeof(old.ownedClasses) == "table" then table.clone(old.ownedClasses) else {}
			for classId in ownedSnapshot do
				mergedOwned[classId] = true
			end
			return {
				bestShift = math.max(tonumber(old.bestShift) or 0, snapshot.bestShift),
				dollsCleared = (tonumber(old.dollsCleared) or 0) + snapshot.dollsCleared,
				perfectShifts = (tonumber(old.perfectShifts) or 0) + snapshot.perfectShifts,
				runs = (tonumber(old.runs) or 0) + snapshot.runs,
				coins = (tonumber(old.coins) or 0) + snapshot.coins,
				ownedClasses = mergedOwned,
				equippedClass = if equipDirty then equipSnapshot else (old.equippedClass or ""),
			}
		end)
	end)
	if ok then
		local d = sessionDelta[player]
		if d then
			d.dollsCleared = 0
			d.perfectShifts = 0
			d.runs = 0
			d.coins = 0
			for classId in ownedSnapshot do
				d.newlyOwnedClasses[classId] = nil -- only clear what THIS flush actually sent
			end
			if equipDirty and d.equippedClass == equipSnapshot then
				d.equippedClassDirty = false -- only clear if nothing newer landed mid-flight
			end
		end
	else
		Util.warn("DataService: flush failed for " .. player.Name)
	end
end
```

No changes needed to `DataService.getStats`, `init`, `recordRun`, `onStatsChanged`, the `BindToClose`/autosave loop, or the DataStore-unavailable fallback.

**Studio-testing note:** no `TeleportService` dependency at all — pure remotes + in-memory cache + `UpdateAsync`. Inherits `DataService`'s existing R5 Studio fallback (memory-only, no persistence across Play sessions in Studio — same as `bestShift`/`dollsCleared` today). **Cross-universe warning worth flagging now:** coin/class persistence is keyed by `UserId` at the DataStore level, which carries over correctly between the lobby and a private shift server **as long as both run in the same Roblox experience/universe**. If the join-square track's private shift instances ever turn out to be a *separate published experience* rather than a reserved server of the same place, DataStores do **not** share across universes and this whole section would need `MessagingService`/`MemoryStore` instead. (Track C below resolves this by recommending a single Place + `TeleportService:ReserveServer`, which keeps everything in one universe — confirms this concern is moot if that recommendation is followed.)

### 2. Coin awards — where and how much

#### 2.1 Recommended defaults

| Award | Amount | When |
|---|---|---|
| Per doll successfully cared for | **7 coins** (DEFAULT) | The instant that doll's 5 listed care steps all complete — mid-shift, not gated on the eventual banish being correct |
| Perfect-shift bonus | **+15 coins** (DEFAULT) | Once, when a shift resolves with a *correct* banish and zero strikes that shift |
| Late-shift bonus | **+3 coins per shift number above 1, capped at shift 6** (DEFAULT, max +15) | Same moment as the perfect-shift bonus |

**Rationale for 7 (middle of the team's 5–10 range):** at 5, a solo 3-doll shift earns only 15 coins before bonuses — 10+ shifts to afford a 100-200 coin class. At 10, a 5-doll multiplayer shift earns 50 coins from care alone, undercutting the bonuses as an incentive. 7 keeps a solo shift-1 clear at `3×7 + 15 = 36` coins, and a late multiplayer shift at `5×7 + 15 + 15 = 65` coins — a 100-coin class reachable in 2–3 shifts either way.

**Why award to every current participant, not just whoever finished the last step:** care is explicitly co-op. Paying only the "finishing" step's player would make coin income depend on who happened to tap last — unfair and easily exploited. This mirrors what `ShiftManager.RunEnd` already does for `dollsCleared`/`recordRun`. **Judgment call, flagged for the team to override if they'd rather split by individual contribution.**

#### 2.2 Exact wiring into `ShiftManager.luau`

**See "READ THIS FIRST" §2 above for the exact merged insertion order relative to the Social and Join
Squares tracks — the pieces below are correct in isolation but must land together with those two.**

**(a) New module-local**, next to the existing ones:
```lua
local coinAwardedDolls: { [string]: boolean } = {} -- reset each ShiftIntro; guards against double-award per doll
```

**(b) `ShiftIntro` branch** — reset the guard and fold class buffs into `shiftParams`:
```lua
		runStats.strikesThisShift = 0
		coinAwardedDolls = {} -- NEW
		spirit = Draw.one(ctx.rng, Spirits.list)
		shiftParams = Escalation.forShift(escalationCfg, shiftNumber, #participants)
		shiftParams.classBuffs = ctx.services.ClassService.applyBuffs(shiftParams, participants) -- NEW
		local names = Draw.sample(ctx.rng, DollNames, shiftParams.dollCount)
```

**(c) `onStepCompleted` hook in `ShiftManager.init`** — award per-doll coins the moment a doll's chain finishes:
```lua
	ctx.services.DollService.onStepCompleted(function(_player: Player, dollId: string, stepId: string)
		ctx.services.PresenceService.notifyStepCompleted()
		if state == "ShiftActive" and not coinAwardedDolls[dollId] and ctx.services.DollService.nextStepFor(dollId) == nil then -- NEW
			coinAwardedDolls[dollId] = true
			for _, participant in participants do
				local mult = ctx.services.ClassService.getCoinMultiplier(participant)
				ctx.services.DataService.addCoins(participant, math.floor(Config.Economy.CoinsPerDoll * mult))
			end
		end
		if state == "ShiftActive" and ctx.services.DollService.allListedCareDone() then
			ctx.services.PresenceService.setAllDollsDone(true)
			ctx.services.BanishService.setUnlocked(true)
		end
		broadcastState()
	end)
```

**(d)/(e)** — see the assembled `onBanishResolved`/strike-limit code in "READ THIS FIRST" §2 above.

### 3. `src/shared/Defs/Classes.luau` (new file, full code)

```lua
--!strict
-- Purchasable classes. Bought with coins in the lobby Shop; exactly one equipped at a time.
-- Each class grants ONE passive buff, applied for the wearer's next shift (ClassService.applyBuffs,
-- called once at ShiftIntro).

export type BuffKind =
	"None"
	| "CareSpeedMultiplier" -- <1 = faster care minigames (0.85 = 15% faster)
	| "ExtraStrike" -- +N to that shift's effective strike limit (shared across the whole group)
	| "TellDurationMultiplier" -- >1 = tells (real + fake) linger longer before resetting (shared, shift-wide)
	| "StartWithRibbon" -- wearer starts the shift already holding a silver ribbon
	| "CoinMultiplier" -- multiplies THIS player's coin awards for the shift (1.25 = +25%)

export type ClassBuff = {
	kind: BuffKind,
	value: number?,
}

export type ClassDef = {
	id: string,
	name: string,
	price: number, -- coins; 0 = free starter, always owned
	description: string, -- one line, shown on the Shop card
	buff: ClassBuff,
}

local Classes: { ClassDef } = {
	{
		id = "Starter",
		name = "Apprentice",
		price = 0,
		description = "Steady hands, no tricks. The Dollmaker's first lesson.",
		buff = { kind = "None" },
	},
	{
		id = "RibbonReady",
		name = "Ribbon-Ready",
		price = 100,
		description = "You start every shift already holding a silver ribbon.",
		buff = { kind = "StartWithRibbon" },
	},
	{
		id = "SwiftHands",
		name = "Swift Hands",
		price = 120,
		description = "Care minigames run 15% faster.",
		buff = { kind = "CareSpeedMultiplier", value = 0.85 },
	},
	{
		id = "KeenEye",
		name = "Keen Eye",
		price = 140,
		description = "Tells linger 50% longer before they reset.",
		buff = { kind = "TellDurationMultiplier", value = 1.5 },
	},
	{
		id = "SteadyNerves",
		name = "Steady Nerves",
		price = 150,
		description = "Your group can take one extra wrong banish before the night ends.",
		buff = { kind = "ExtraStrike", value = 1 },
	},
	{
		id = "PennyPincher",
		name = "Penny-Pincher",
		price = 200,
		description = "Earn 25% more coins this shift.",
		buff = { kind = "CoinMultiplier", value = 1.25 },
	},
}

local byId: { [string]: ClassDef } = {}
for _, def in Classes do
	byId[def.id] = def
end

return {
	list = Classes,
	byId = byId,
	starterId = "Starter",
}
```

**On the two buffs that reach into services this section doesn't own** (`CareSpeedMultiplier`, `TellDurationMultiplier`): they're included in the launch roster because the team explicitly asked for "faster care minigames" and "longer-lasting tells" as example buffs, but *consuming* them requires small touches in `DollService.luau`/`MinigameController.luau` and `TellService.luau`/`DollService.performTell`. `ClassService.applyBuffs` (§4) computes and returns these multipliers regardless — if those other files aren't wired to read them, the buffs simply no-op safely. Follow-ups for whoever touches those files:
- `DollService`: when firing `MinigameStart(dollId, stepId, seed)`, look up the acting player's multiplier and add it as an optional 4th arg (`speedMultiplier: number?`) for `MinigameController` to apply.
- `TellService`/`DollService.performTell`: the per-motion durations are shift-wide (all watchers see the same tell), so `shiftParams.classBuffs.tellDurationMultiplier` (most-generous-wins) just multiplies the hardcoded durations.

`ExtraStrike` and `StartWithRibbon` are fully wired below with no dependency on other sections' files.

### 4. `src/server/Services/ClassService.luau` (new file, full code)

Ownership + equip state lives in `DataService` (single source of truth); `ClassService` is the validation/business-logic layer plus the buff-folding hook `ShiftManager` calls at `ShiftIntro`.

**R1 (solo):** `applyBuffs` and every award loop iterate `participants`, valid at length 1.
**R6 (no free physics):** zero world `Instance`s, zero physics — pure data + two remotes.

```lua
--!strict
-- Purchasable classes: ownership + one-equipped-at-a-time model + buff folding into shift params.
-- Persistence lives in DataService (R5); this service is validation + the buff-application hook
-- ShiftManager calls once per ShiftIntro.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Util = require(Shared:WaitForChild("Util")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local Classes = require(Shared:WaitForChild("Defs"):WaitForChild("Classes")) :: any

local ClassService = {}

local ctx: any

local function starterId(): string
	return Classes.starterId
end

local function ownedSet(player: Player): { [string]: boolean }
	local stats = ctx.services.DataService.getStats(player)
	return stats.ownedClasses or {}
end

function ClassService.isOwned(player: Player, classId: string): boolean
	local def = Classes.byId[classId]
	if not def then
		return false
	end
	if def.price <= 0 then
		return true -- free classes are always owned; never persisted as "owned"
	end
	return ownedSet(player)[classId] == true
end

function ClassService.getEquippedId(player: Player): string
	local stats = ctx.services.DataService.getStats(player)
	local id = stats.equippedClass
	if typeof(id) ~= "string" or id == "" or not Classes.byId[id] then
		return starterId()
	end
	if not ClassService.isOwned(player, id) then
		return starterId() -- defensive: should not happen, but never equip something not owned
	end
	return id
end

function ClassService.getEquippedBuff(player: Player): any
	local def = Classes.byId[ClassService.getEquippedId(player)]
	return (def and def.buff) or Classes.byId[starterId()].buff
end

-- Convenience read used at every coin-award call site so award code never has to know about buff
-- "kind" strings.
function ClassService.getCoinMultiplier(player: Player): number
	local buff = ClassService.getEquippedBuff(player)
	if buff.kind == "CoinMultiplier" then
		return buff.value or 1
	end
	return 1
end

local function pushClassesData(player: Player)
	Remotes.get(Remotes.Names.ClassesData):FireClient(player, {
		owned = ownedSet(player),
		equipped = ClassService.getEquippedId(player),
	})
end

-- Returns (ok: boolean, message: string) — message is meant to go straight into a Toast.
function ClassService.buyClass(player: Player, classId: string): (boolean, string)
	if not Config.Features.Economy then
		return false, "The shop is closed right now."
	end
	local def = Classes.byId[classId]
	if not def then
		return false, "Unknown class."
	end
	if def.price <= 0 then
		return false, "That one's already free."
	end
	if ClassService.isOwned(player, classId) then
		return false, "You already own that."
	end
	local ok = ctx.services.DataService.spendCoins(player, def.price)
	if not ok then
		return false, "Not enough coins."
	end
	ctx.services.DataService.grantClassOwnership(player, classId)
	pushClassesData(player)
	return true, ("Bought %s."):format(def.name)
end

function ClassService.equipClass(player: Player, classId: string): (boolean, string)
	if not Config.Features.Economy then
		return false, "The shop is closed right now."
	end
	local def = Classes.byId[classId]
	if not def then
		return false, "Unknown class."
	end
	if not ClassService.isOwned(player, classId) then
		return false, "You don't own that yet."
	end
	ctx.services.DataService.setEquippedClass(player, classId)
	pushClassesData(player)
	return true, ("Equipped %s."):format(def.name)
end

-- Called once per shift, from ShiftManager's ShiftIntro branch, AFTER shiftParams exists and BEFORE
-- DollService.spawnShift/TellService.startShift/etc read it. R1: correct with 1 participant.
-- Shared/global buffs (ExtraStrike, TellDurationMultiplier) take the most-generous value across ALL
-- equipped participants rather than stacking — strikes and tell timing are shift-wide state, not
-- per-player. Per-player buffs (StartWithRibbon) are applied directly here as a side effect;
-- CoinMultiplier is read per-player at the award call site instead, not folded into this aggregate.
function ClassService.applyBuffs(_shiftParams: any, participants: { Player }): any
	local aggregate = {
		strikeLimitBonus = 0,
		careSpeedMultiplier = 1, -- <1 = faster; most-generous (lowest) among equipped participants
		tellDurationMultiplier = 1, -- >1 = tells linger longer; most-generous (highest) among equipped participants
	}
	if not Config.Features.Economy then
		return aggregate
	end
	for _, player in participants do
		local buff = ClassService.getEquippedBuff(player)
		if buff.kind == "ExtraStrike" then
			aggregate.strikeLimitBonus = math.max(aggregate.strikeLimitBonus, buff.value or 0)
		elseif buff.kind == "CareSpeedMultiplier" then
			aggregate.careSpeedMultiplier = math.min(aggregate.careSpeedMultiplier, buff.value or 1)
		elseif buff.kind == "TellDurationMultiplier" then
			aggregate.tellDurationMultiplier = math.max(aggregate.tellDurationMultiplier, buff.value or 1)
		elseif buff.kind == "StartWithRibbon" then
			Util.safeCall("giveRibbon", ctx.services.DollService.giveRibbon, player)
		end
	end
	return aggregate
end

function ClassService.init(context: any)
	ctx = context

	Remotes.get(Remotes.Names.BuyClass).OnServerEvent:Connect(function(player: Player, classId: any)
		if typeof(classId) ~= "string" then
			return
		end
		Util.safeCall("buyClass", function()
			local _ok, msg = ClassService.buyClass(player, classId)
			Remotes.get(Remotes.Names.Toast):FireClient(player, msg, 3)
		end)
	end)

	Remotes.get(Remotes.Names.EquipClass).OnServerEvent:Connect(function(player: Player, classId: any)
		if typeof(classId) ~= "string" then
			return
		end
		Util.safeCall("equipClass", function()
			local _ok, msg = ClassService.equipClass(player, classId)
			Remotes.get(Remotes.Names.Toast):FireClient(player, msg, 3)
		end)
	end)

	ctx.services.DataService.onStatsChanged(function(player: Player, _stats: any)
		pushClassesData(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		pushClassesData(player)
		task.delay(3, function()
			if player.Parent then
				pushClassesData(player)
			end
		end)
	end)
end

return ClassService
```

**Required addition to `DollService.luau`** (needed only for `StartWithRibbon`): the file already tracks ribbon possession in a module-local `ribbonHolders: { [Player]: boolean }` table, set by the ribbon-spool `ProximityPrompt.Triggered` handler. Add a public equivalent:

```lua
-- ADD to DollService.luau — grants a ribbon outside the spool-prompt flow (used by ClassService's
-- StartWithRibbon buff at ShiftIntro). Mirrors the existing spool-prompt handler exactly.
function DollService.giveRibbon(player: Player): boolean
	ribbonHolders[player] = true
	fireTo(player, "Toast", "A silver ribbon is already tucked in your pocket.", 3)
	return true
end
```

**Wiring order:** `docs/INTERFACES.md` lists the server init order as `MapBuilder, DataService, WatchService, DollService, GlyphService, TellService, PresenceService, HauntService, BanishService, LobbyService, ShiftManager, DebugService`. `ClassService` needs `DataService` and `DollService` already initialized, so it must init **after `DollService`, before `ShiftManager`** — e.g. right after `BanishService` and before `LobbyService`.

### 5. New Remotes (flag for addition to `src/shared/Remotes.luau`'s `DEFS` table)

```lua
	-- Server -> Client
	CoinsUpdate = "Event", -- (coins: number) pushed on any balance change (grant/spend) + once near PlayerAdded
	ClassesData = "Event", -- (data: {owned: {[string]: boolean}, equipped: string}) pushed per-player on join/buy/equip

	-- Client -> Server
	BuyClass = "Event", -- (classId: string)
	EquipClass = "Event", -- (classId: string)
```

All four are simple `RemoteEvent`s. Error/success feedback for buy/equip reuses the **existing** `Toast` remote.

### 6. `src/client/Controllers/Shop.luau` (new file, full code)

Follows `LedgerUI.luau`'s book-panel idiom. **Panel-open interop: see "READ THIS FIRST" §3 above — this
listing originally used a `PorcelainOpenShop` bindable; change it to listen on `PorcelainOpenPanel`
with a `"Shop"` name check per that section's recommendation before implementing.**

```lua
--!strict
-- Coin balance + class shop. Full-screen panel toggled via Shop.open()/close()/toggle(), or by any
-- other controller firing ReplicatedStorage's "PorcelainOpenPanel" BindableEvent with the string
-- "Shop" (see PACKET_1_LOBBY_SYSTEMS.md's integration notes — this listens on the SAME bindable the
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
```

### 6b. `src/client/Controllers/Classes.luau` (new file, full code)

**Added 2026-08-15 per the team's decision to keep Classes as its own screen, separate from Shop** (see
"READ THIS FIRST" §3 above). Styled after the actual reference screenshots: a scrollable list of every
class on the left (locked ones show a 🔒 — Unicode 6.0/2010, the same generation as the `😱`/`🐞`
already confirmed rendering fine elsewhere in this codebase, so it doesn't carry B6's tofu-box risk),
the equipped one highlighted gold, a description/detail pane on the right, and an Equip button.
Deliberately does **not** attempt the reference's per-class outfit preview or level tabs — see §3a
above for why that's out of scope for this batch. Reuses `Shop.luau`'s exact remotes
(`ClassesData`/`CoinsUpdate`) and the same `PorcelainOpenPanel` interop convention, listening for
`"Classes"` instead of `"Shop"` — no new remotes needed.

```lua
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
	equipButton = Theme.button(detail, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(0, 200, 0, 64), -- mobile-first: >=64px touch target
		TextSize = 18,
		Text = "EQUIP",
	})
	equipButton.Activated:Connect(function()
		if not isOwnedLocally(selectedId) or equipped == selectedId then
			return
		end
		SoundKit.play("UiClick")
		Remotes.get(Remotes.Names.EquipClass):FireServer(selectedId)
	end)

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
```

Add `"Classes"` to `src/client/init.client.luau`'s `ORDER` list (integration-owned file), alongside
`Shop`/`Journal`/`JoinSquareUI`/`LobbyHud`.

**Small `LobbyService.luau` touch-point, directly from the reference screenshots:** every player's
lobby billboard there shows "Top Shift: N" plus their currently equipped class name underneath, in
place of a second numeric stat. Cheap and worth doing — `LobbyService`'s billboard-refresh code
(wherever it sets the two `BillboardGui` text lines per player) should read
`ctx.services.ClassService.getEquippedId(player)` → `Classes.byId[id].name` for the second line
instead of (or in addition to) `dollsCleared`. Not blocking — flag to whoever wires `LobbyService`
alongside the rest of this packet, since `ClassService` (Track A §4) needs to exist first.

### 7. Config additions (flag for `src/shared/Config.luau`)

**`Config.Features`** — append one key (R3 kill switch for the whole system):
```lua
	Features = {
		DataStore = true,
		FakeTells = true,
		Detector = true,
		Naming = true,
		FreeTextNames = false,
		Taken = false,
		PanicEmote = true,
		Economy = true, -- NEW: master kill switch for coins/classes/shop (R3)
	},
```

**New top-level `Config.Economy` table:**
```lua
	Economy = {
		CoinsPerDoll = 7, -- DEFAULT -- flag to team if they'd rather use a different number in the 5-10 range.
		PerfectShiftBonus = 15, -- DEFAULT -- once per shift cleared with zero strikes that shift
		LateShiftBonusPerShift = 3, -- DEFAULT -- flat bonus per shift-number-above-1 cleared
		LateShiftBonusCapShifts = 5, -- DEFAULT -- bonus stops growing past shift 6 (5 * 3 = 15 max)
	},
```

Class prices and buff values deliberately stay in `Classes.luau` itself, not here — consistent with how `Tells.luau` keeps its own weights and `Haunts.luau` keeps its own cooldowns/tiers.

**`SoundConfig.luau`** — two optional new cues (ids ship `0`, per the existing "audio ships silent" convention):
```lua
	-- Shop / economy
	PurchaseSuccess = { soundId = 0, volume = 0.7 }, -- TODO(team): coin-drop / register chime
	PurchaseDenied = { soundId = 0, volume = 0.5 }, -- TODO(team): soft buzz (not enough coins / already owned)
```

### 8. Toolbox / Creator Store asset ideas (decoration only — code stays procedural)

- Physical Shop kiosk/stall: **"Victorian shop counter low poly"**, **"antique dollmaker cabinet"**, or **"creepy curiosity shop shelf"**.
- Coin icon: **"free coin icon"** or **"gold coin mesh low poly"**.
- Sound cues: **"coin purchase chime"** / **"cash register ding"** (`PurchaseSuccess`), soft **"denied buzz"** (`PurchaseDenied`).

**Compliance reminder (MASTER.md §3.4):** every inserted Toolbox/free asset must be audited before use for (a) hidden scripts/backdoors, (b) third-party IP that could trigger a DMCA.

### 9. Compliance note (MASTER.md §3.3)

Fixed-outcome purchases only: coins are earned currency, never purchasable with real money in this section; the Shop sells a fixed roster at fixed prices with zero randomness. No loot boxes, no gacha, matching `MASTER.md` §3.3's v1 rule exactly. **[LATER]:** wiring this to accept real-money Robux is explicitly out of scope — would need game passes/dev products, `MarketplaceService` receipt handling, and the monetization dashboard work called out in `PLAN.md`.

### Open questions / defaults chosen

- **`CoinsPerDoll = 7`, `PerfectShiftBonus = 15`, `LateShiftBonusPerShift = 3` (cap 5 shifts)** — all DEFAULT.
- **Coins are awarded to every current shift participant**, not just whoever finished the last care step — flag if the team wants individual-contribution-based splits instead.
- **`ownedClasses`/`equippedClass` merge semantics are genuinely new patterns for `DataService`** — see "READ THIS FIRST" §1.
- **Shared vs. per-player buffs:** `ExtraStrike`/`TellDurationMultiplier` apply once per shift (most-generous across equipped participants), because strikes/tell timing are shift-wide singleton state.
- **`CareSpeedMultiplier`/`TellDurationMultiplier` are only half-wired by this section** — safe no-ops until `DollService`/`MinigameController`/`TellService` are edited to consume them.
- **`DollService.giveRibbon` is a new API** this section needs, proposed as a two-line addition.
- **`docs/INTERFACES.md` says `DataService` exposes `onStatsLoaded`; the actual current file exports `onStatsChanged`** — this section follows the real file, not the doc prose. Worth a doc-fix pass.

---

## Track B — Social: Journal/Quests + Invite + Tutorial Gate

**Owner scope:** the Journal (quest/checklist) system, the Invite button, and the tutorial-gate flag. Does **not** cover the Shop, Classes, join-squares, or the physical left-side HUD bar — see the "READ THIS FIRST" section above for exact interop points.

**Grounding:** `docs/INTERFACES.md`, `PLAN.md` §3 (R1–R8), and direct reads of `src/shared/Config.luau`, `src/shared/Remotes.luau`, `src/shared/Util.luau`, `src/shared/SoundConfig.luau`, `src/shared/Defs/{CareSteps,Spirits,DollNames}.luau`, `src/shared/Logic/GlyphMatch.luau`, `src/server/Services/{DataService,ShiftManager,BanishService,DollService,LobbyService,DebugService}.luau`, `src/server/init.server.luau`, `src/client/{init.client,Theme}.luau`, `src/client/Controllers/{LedgerUI,Toast}.luau`.

### 0. New files / edits at a glance

| File | Action |
|---|---|
| `src/shared/Defs/Quests.luau` | **NEW** — quest roster (data only) |
| `src/shared/Logic/QuestProgress.luau` | **NEW** — pure progress math, shared client+server (mirrors `Logic/GlyphMatch.luau`) |
| `src/server/Services/QuestService.luau` | **NEW** — progress hooks, claim, easter-egg world triggers |
| `src/server/Services/DataService.luau` | **EDIT** — new fields, new merge rules, new public functions (see "READ THIS FIRST" §1 for the merge with the Economy track) |
| `src/server/Services/DollService.luau` | **EDIT** — add `onRibbonTied` callback hook |
| `src/server/Services/ShiftManager.luau` | **EDIT** — add `onShiftCleared` callback hook (see "READ THIS FIRST" §2) |
| `src/server/init.server.luau` | **EDIT** — register `QuestService` (integration-owned file) |
| `src/shared/Remotes.luau` | **EDIT** — add `PlayerStats` (S→C), `ClaimQuest` (C→S) |
| `src/shared/Config.luau` | **EDIT** — `Config.Quests.*`, `Config.Features.Quests`, `Config.Features.TutorialGate`, `Config.Features.InviteFallbackButton` |
| `src/shared/SoundConfig.luau` | **EDIT (optional)** — `QuestComplete` cue placeholder |
| `src/client/Controllers/Journal.luau` | **NEW** — quest list UI |
| `src/client/Controllers/InviteButton.luau` | **NEW** — invite handler |
| `src/client/init.client.luau` | **EDIT** — register both new controllers (integration-owned file) |

### 1. `src/shared/Defs/Quests.luau` (new)

Numbers sized against the team's own baseline ("5–10 coins per doll"): milestone rewards roughly track "how many shifts of grinding would this otherwise take," easter eggs are flat small treats. **All marked DEFAULT.**

```lua
--!strict
-- The Dollmaker's Journal: quest/checklist roster. Data only -- no game references, mirrors the
-- shape of Defs/CareSteps.luau and Defs/Spirits.luau (list + byId). Progress math lives in
-- Logic/QuestProgress.luau so both QuestService (server) and Journal (client) share one
-- implementation, the same split used for GlyphMatch/LedgerUI.

export type GoalType = "DollsCleared" | "ShiftsSurvived" | "FirstTryBanishes" | "RibbonsTied" | "Flag"

export type Quest = {
	id: string,
	title: string,
	description: string,
	goalType: GoalType,
	target: number,
	coinReward: number,
	category: "Milestone" | "EasterEgg",
	hidden: boolean?, -- true = Journal UI shows "???" until DataService stats.questFlags[id] is true
}

local Quests: { Quest } = {
	{
		id = "DollsTen",
		title = "Gentle Hands",
		description = "Finish caring for 10 dolls, across as many shifts as it takes.",
		goalType = "DollsCleared",
		target = 10,
		coinReward = 15,
		category = "Milestone",
	},
	{
		id = "DollsFifty",
		title = "Steady Hands",
		description = "Finish caring for 50 dolls in total. The Dollmaker is starting to notice.",
		goalType = "DollsCleared",
		target = 50,
		coinReward = 60,
		category = "Milestone",
	},
	{
		id = "DollsHundred",
		title = "The Dollmaker's Favorite",
		description = "Finish caring for 100 dolls in total. Nobody else lasts this long.",
		goalType = "DollsCleared",
		target = 100,
		coinReward = 150,
		category = "Milestone",
	},
	{
		id = "ShiftFive",
		title = "Steady Nerves",
		description = "Survive all the way to Shift 5.",
		goalType = "ShiftsSurvived",
		target = 5,
		coinReward = 40,
		category = "Milestone",
	},
	{
		id = "ShiftTen",
		title = "Old Hand",
		description = "Survive all the way to Shift 10. The workshop feels almost familiar now.",
		goalType = "ShiftsSurvived",
		target = 10,
		coinReward = 100,
		category = "Milestone",
	},
	{
		id = "FirstTryFive",
		title = "Sharp Eyes",
		description = "Banish the right one on your very first guess, 5 times total.",
		goalType = "FirstTryBanishes",
		target = 5,
		coinReward = 50,
		category = "Milestone",
	},
	{
		id = "RibbonsTwentyFive",
		title = "Silver Fingers",
		description = "Tie the silver ribbon 25 times in total. Never skip it. Always. — The Dollmaker",
		goalType = "RibbonsTied",
		target = 25,
		coinReward = 45,
		category = "Milestone",
	},
	{
		id = "EggFloorboard",
		title = "Under the Floorboard",
		description = "Something was hidden beneath the lobby floor. You found it.",
		goalType = "Flag",
		target = 1,
		coinReward = 20,
		category = "EasterEgg",
		hidden = true,
	},
	{
		id = "EggNote",
		title = "The Dollmaker's Handwriting",
		description = "You found a note in handwriting that isn't yours. It knew you'd look.",
		goalType = "Flag",
		target = 1,
		coinReward = 20,
		category = "EasterEgg",
		hidden = true,
	},
	{
		id = "EggStillness",
		title = "Don't Move",
		description = "You stood somewhere you shouldn't have, and stayed there. Something noticed.",
		goalType = "Flag",
		target = 1,
		coinReward = 25,
		category = "EasterEgg",
		hidden = true,
	},
}

local byId: { [string]: Quest } = {}
for _, quest in Quests do
	byId[quest.id] = quest
end

return {
	list = Quests,
	byId = byId,
}
```

### 2. DataService tracking plan

**See "READ THIS FIRST" §1 above — this section's `DataService` changes must be merged with the
Economy track's, not applied as an independent full-file replacement.**

#### What already exists (checked against the real file)

`Stats = { bestShift: number, dollsCleared: number, perfectShifts: number, runs: number, loaded: boolean }`, merged via `UpdateAsync` with **max()** for `bestShift` and **sum()** for the rest.

| Quest | Reuses existing field? | Notes |
|---|---|---|
| `DollsTen`/`DollsFifty`/`DollsHundred` | **Yes — `dollsCleared`** | Increments by `shiftParams.dollCount` on every *correct* banish. Doesn't count dolls consumed by a wrong banish in the same shift, and only commits at `RunEnd` — both pre-existing behaviors, flagging per instructions. |
| `ShiftFive`/`ShiftTen` | **Yes — `bestShift`** | Already a max-of-career value. |
| `FirstTryFive` | **Yes — `perfectShifts`** | `ShiftManager.onBanishResolved`'s correct branch does `if runStats.strikesThisShift == 0 then runStats.perfect += 1 end`, and `strikesThisShift` resets every `ShiftIntro`. So `perfectShifts` already IS "correct banish on the first try," summed over career. No new field. |
| `RibbonsTwentyFive` | **No — genuinely new.** | New field: `ribbonsTiedTotal: number`, sum-merge. |
| `EggFloorboard`/`EggNote`/`EggStillness` | **No — genuinely new.** | New field: `questFlags: {[string]: boolean}`, per-key OR/union-merge. |

#### New fields and their merge rules

| Field | Type | Merge rule | Why it deviates |
|---|---|---|---|
| `coins` | `number` | **sum** | Net change this session — **see "READ THIS FIRST" §1, same field as Economy's, compatible.** |
| `ribbonsTiedTotal` | `number` | **sum** | Career counter, same shape as `dollsCleared`. |
| `tutorialDone` | `boolean` | **OR-merge — `old OR new`, never reset to false** | Genuine deviation from max/sum — a boolean that can only go false→true and must never revert. |
| `claimedQuestIds` | `{[string]: boolean}` | **per-key OR/union-merge** | Once a quest is claimed by *any* session, it must never be payable again — the double-payout guard. |
| `questFlags` | `{[string]: boolean}` | **per-key OR/union-merge** | Easter-egg discovery state (separate from *claimed*). |

**Important correctness fix bundled with this change:** the existing `flushPlayer` early-return gate would silently **skip flushing** a player whose *only* changes this session were coin/ribbon/tutorial/quest-flag updates. This spec replaces that gate with an explicit `dirty: {[Player]: boolean}` table set `true` by every stat-mutating function and cleared only after a successful flush — a real behavior change to the existing file.

#### Full replacement for `src/server/Services/DataService.luau`

**(Merge with Economy track's own full replacement per "READ THIS FIRST" §1 before applying — the
listing below, on its own, is missing Economy's `ownedClasses`/`equippedClass` fields.)**

```lua
--!strict
-- Persistence per R5: probe once, memory fallback, UpdateAsync merge-only, never blocks gameplay.
--
-- Extended for the lobby/economy Journal system (Social spec): coins, ribbon-tie counter,
-- tutorialDone (a ONE-WAY flag -- OR-merge, not sum/max), and two claimed/discovered id sets
-- (per-key OR/union-merge). R5 says every merge is max() or sum() UNLESS explicitly flagged
-- otherwise -- these three new shapes (sum x2, OR-boolean, OR-set x2) are that flagged exception.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Util = require(Shared:WaitForChild("Util")) :: any

local DataService = {}

type Stats = {
	bestShift: number,
	dollsCleared: number,
	perfectShifts: number,
	runs: number,
	coins: number, -- NEW: sum-merge.
	ribbonsTiedTotal: number, -- NEW: sum-merge.
	tutorialDone: boolean, -- NEW: OR-merge.
	claimedQuestIds: { [string]: boolean }, -- NEW: per-key OR/union-merge.
	questFlags: { [string]: boolean }, -- NEW: per-key OR/union-merge.
	loaded: boolean,
}

local available = false
local store: any = nil
local cache: { [Player]: Stats } = {}
local sessionDelta: {
	[Player]: {
		dollsCleared: number,
		perfectShifts: number,
		runs: number,
		bestShift: number,
		coins: number, -- NEW
		ribbonsTiedTotal: number, -- NEW
	},
} = {}
local dirty: { [Player]: boolean } = {} -- NEW: true when cache has unflushed changes
local loadedCallbacks: { (Player, Stats) -> () } = {}

local function defaultStats(): Stats
	return {
		bestShift = 0,
		dollsCleared = 0,
		perfectShifts = 0,
		runs = 0,
		coins = 0,
		ribbonsTiedTotal = 0,
		tutorialDone = false,
		claimedQuestIds = {},
		questFlags = {},
		loaded = false,
	}
end

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

local function loadPlayer(player: Player)
	cache[player] = defaultStats()
	sessionDelta[player] =
		{ dollsCleared = 0, perfectShifts = 0, runs = 0, bestShift = 0, coins = 0, ribbonsTiedTotal = 0 }
	dirty[player] = false
	if not available then
		return
	end
	task.spawn(function()
		for attempt = 1, Config.Data.ReadRetries do
			local ok, result = pcall(function()
				return store:GetAsync(keyFor(player))
			end)
			if ok then
				local stats = cache[player]
				if stats and typeof(result) == "table" then
					stats.bestShift = tonumber(result.bestShift) or 0
					stats.dollsCleared = tonumber(result.dollsCleared) or 0
					stats.perfectShifts = tonumber(result.perfectShifts) or 0
					stats.runs = tonumber(result.runs) or 0
					stats.coins = tonumber(result.coins) or 0
					stats.ribbonsTiedTotal = tonumber(result.ribbonsTiedTotal) or 0
					stats.tutorialDone = result.tutorialDone == true
					if typeof(result.claimedQuestIds) == "table" then
						for id, v in result.claimedQuestIds do
							if v and typeof(id) == "string" then
								stats.claimedQuestIds[id] = true
							end
						end
					end
					if typeof(result.questFlags) == "table" then
						for id, v in result.questFlags do
							if v and typeof(id) == "string" then
								stats.questFlags[id] = true
							end
						end
					end
				end
				if stats then
					stats.loaded = true
					for _, cb in loadedCallbacks do
						Util.safeCall("statsLoaded", cb, player, stats)
					end
				end
				return
			end
			task.wait(Config.Data.RetryBackoffSeconds * attempt)
		end
		Util.warn("DataService: load failed for " .. player.Name .. " (memory-only this session)")
	end)
end

local function flushPlayer(player: Player)
	if not available or not dirty[player] then -- NEW gate (was: delta.runs == 0 and delta.bestShift == 0)
		return
	end
	local delta = sessionDelta[player]
	local stats = cache[player]
	if not delta or not stats then
		return
	end
	local snapshot = {
		bestShift = delta.bestShift,
		dollsCleared = delta.dollsCleared,
		perfectShifts = delta.perfectShifts,
		runs = delta.runs,
		coins = delta.coins,
		ribbonsTiedTotal = delta.ribbonsTiedTotal,
		tutorialDone = stats.tutorialDone, -- absolute value -- OR-merge is idempotent, no delta needed
		claimedQuestIds = table.clone(stats.claimedQuestIds), -- absolute
		questFlags = table.clone(stats.questFlags), -- absolute
	}
	local ok = pcall(function()
		store:UpdateAsync(keyFor(player), function(old: any)
			old = if typeof(old) == "table" then old else {}
			local mergedClaimed = if typeof(old.claimedQuestIds) == "table" then table.clone(old.claimedQuestIds) else {}
			for id, v in snapshot.claimedQuestIds do
				if v then
					mergedClaimed[id] = true
				end
			end
			local mergedFlags = if typeof(old.questFlags) == "table" then table.clone(old.questFlags) else {}
			for id, v in snapshot.questFlags do
				if v then
					mergedFlags[id] = true
				end
			end
			return {
				bestShift = math.max(tonumber(old.bestShift) or 0, snapshot.bestShift),
				dollsCleared = (tonumber(old.dollsCleared) or 0) + snapshot.dollsCleared,
				perfectShifts = (tonumber(old.perfectShifts) or 0) + snapshot.perfectShifts,
				runs = (tonumber(old.runs) or 0) + snapshot.runs,
				coins = (tonumber(old.coins) or 0) + snapshot.coins,
				ribbonsTiedTotal = (tonumber(old.ribbonsTiedTotal) or 0) + snapshot.ribbonsTiedTotal,
				tutorialDone = (old.tutorialDone == true) or snapshot.tutorialDone,
				claimedQuestIds = mergedClaimed,
				questFlags = mergedFlags,
			}
		end)
	end)
	if ok then
		dirty[player] = false
		local d = sessionDelta[player]
		if d then
			d.dollsCleared = 0
			d.perfectShifts = 0
			d.runs = 0
			d.coins = 0
			d.ribbonsTiedTotal = 0
			-- bestShift / tutorialDone / claimedQuestIds / questFlags stay as-is: their merges are idempotent
		end
	else
		Util.warn("DataService: flush failed for " .. player.Name)
	end
end

function DataService.init(_ctx: any)
	if Config.Features.DataStore then
		task.spawn(function()
			local ok = pcall(function()
				store = DataStoreService:GetDataStore(Config.Data.StoreName)
				store:GetAsync("__probe")
			end)
			available = ok
			Util.log(
				"DataService: " .. (
					if available
						then "DataStores ONLINE"
						else "DataStores unavailable — memory-only (publish + enable Studio API access to persist)"
				)
			)
			if available then
				for _, player in Players:GetPlayers() do
					if cache[player] and not cache[player].loaded then
						loadPlayer(player)
					end
				end
			end
		end)
	end

	Players.PlayerAdded:Connect(loadPlayer)
	for _, player in Players:GetPlayers() do
		if not cache[player] then
			loadPlayer(player)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		flushPlayer(player)
		cache[player] = nil
		sessionDelta[player] = nil
		dirty[player] = nil
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			Util.safeCall("bindToCloseFlush", flushPlayer, player)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(120)
			for _, player in Players:GetPlayers() do
				Util.safeCall("autosave", flushPlayer, player)
			end
		end
	end)
end

function DataService.getStats(player: Player): Stats
	return cache[player] or defaultStats()
end

function DataService.recordRun(player: Player, result: { shiftReached: number, dollsCleared: number, perfect: number })
	local stats = cache[player]
	local delta = sessionDelta[player]
	if not stats or not delta then
		return
	end
	stats.bestShift = math.max(stats.bestShift, result.shiftReached)
	stats.dollsCleared += result.dollsCleared
	stats.perfectShifts += result.perfect
	stats.runs += 1
	delta.bestShift = math.max(delta.bestShift, result.shiftReached)
	delta.dollsCleared += result.dollsCleared
	delta.perfectShifts += result.perfect
	delta.runs += 1
	dirty[player] = true
	for _, cb in loadedCallbacks do
		Util.safeCall("statsChanged", cb, player, stats)
	end
end

-- ---------- Journal/economy support (Social spec) ----------

function DataService.addCoins(player: Player, amount: number)
	local stats = cache[player]
	local delta = sessionDelta[player]
	if not stats or not delta then
		return
	end
	stats.coins += amount
	delta.coins += amount
	dirty[player] = true
	for _, cb in loadedCallbacks do
		Util.safeCall("statsChanged", cb, player, stats)
	end
end

function DataService.addRibbonTied(player: Player, amount: number)
	local stats = cache[player]
	local delta = sessionDelta[player]
	if not stats or not delta then
		return
	end
	stats.ribbonsTiedTotal += amount
	delta.ribbonsTiedTotal += amount
	dirty[player] = true
	for _, cb in loadedCallbacks do
		Util.safeCall("statsChanged", cb, player, stats)
	end
end

function DataService.setTutorialDone(player: Player)
	local stats = cache[player]
	if not stats or stats.tutorialDone then
		return
	end
	stats.tutorialDone = true
	dirty[player] = true
	for _, cb in loadedCallbacks do
		Util.safeCall("statsChanged", cb, player, stats)
	end
end

function DataService.setQuestFlag(player: Player, questId: string)
	local stats = cache[player]
	if not stats or stats.questFlags[questId] then
		return
	end
	stats.questFlags[questId] = true
	dirty[player] = true
	for _, cb in loadedCallbacks do
		Util.safeCall("statsChanged", cb, player, stats)
	end
end

function DataService.markQuestClaimed(player: Player, questId: string): boolean
	local stats = cache[player]
	if not stats or stats.claimedQuestIds[questId] then
		return false
	end
	stats.claimedQuestIds[questId] = true
	dirty[player] = true
	for _, cb in loadedCallbacks do
		Util.safeCall("statsChanged", cb, player, stats)
	end
	return true
end

function DataService.onStatsChanged(fn: (Player, Stats) -> ())
	table.insert(loadedCallbacks, fn)
end

return DataService
```

### 3. `QuestService.luau` + hook edits + new Remotes

#### 3a. Exact hook points

**Ribbon-tie counter → `DollService.luau`.** Add a callback list mirroring the existing `stepCallbacks`/`onStepCompleted` pattern:

1. Near the top: `local ribbonCallbacks: { (Player, string) -> () } = {} -- NEW (Social/Journal spec)`
2. Inside `DollService.tieRibbon(...)`, right before the final `return true` (after `refreshPrompt(rec)`):
```lua
	for _, cb in ribbonCallbacks do
		Util.safeCall("ribbonCallback", cb, player, dollId)
	end
```
3. Near the existing `DollService.onStepCompleted`:
```lua
function DollService.onRibbonTied(fn: (Player, string) -> ())
	table.insert(ribbonCallbacks, fn)
end
```

**First full shift → `ShiftManager.luau`.** Hook the `correct` branch of `onBanishResolved` directly (NOT `RunEnd`/`recordRun`, which only fires at the whole run's end — a player who wins shift 1 then quits would never get credit if hooked there). **See "READ THIS FIRST" §2 for the exact final insertion order relative to Economy's own edits to this same branch.**

1. Near other module-level state: `local shiftClearedCallbacks: { ({ Player }, number) -> () } = {} -- NEW`
2. Inside `onBanishResolved`'s `correct` branch — insert after the `runStats.perfect` bump, before `shiftNumber += 1`:
```lua
			pruneParticipants()
			for _, cb in shiftClearedCallbacks do
				Util.safeCall("shiftClearedCallback", cb, table.clone(participants), shiftNumber)
			end
```
3. Near the other public API functions:
```lua
function ShiftManager.onShiftCleared(fn: ({ Player }, number) -> ())
	table.insert(shiftClearedCallbacks, fn)
end
```

#### 3b. New Remotes — **ADD to `src/shared/Remotes.luau`'s `DEFS` table**

```lua
	-- Server -> Client
	PlayerStats = "Event", -- (stats: DataService.Stats) full per-player stats snapshot -- fired on
	                       -- load + every change. Consumed by Journal (progress), the join-square
	                       -- UI (tutorialDone -> Skip Tutorial button), and Shop (coins, via CoinsUpdate).

	-- Client -> Server
	ClaimQuest = "Event", -- (questId: string) client requests reward payout for a completed quest
```

#### 3c. `src/shared/Logic/QuestProgress.luau` (new)

```lua
--!strict
-- Pure logic: quest progress computation, shared by QuestService (server, authoritative) and
-- Journal (client, immediate feedback) -- same split as Logic/GlyphMatch.luau for the Ledger.

export type QuestStatsView = {
	dollsCleared: number,
	bestShift: number,
	perfectShifts: number,
	ribbonsTiedTotal: number,
	questFlags: { [string]: boolean },
}

export type QuestDef = {
	id: string,
	goalType: "DollsCleared" | "ShiftsSurvived" | "FirstTryBanishes" | "RibbonsTied" | "Flag",
	target: number,
}

local QuestProgress = {}

function QuestProgress.compute(stats: QuestStatsView, quest: QuestDef): number
	if quest.goalType == "DollsCleared" then
		return stats.dollsCleared
	elseif quest.goalType == "ShiftsSurvived" then
		return stats.bestShift
	elseif quest.goalType == "FirstTryBanishes" then
		return stats.perfectShifts
	elseif quest.goalType == "RibbonsTied" then
		return stats.ribbonsTiedTotal
	elseif quest.goalType == "Flag" then
		return (stats.questFlags[quest.id] == true) and 1 or 0
	end
	return 0
end

function QuestProgress.isComplete(stats: QuestStatsView, quest: QuestDef): boolean
	return QuestProgress.compute(stats, quest) >= quest.target
end

return QuestProgress
```

#### 3d. `src/server/Services/QuestService.luau` (new)

```lua
--!strict
-- Journal / quests: tracks progress toward Defs/Quests.luau and pays out coin rewards. Progress
-- is derived at read-time from DataService's stats via Logic/QuestProgress -- QuestService holds
-- no separate "quest progress" cache, it's a thin authority layer over DataService.
--
-- Also owns: the hidden lobby easter-egg triggers, and (behind Config.Features.TutorialGate)
-- setting tutorialDone the moment a player's first shift is won.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Util = require(Shared:WaitForChild("Util")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local Quests = require(Shared:WaitForChild("Defs"):WaitForChild("Quests")) :: any
local QuestProgress = require(Shared:WaitForChild("Logic"):WaitForChild("QuestProgress")) :: any

local QuestService = {}

local ctx: any
local stillnessDwell: { [Player]: number } = {}

local function broadcastStats(player: Player)
	local stats = ctx.services.DataService.getStats(player)
	Remotes.get(Remotes.Names.PlayerStats):FireClient(player, stats)
end

-- ---------- claim ----------

function QuestService.claim(player: Player, questId: string): boolean
	local quest = Quests.byId[questId]
	if not quest then
		return false
	end
	local DataService = ctx.services.DataService
	local stats = DataService.getStats(player)
	if stats.claimedQuestIds[questId] then
		Remotes.get(Remotes.Names.Toast):FireClient(player, "Already claimed.", 3)
		return false
	end
	if not QuestProgress.isComplete(stats, quest) then
		return false -- client shouldn't have shown Claim yet; ignore silently
	end
	if not DataService.markQuestClaimed(player, questId) then
		return false -- race: another claim beat us to it
	end
	DataService.addCoins(player, quest.coinReward)
	Remotes.get(Remotes.Names.Toast):FireClient(
		player,
		("Journal complete: %s (+%d coins)"):format(quest.title, quest.coinReward),
		4
	)
	broadcastStats(player)
	return true
end

-- ---------- easter eggs ----------
-- Built by THIS service, independently of MapBuilder.luau, and parented under ctx.manifest.root.
-- Safe to do because MapBuilder.build() always runs BEFORE any service's init() (server
-- bootstrap order per docs/INTERFACES.md), so ctx.manifest is fully populated here.

local function makeEggPrompt(part: BasePart, actionText: string, objectText: string, onTrigger: (Player) -> ())
	CollectionService:AddTag(part, "QuestTrigger")
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = Config.Care.PromptDistance
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Parent = part
	prompt.Triggered:Connect(function(player: Player)
		Util.safeCall("eggTrigger", onTrigger, player)
	end)
end

local function grantEggFlag(player: Player, questId: string, flavorLine: string)
	local DataService = ctx.services.DataService
	local stats = DataService.getStats(player)
	if stats.questFlags[questId] then
		return -- already found; no repeat toast
	end
	DataService.setQuestFlag(player, questId)
	Remotes.get(Remotes.Names.Toast):FireClient(player, flavorLine, 5)
	broadcastStats(player)
end

local function wireEasterEggs()
	local manifest = ctx.manifest
	local anchor = manifest.chalkboard or manifest.lobbySpawn
	if not anchor then
		return
	end

	-- Egg 1: a floorboard near the chalkboard, deliberately unremarkable-looking
	Util.safeCall("eggFloorboard", function()
		local board = Instance.new("Part")
		board.Name = "LooseFloorboard"
		board.Anchored = true
		board.CanCollide = false
		board.Material = Enum.Material.WoodPlanks
		board.Color = Color3.fromRGB(70, 55, 45)
		board.Size = Vector3.new(2, 0.15, 1)
		board.CFrame = anchor.CFrame * CFrame.new(-4, -0.9, 2.5) -- DEFAULT offset; retune once the real lobby geometry exists
		board.Parent = manifest.root
		makeEggPrompt(board, "Pry It Up", "Loose Floorboard", function(player: Player)
			grantEggFlag(player, "EggFloorboard", "Something glints under the floorboard. You tuck it away.")
		end)
	end)

	-- Egg 2: a folded note near the ribbon spool (thematic tie-in to the ribbon's own hidden-6th-step dread)
	Util.safeCall("eggNote", function()
		local spot = manifest.ribbonSpool or manifest.ledgerDesk or anchor
		local note = Instance.new("Part")
		note.Name = "HiddenNote"
		note.Anchored = true
		note.CanCollide = false
		note.Material = Enum.Material.SmoothPlastic
		note.Color = Color3.fromRGB(224, 214, 180)
		note.Size = Vector3.new(0.6, 0.05, 0.8)
		note.CFrame = spot.CFrame * CFrame.new(1.2, 0.05, -0.3) * CFrame.Angles(0, math.rad(15), 0) -- DEFAULT offset
		note.Parent = manifest.root
		makeEggPrompt(note, "Read the Note", "Folded Paper", function(player: Player)
			grantEggFlag(player, "EggNote", "\"Count the stitches before you count the hours. — The Dollmaker\"")
		end)
	end)

	-- Egg 3: stand still in an odd, unmarked corner of the lobby for a while
	Util.safeCall("eggStillnessSetup", function()
		local spotPart = Instance.new("Part")
		spotPart.Name = "StillnessSpot"
		spotPart.Anchored = true
		spotPart.CanCollide = false
		spotPart.CanQuery = false
		spotPart.Transparency = 1
		spotPart.Size = Vector3.new(4, 1, 4)
		spotPart.CFrame = anchor.CFrame * CFrame.new(6, 0, -5) -- DEFAULT offset
		spotPart.Parent = manifest.root
		CollectionService:AddTag(spotPart, "QuestTrigger")

		task.spawn(function()
			while true do
				task.wait(1 / Config.Quests.StillnessPollHz)
				local standing: { [Player]: boolean } = {}
				local parts = workspace:GetPartBoundsInBox(
					CFrame.new(spotPart.Position + Vector3.new(0, 2.5, 0)),
					Vector3.new(6, 6, 6)
				)
				for _, part in parts do
					local char = part:FindFirstAncestorOfClass("Model")
					local player = char and Players:GetPlayerFromCharacter(char)
					if player then
						standing[player] = true
					end
				end
				for _, player in Players:GetPlayers() do
					if standing[player] then
						local dwell = (stillnessDwell[player] or 0) + (1 / Config.Quests.StillnessPollHz)
						stillnessDwell[player] = dwell
						if dwell >= Config.Quests.StillnessSeconds then
							grantEggFlag(player, "EggStillness", "You stood still long enough for something to notice you back.")
							stillnessDwell[player] = 0
						end
					else
						stillnessDwell[player] = 0
					end
				end
			end
		end)
	end)
end

-- ---------- init ----------

function QuestService.init(context: any)
	ctx = context

	ctx.services.DataService.onStatsChanged(function(player: Player, _stats: any)
		broadcastStats(player)
	end)
	Players.PlayerAdded:Connect(function(player)
		task.delay(2, function()
			if player.Parent then
				broadcastStats(player)
			end
		end)
		stillnessDwell[player] = 0
	end)
	Players.PlayerRemoving:Connect(function(player)
		stillnessDwell[player] = nil
	end)

	if Config.Features.TutorialGate then
		Util.safeCall("wireShiftClearedHook", function()
			ctx.services.ShiftManager.onShiftCleared(function(participants: { Player }, _clearedShift: number)
				for _, player in participants do
					if player.Parent then
						ctx.services.DataService.setTutorialDone(player)
					end
				end
			end)
		end)
	end

	if Config.Features.Quests then
		Util.safeCall("wireRibbonHook", function()
			ctx.services.DollService.onRibbonTied(function(player: Player, _dollId: string)
				ctx.services.DataService.addRibbonTied(player, 1)
			end)
		end)

		Remotes.get(Remotes.Names.ClaimQuest).OnServerEvent:Connect(function(player: Player, questId: any)
			if typeof(questId) ~= "string" then
				return
			end
			QuestService.claim(player, questId)
		end)

		wireEasterEggs()
	end
end

return QuestService
```

#### 3e. Server bootstrap wiring — **EDIT `src/server/init.server.luau`**

Integration-owned file — add `QuestService` to the `require` block, `ctx.services`, and `initOrder`, positioned **after `"ShiftManager"` and before `"DebugService"`**:

```lua
local QuestService = require(ServicesFolder:WaitForChild("QuestService")) :: any
-- ...
services = { ..., ShiftManager = ShiftManager, QuestService = QuestService, DebugService = DebugService }
-- ...
initOrder = { ..., "ShiftManager", "QuestService", "DebugService" }
```

### 4. `src/client/Controllers/Journal.luau` (new)

**Panel-open interop: see "READ THIS FIRST" §3 above — add a listener on `PorcelainOpenPanel`
checking for `"Journal"`, in addition to keeping the `.open()`/`.close()`/`.toggle()` exports below.**

```lua
--!strict
-- The Dollmaker's Journal: quest/checklist list with coin rewards. Opened via the left-side HUD
-- Nav bar firing ReplicatedStorage's "PorcelainOpenPanel" bindable with "Journal" (see
-- PACKET_1_LOBBY_SYSTEMS.md's integration notes), or directly via Journal.open()/.close()/.toggle()
-- (mirrors Toast's cross-controller export pattern, Toast.show).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local Quests = require(Shared:WaitForChild("Defs"):WaitForChild("Quests")) :: any
local QuestProgress = require(Shared:WaitForChild("Logic"):WaitForChild("QuestProgress")) :: any
local SoundKit = require(Shared:WaitForChild("SoundKit")) :: any
local Theme = require(script.Parent.Parent:WaitForChild("Theme")) :: any

local Journal = {}

local gui: ScreenGui? = nil
local listFrame: ScrollingFrame? = nil
local latestStats: any = nil
local previousClaimed: { [string]: boolean } = {}

local HIDDEN_TITLE = "???"
local HIDDEN_DESC = "Something in the workshop is waiting to be found."

local function fillBar(parent: Instance, fraction: number)
	local track = Instance.new("Frame")
	track.BackgroundColor3 = Theme.BgSoft
	track.BorderSizePixel = 0
	track.Size = UDim2.new(1, 0, 0, 14)
	track.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = track
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Theme.Gold
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 7)
	fillCorner.Parent = fill
end

local function buildCard(parent: Instance, quest: any, stats: any)
	local discovered = not quest.hidden or (stats.questFlags and stats.questFlags[quest.id] == true)
	local claimed = stats.claimedQuestIds and stats.claimedQuestIds[quest.id] == true
	local progress = QuestProgress.compute(stats, quest)
	local complete = progress >= quest.target

	local card = Theme.panel(parent, {
		Size = UDim2.new(1, -8, 0, 118),
		BackgroundTransparency = 0.15,
	})

	Theme.label(card, {
		Position = UDim2.new(0, 14, 0, 8),
		Size = UDim2.new(1, -28, 0, 24),
		Font = Theme.TitleFont,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = if discovered then quest.title else HIDDEN_TITLE,
	})

	Theme.label(card, {
		Position = UDim2.new(0, 14, 0, 32),
		Size = UDim2.new(1, -28, 0, 32),
		TextSize = 14,
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = if discovered then quest.description else HIDDEN_DESC,
	})

	local barHolder = Instance.new("Frame")
	barHolder.BackgroundTransparency = 1
	barHolder.Position = UDim2.new(0, 14, 0, 68)
	barHolder.Size = UDim2.new(1, -160, 0, 14)
	barHolder.Parent = card
	fillBar(barHolder, if quest.target > 0 then progress / quest.target else 0)

	Theme.label(card, {
		Position = UDim2.new(0, 14, 0, 86),
		Size = UDim2.new(1, -160, 0, 18),
		TextSize = 13,
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = if discovered
			then ("%d / %d  ·  +%d coins"):format(math.min(progress, quest.target), quest.target, quest.coinReward)
			else "? / ?",
	})

	local claimButton = Theme.button(card, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0, 120, 0, 64), -- mobile touch target (>=64px)
		TextSize = 16,
		Text = if claimed then "Claimed" elseif complete then "Claim" else "Locked",
	})
	claimButton.AutoButtonColor = complete and not claimed
	if claimed or not complete then
		claimButton.BackgroundColor3 = Theme.BgSoft
		claimButton.TextColor3 = Theme.Muted
	end
	claimButton.Activated:Connect(function()
		if claimed or not complete then
			return
		end
		SoundKit.play("UiClick")
		Remotes.get(Remotes.Names.ClaimQuest):FireServer(quest.id)
	end)
end

local function refreshList()
	local list = listFrame
	if not list or not latestStats then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for _, quest in Quests.list do
		buildCard(list, quest, latestStats)
	end

	-- celebration beat: diff claimed sets, flash+chime any id that just newly appeared
	local newlyClaimed = false
	for id in latestStats.claimedQuestIds do
		if not previousClaimed[id] then
			newlyClaimed = true
			break
		end
	end
	if newlyClaimed then
		SoundKit.play("UiConfirm")
		if gui then
			local flash = Instance.new("Frame")
			flash.BackgroundColor3 = Theme.Gold
			flash.BackgroundTransparency = 0.55
			flash.BorderSizePixel = 0
			flash.Size = UDim2.fromScale(1, 1)
			flash.ZIndex = 50
			flash.Parent = gui
			TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
			task.delay(0.65, function()
				flash:Destroy()
			end)
		end
	end
	previousClaimed = {}
	for id in latestStats.claimedQuestIds do
		previousClaimed[id] = true
	end
end

local function buildUI()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local g = Theme.screenGui("PorcelainJournal", 12)
	g.Enabled = false
	g.Parent = playerGui
	gui = g

	local backdrop = Instance.new("Frame")
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.4
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Parent = g

	local panel = Theme.panel(g, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 560, 0, 560),
		BackgroundTransparency = 0.03,
	})

	Theme.label(panel, {
		Position = UDim2.new(0, 0, 0, 10),
		Size = UDim2.new(1, 0, 0, 32),
		Font = Theme.TitleFont,
		TextSize = 26,
		Text = "— The Dollmaker's Journal —",
	})

	local close = Theme.button(panel, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.new(0, 40, 0, 34),
		TextSize = 20,
		Text = "✕",
	})
	close.Activated:Connect(function()
		Journal.close()
	end)

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.new(0, 14, 0, 52)
	list.Size = UDim2.new(1, -28, 1, -66)
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 6
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = list
	listFrame = list
end

function Journal.open()
	if gui then
		gui.Enabled = true
		SoundKit.play("UiClick")
	end
end

function Journal.close()
	if gui then
		gui.Enabled = false
	end
end

function Journal.toggle()
	if gui then
		if gui.Enabled then
			Journal.close()
		else
			Journal.open()
		end
	end
end

function Journal.init()
	buildUI()

	Remotes.get(Remotes.Names.PlayerStats).OnClientEvent:Connect(function(stats: any)
		if typeof(stats) ~= "table" then
			return
		end
		latestStats = stats
		refreshList()
	end)

	Remotes.get(Remotes.Names.StateChanged).OnClientEvent:Connect(function(state: any)
		if state ~= "LobbyIdle" and gui then
			gui.Enabled = false
		end
	end)

	-- panel-open interop: see PACKET_1_LOBBY_SYSTEMS.md "READ THIS FIRST" §3
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
		if panelName == "Journal" then
			Journal.open()
		end
	end)

	-- desktop convenience shortcut; mirrors PanicEmote's "+ E key on PC" precedent alongside its touch button
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.J then
			Journal.toggle()
		end
	end)
end

return Journal
```

### 5. Invite button

Entirely client-side: `SocialService:CanSendGameInviteAsync` → `SocialService:PromptGameInvite`, both `Util.safeCall`-wrapped, graceful disable-with-toast on failure. Wires via a `CollectionService` tag (`"InviteButtonTag"`) — generalizing R4's "find by tag, don't hard-wire" idea to a GUI element. A same-file fallback button ships behind a kill switch (default off).

`src/shared/Config.luau` — **ADD** to `Config.Features`:
```lua
InviteFallbackButton = false, -- DEFAULT off: the left-nav HUD owns the real Invite button. Flip
                               -- true only for standalone testing before that button exists/is tagged.
```

`src/client/Controllers/InviteButton.luau` (new):

```lua
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
```

*Note on exact `SocialService` API surface: `CanSendGameInviteAsync(player): boolean` and `PromptGameInvite(player)` are the current Roblox APIs as of this writing — double-check against the team's toolchain's API dump in case they've changed by the time this ships.*

**Studio-safety note:** unlike the join-squares mechanic, nothing here touches `TeleportService`. `SocialService:PromptGameInvite` is unlikely to do anything meaningful inside Studio Play — but the button already disables itself with a toast on any failure, so it degrades safely with zero special-casing: in Studio it'll most likely just show "Invites aren't available right now" instead of erroring.

*(Note: the Join-Squares track independently gives `LobbyHud.luau`'s Invite button its own inline `pcall(function() StarterGui:SetCore("PromptSendFriendInvite", Players.LocalPlayer) end)` implementation, using an older `StarterGui:SetCore` API rather than this track's `SocialService` API. Pick ONE — this track's `SocialService`-based `InviteButton.luau` is the more current/documented Roblox API and is recommended as the one to keep; if adopted, `LobbyHud.luau`'s Invite button should just tag itself `InviteButtonTag` and delete its own inline invite call, deferring to this controller.)*

### 6. Tutorial gate

**Field:** `tutorialDone: boolean` on `DataService.Stats`, **OR-merge**.

**Exact set point:** `ShiftManager.onBanishResolved`'s `correct` branch, via the new `ShiftManager.onShiftCleared` callback, wired in `QuestService.init` behind `Config.Features.TutorialGate`.

**COORDINATION — what the join-square UI spec should check:** listen for the `PlayerStats` remote and read `stats.tutorialDone`. Show the **Skip Tutorial** button only when `stats.tutorialDone == true`. **See "READ THIS FIRST" §5 above — there's an open design question about whether a Skip Tutorial button makes sense at all given this track's recommendation below.**

#### Recommendation: same map, guided first shift, not a separate map

**Recommendation: reuse the existing single workshop map for the tutorial, with light guided hints scoped to shift 1 only, plus the tutorial-done flag once complete. Do not build a second map.**

Rationale:
- The entire map is procedurally built at runtime by one `MapBuilder`. A genuinely separate tutorial map means either doubling that surface or standing up a second place via `TeleportService` — which **does not function inside Studio Play/Run mode** at all, directly contradicting R1 (solo is the golden path, first test is solo Play in Studio) and R8 (tiny map, one small site).
- A guided-first-shift approach costs almost nothing: `ShiftManager.currentObjective()` already exists and drives the HUD objective line; the tutorial variant is just a handful of extra one-time `Toast` hints gated on `shiftNumber == 1 and not stats.tutorialDone`.
- Reuses 100% of existing `DollService`/`GlyphService`/`BanishService`/`ShiftManager` logic — zero risk of the tutorial drifting out of sync with real gameplay.
- Trivially testable solo in Studio today, with no `TeleportService` dependency anywhere in the path.

This is a judgment call flagged for the team to override — but it's the right default given R1/R8 and the Studio-testing constraints already baked into this codebase.

### 7. Config additions summary

`src/shared/Config.luau` — new `Config.Quests` table and three new `Config.Features.*` keys:

```lua
	Features = {
		-- ...existing keys unchanged...
		Quests = true, -- DEFAULT on: Journal/quest claim + easter-egg triggers + ribbon-tie counter kill switch (R3)
		TutorialGate = true, -- DEFAULT on: tutorialDone tracking kill switch (R3), independent of Quests
		InviteFallbackButton = false, -- DEFAULT off: see §5
	},

	-- ...

	Quests = {
		StillnessSeconds = 20, -- DEFAULT: how long (seconds) to stand in the hidden spot for "Don't
		                       -- Move" -- long enough to feel deliberate, short enough not to bore a kid
		StillnessPollHz = 2, -- DEFAULT: matches LobbyService's existing ready-pad poll rate
	},
```

`src/shared/SoundConfig.luau` — optional, not required for MVP (Journal reuses the existing `UiConfirm` cue):
```lua
	QuestComplete = { soundId = 0, volume = 0.7 }, -- TODO(team): a small chime/page-turn cue, distinct from UiConfirm
```

### 8. Monetization compliance

No purchases of any kind in this section — quest rewards are coins granted for free upon completing an objective, no random outcome anywhere. MASTER.md §3.3 is not directly implicated by this track (it matters for the Shop/Classes track above, which actually sells things).

### 9. Toolbox / Creator Store asset ideas (decoration only)

- **Journal HUD button icon:** search for a free "quill pen icon" or "antique book icon."
- **Optional lobby flavor prop:** a free "low poly Victorian writing desk" or "old journal / ledger book" mesh.
- **Hidden-note prop polish:** swap the procedural `HiddenNote` part for a free "torn parchment / old paper" mesh or decal.
- **Claim celebration audio:** a short, free "chime" or "page turn" SFX for the optional `QuestComplete` cue.

**Compliance reminder (MASTER.md §3.4):** audit before use for (a) hidden scripts/backdoors, (b) third-party IP that could trigger a DMCA.

### Open questions / defaults chosen

- **`dollsCleared` reuse nuance:** doesn't count dolls consumed by a wrong banish, only commits at true `RunEnd` — pre-existing behaviors, worth the team knowing.
- **`perfectShifts` reuse for "5 correct banishes on the first try":** turned out to already track exactly this.
- **Coins field ownership overlap with Economy track:** see "READ THIS FIRST" §1.
- **Reward numbers** (15/60/150/40/100/50/45/20/20/25 coins) — all DEFAULT.
- **`Config.Quests.StillnessSeconds = 20`, `StillnessPollHz = 2`, and all three easter-egg world-position offsets** — DEFAULT guesses; need retuning once the real lobby geometry exists.
- **Tutorial gate design:** recommended same-map guided-first-shift over a separate map — see "READ THIS FIRST" §5 for the open "does Skip Tutorial still make sense" question this creates.
- **New `DataService` merge-rule generalization** (OR-boolean, per-key OR/union) and the `dirty`-table fix to `flushPlayer`'s gating — real, flagged deviations, not just additive changes.
- **`Logic/QuestProgress.luau` as a new shared module:** proposed beyond the minimum ask, for consistency with `GlyphMatch.luau`.
- **Hidden egg cards showing "???" until discovered:** this track's own UX choice — confirm the team likes it.

---

## Track C — Join Squares, Private-Server Transfer & Lobby Hub Loop

**Recommendation stated up front (full rationale in §2): build this as a single Roblox Place. Join squares hand a group off via `TeleportService:TeleportAsync` with `TeleportOptions.ShouldReserveServer = true`, which spins up a fresh private reserved instance *of this same place* — not a second, separately-published Place.**

### 0. Standalone context

Project Porcelain is a Roblox co-op haunted-doll horror game. Today, one Roblox Place contains both a **Lobby** area and a **Workshop** area, ~200 studs apart, built by `MapBuilder.build()` at server boot. A single server-wide state machine, `ShiftManager`, cycles `LobbyIdle → ShiftIntro → ShiftActive → ShiftResult → RunEnd → LobbyIdle`. Today, the only way into a shift is a single `ReadyPad` zone in the lobby. There is currently no privacy boundary at all — the "shift" is just a locked door in the same shared server everyone in the lobby is standing in.

The team wants to layer on a new lobby/economy system modeled on *Animal Hospital*'s loop: an open hub with 4–6 floor-tile "join squares" that fill up to 4 players, count down, and then drop that exact group into a **private** instance nobody else can join; plus a left-side HUD (Shop / Classes / Invite / Journal) for a new coin economy. **This section owns**: the join-square server system, the single-place-vs-two-places architecture call, the Studio-testability fallback, the bottom-of-screen join-square action UI, the generic left-side hub HUD shell, and the new Remotes this all needs.

### 1. Server-side join-square system

#### 1.0 New shared helper: `src/shared/ServerKind.luau` (ADD — new file)

Both the join-square resolve logic and `MapBuilder`'s conditional room-build need to agree on "what kind of server is this" — Studio, live public lobby, or live private shift instance. Lives once here to avoid duplicated/disagreeing boolean logic.

```lua
--!strict
-- ServerKind: single source of truth for "what kind of server is this," now that a shift can run
-- either in-place (Studio, or the Config.Features.PrivateShiftServers kill switch) or in a
-- dedicated live reserved private server (TeleportService:TeleportAsync + ShouldReserveServer).
-- MapBuilder and JoinSquareService both read this so their branches can never disagree.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any

local ServerKind = {}

-- True when this server should run the CURRENT single-server flow: MapBuilder builds both Lobby
-- and Workshop, and join squares resolve via ShiftManager.beginShiftFor instead of a real
-- cross-server teleport. True in Studio (TeleportService never functions there) OR when the team
-- has thrown Config.Features.PrivateShiftServers off (R3 escape hatch if live teleporting misbehaves).
function ServerKind.isSameServerMode(): boolean
	return RunService:IsStudio() or not Config.Features.PrivateShiftServers
end

-- True only for a live, published server that booted as a TeleportAsync-reserved instance.
function ServerKind.isReservedShiftServer(): boolean
	return (not ServerKind.isSameServerMode()) and game.PrivateServerId ~= ""
end

-- True for a live public server that is NOT a reserved shift instance -- i.e. the lobby.
function ServerKind.isPublicLobbyServer(): boolean
	return (not ServerKind.isSameServerMode()) and game.PrivateServerId == ""
end

return ServerKind
```

*Note: `game.PrivateServerId` is empty for every normal public server and every Studio session, and non-empty for both VIP/persistent private servers and `TeleportAsync`-reserved ones. This game has no VIP-private-server concept today, so "non-empty and not Studio" is sufficient. If the team ever adds VIP servers later, `isReservedShiftServer` will need a third branch (`game.PrivateServerOwnerId == 0` distinguishes reserved from owned) — a forward-compat note, not needed today.*

#### 1.1 CollectionService tag

**Tag name: `JoinSquare`.** Ownership: whichever module ends up building the winning hub layout (`MapBuilder`, per `PACKET_1_MAP_DESIGN.md`) is responsible for creating 4–6 `BasePart`s, tagging each `JoinSquare`, and giving each a unique `Name`. `JoinSquareService` discovers them purely via `CollectionService:GetTagged("JoinSquare")` — deliberate, so this service needs zero knowledge of which map layout wins.

#### 1.2 New service: `src/server/Services/JoinSquareService.luau` (ADD — new file)

Owns: per-square occupant set, countdown, idle/occupied/locking color + `N/4` billboard, Exit/Start Now/Skip Tutorial actions, resolving a square (in-place in Studio, real cross-server teleport live), and the **receiving** side of that handoff inside a freshly-booted reserved shift server.

```lua
--!strict
-- JoinSquareService: lobby floor-tile "join squares" (Animal-Hospital-style party assembly).
-- Each tagged part fills with 1..MaxGroupSize players, runs a countdown once the first player
-- steps on, then hands the group off to a shift -- either a fresh private reserved server (live)
-- or the existing in-place ShiftIntro flow (Studio / Config.Features.PrivateShiftServers=false).
-- Also owns the RECEIVING side of that handoff: in a live reserved shift server (no lobby, no
-- squares exist there) it waits for the expected arrivals and starts the shift the same way.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Util = require(Shared:WaitForChild("Util")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local ServerKind = require(Shared:WaitForChild("ServerKind")) :: any

local JOIN_SQUARE_TAG = "JoinSquare"

local JoinSquareService = {}

local ctx: any

type Phase = "Idle" | "Waiting" | "Locking"

type SquareState = {
	id: string,
	part: BasePart,
	occupants: { Player },
	phase: Phase,
	countdownGen: number,
	countdownActive: boolean,
}

local squares: { [BasePart]: SquareState } = {}

-- ---------- visuals ----------

local function colorFor(phase: Phase): Color3
	if phase == "Idle" then
		return Config.JoinSquares.IdleColor
	elseif phase == "Waiting" then
		return Config.JoinSquares.OccupiedColor
	else
		return Config.JoinSquares.LockingColor
	end
end

local function ensureLabel(square: SquareState): TextLabel
	local part = square.part
	local billboard = part:FindFirstChild("JoinSquareGui")
	if not billboard then
		local b = Instance.new("BillboardGui")
		b.Name = "JoinSquareGui"
		b.Adornee = part
		b.Size = UDim2.new(0, 160, 0, 60)
		b.StudsOffset = Vector3.new(0, 4, 0)
		b.MaxDistance = Config.JoinSquares.BillboardMaxDistance
		b.AlwaysOnTop = true
		b.Parent = part
		local label = Instance.new("TextLabel")
		label.Name = "Count"
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 1, 0)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(235, 228, 210)
		label.TextStrokeTransparency = 0.3
		label.Parent = b
		billboard = b
	end
	return (billboard :: BillboardGui):FindFirstChild("Count") :: TextLabel
end

local function refreshVisual(square: SquareState)
	square.part.Color = colorFor(square.phase)
	local label = ensureLabel(square)
	label.Text = ("%d/%d"):format(#square.occupants, Config.JoinSquares.MaxGroupSize)
end

-- ---------- broadcasts ----------

local function broadcastOccupancy(square: SquareState)
	local ids: { number } = {}
	for _, plr in square.occupants do
		table.insert(ids, plr.UserId)
	end
	Remotes.get(Remotes.Names.JoinSquareUpdate):FireAllClients(square.id, {
		count = #square.occupants,
		max = Config.JoinSquares.MaxGroupSize,
		occupantUserIds = ids,
		phase = square.phase,
	})
end

local function cancelCountdown(square: SquareState)
	local wasActive = square.countdownActive
	square.countdownActive = false
	square.countdownGen += 1 -- invalidates any in-flight countdown loop (see startCountdown)
	if wasActive then
		Remotes.get(Remotes.Names.JoinSquareCountdown):FireAllClients(square.id, nil)
	end
end

local function resetSquare(square: SquareState)
	square.occupants = {}
	square.phase = "Idle"
	cancelCountdown(square)
	broadcastOccupancy(square)
	refreshVisual(square)
end

-- ---------- resolve: Start Now, countdown hits zero, or auto-full ----------

local function resolveSquare(square: SquareState)
	if #square.occupants == 0 then
		return
	end
	cancelCountdown(square)
	square.phase = "Locking"
	broadcastOccupancy(square)
	refreshVisual(square)

	local occupants = table.clone(square.occupants)

	local function revertToWaiting(message: string)
		for _, plr in occupants do
			if plr.Parent then
				Remotes.get(Remotes.Names.Toast):FireClient(plr, message, 4)
			end
		end
		square.phase = "Waiting"
		broadcastOccupancy(square)
		refreshVisual(square)
	end

	if ServerKind.isSameServerMode() then
		-- Studio, or the live emergency kill switch: reuse ShiftManager's existing flow in-place.
		local ok = Util.safeCall("joinSquareBeginInPlace:" .. square.id, function()
			local started = ctx.services.ShiftManager.beginShiftFor(occupants)
			if not started then
				error("beginShiftFor declined -- ShiftManager state was not LobbyIdle")
			end
		end)
		if ok then
			resetSquare(square)
		else
			revertToWaiting("A shift is already starting elsewhere -- try again in a moment.")
		end
		return
	end

	-- Live: real cross-server private teleport.
	local userIds: { number } = {}
	for _, plr in occupants do
		table.insert(userIds, plr.UserId)
	end
	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions.ShouldReserveServer = true
	teleportOptions:SetTeleportData({
		kind = "Shift",
		squareId = square.id,
		expectedUserIds = userIds,
	})
	local ok = Util.safeCall("joinSquareTeleport:" .. square.id, function()
		TeleportService:TeleportAsync(game.PlaceId, occupants, teleportOptions)
	end)
	if ok then
		-- Occupants are leaving this server. Reset now rather than waiting for the next poll tick
		-- / PlayerRemoving to notice, so the tile doesn't sit "full" for stragglers mid-loading-screen.
		resetSquare(square)
	else
		revertToWaiting("Couldn't start the shift -- try again.")
	end
end

-- ---------- countdown ----------

local function startCountdown(square: SquareState)
	if square.countdownActive then
		return
	end
	square.countdownActive = true
	square.countdownGen += 1
	local gen = square.countdownGen
	task.spawn(function()
		for remaining = Config.JoinSquares.CountdownSeconds, 1, -1 do
			if square.countdownGen ~= gen then
				return -- cancelled (square emptied) or resolved (Start Now / auto-full) elsewhere
			end
			Remotes.get(Remotes.Names.JoinSquareCountdown):FireAllClients(square.id, remaining)
			task.wait(1)
		end
		if square.countdownGen == gen then
			resolveSquare(square)
		end
	end)
end

-- ---------- occupancy polling (LobbyService's ready-pad idiom, generalized to N squares) ----------

local function standingOn(part: BasePart): { Player }
	local size = Vector3.new(part.Size.X, Config.JoinSquares.DetectHeightPadding, part.Size.Z)
	local center = part.Position + Vector3.new(0, size.Y / 2, 0)
	local hits = workspace:GetPartBoundsInBox(CFrame.new(center), size)
	local seen: { [Player]: boolean } = {}
	local standing: { Player } = {}
	for _, hit in hits do
		local char = hit:FindFirstAncestorOfClass("Model")
		if char then
			local player = Players:GetPlayerFromCharacter(char)
			if player and not seen[player] then
				seen[player] = true
				table.insert(standing, player)
			end
		end
	end
	return standing
end

local function sameOccupants(a: { Player }, b: { Player }): boolean
	if #a ~= #b then
		return false
	end
	for i, plr in a do
		if b[i] ~= plr then
			return false
		end
	end
	return true
end

local function refreshSquare(square: SquareState)
	local newOccupants = standingOn(square.part)
	local wasEmpty = #square.occupants == 0
	local nowEmpty = #newOccupants == 0
	local changed = not sameOccupants(square.occupants, newOccupants)

	square.occupants = newOccupants

	if wasEmpty and not nowEmpty then
		square.phase = "Waiting"
		startCountdown(square) -- starts ONLY on first entrant into an empty square, per spec
	elseif not wasEmpty and nowEmpty then
		resetSquare(square) -- last occupant left (Exit button OR walked off) -- full reset
		return
	end

	if changed then
		broadcastOccupancy(square)
		refreshVisual(square)
	end

	if not nowEmpty
		and Config.JoinSquares.AutoStartOnFull
		and square.countdownActive
		and #square.occupants >= Config.JoinSquares.MaxGroupSize
	then
		resolveSquare(square)
	end
end

local function pollLoop()
	while true do
		task.wait(Config.JoinSquares.PollIntervalSeconds)
		for _, square in squares do
			Util.safeCall("joinSquarePoll:" .. square.id, refreshSquare, square)
		end
	end
end

-- ---------- square lifecycle ----------

local function registerSquare(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	if squares[inst] then
		return
	end
	local id = if inst.Name ~= "" then inst.Name else inst:GetDebugId()
	local square: SquareState = {
		id = id,
		part = inst,
		occupants = {},
		phase = "Idle",
		countdownGen = 0,
		countdownActive = false,
	}
	squares[inst] = square
	refreshVisual(square)
end

local function unregisterSquare(inst: Instance)
	local square = squares[inst]
	if square then
		cancelCountdown(square)
		squares[inst] = nil
	end
end

local function findSquareById(id: string): SquareState?
	for _, square in squares do
		if square.id == id then
			return square
		end
	end
	return nil
end

local function handleExit(player: Player, square: SquareState)
	local idx = table.find(square.occupants, player)
	if not idx then
		return
	end
	table.remove(square.occupants, idx)
	if #square.occupants == 0 then
		resetSquare(square)
	else
		broadcastOccupancy(square)
		refreshVisual(square)
	end
end

local function onJoinSquareAction(player: Player, squareId: any, action: any)
	if typeof(squareId) ~= "string" or typeof(action) ~= "string" then
		return
	end
	local square = findSquareById(squareId)
	if not square then
		return
	end
	if not table.find(square.occupants, player) then
		return -- server-authoritative: reject actions from players not actually standing here
	end
	if action == "Exit" then
		handleExit(player, square)
	elseif action == "StartNow" then
		resolveSquare(square)
	elseif action == "SkipTutorial" then
		Util.safeCall("joinSquareSkipTutorial", function()
			-- TODO(integration): see PACKET_1_LOBBY_SYSTEMS.md "READ THIS FIRST" §5 -- there is no
			-- TutorialService in this packet; the Social track's tutorial-gate design deliberately
			-- has no separate skippable flow. Resolve per the team's decision there before wiring
			-- this to a real function.
			if ctx.services.TutorialService and ctx.services.TutorialService.setSkipped then
				ctx.services.TutorialService.setSkipped(player)
			end
		end)
	end
end

-- ---------- receiving side: bootstrap a fresh reserved shift server ----------

local function bootstrapReservedServer()
	local expectedUserIds: { number }? = nil
	local started = false

	local function tryStart()
		if started or expectedUserIds == nil then
			return
		end
		local current = Players:GetPlayers()
		if #current >= #(expectedUserIds :: { number }) then
			started = true
			Util.safeCall("joinSquareBootstrapBegin", function()
				ctx.services.ShiftManager.beginShiftFor(current)
			end)
		end
	end

	local function captureTeleportData(player: Player)
		if expectedUserIds ~= nil then
			return
		end
		local ok, joinData = pcall(function()
			return player:GetJoinData()
		end)
		local data = ok and joinData and joinData.TeleportData
		if typeof(data) == "table" and typeof(data.expectedUserIds) == "table" then
			expectedUserIds = data.expectedUserIds
			-- R2 watchdog: start with whoever actually made it, even if the group arrives short.
			task.delay(Config.JoinSquares.ArrivalWatchdogSeconds, tryStart)
		end
	end

	for _, player in Players:GetPlayers() do
		captureTeleportData(player)
	end
	Players.PlayerAdded:Connect(function(player)
		captureTeleportData(player)
		task.defer(tryStart)
	end)
	task.defer(tryStart)
end

-- ---------- public API ----------

function JoinSquareService.init(context: any)
	ctx = context
	if not Config.Features.JoinSquares then
		return
	end

	if ServerKind.isReservedShiftServer() then
		bootstrapReservedServer()
		return -- no JoinSquare-tagged parts exist in a workshop-only server; nothing else to do
	end

	for _, inst in CollectionService:GetTagged(JOIN_SQUARE_TAG) do
		registerSquare(inst)
	end
	CollectionService:GetInstanceAddedSignal(JOIN_SQUARE_TAG):Connect(registerSquare)
	CollectionService:GetInstanceRemovedSignal(JOIN_SQUARE_TAG):Connect(unregisterSquare)

	Players.PlayerRemoving:Connect(function(player)
		for _, square in squares do
			if table.find(square.occupants, player) then
				handleExit(player, square)
			end
		end
	end)

	Remotes.get(Remotes.Names.JoinSquareAction).OnServerEvent:Connect(onJoinSquareAction)

	task.spawn(pollLoop)
end

-- Called by ShiftManager's RunEnd branch when a live reserved shift server's run ends, to hand
-- the group back to the public lobby. No-op in same-server mode -- ShiftManager's own existing
-- in-place teleport-to-lobbySpawn already covers that case.
function JoinSquareService.sendGroupHome(players: { Player })
	if #players == 0 or ServerKind.isSameServerMode() then
		return
	end
	local ok = Util.safeCall("joinSquareSendHome", function()
		TeleportService:TeleportAsync(game.PlaceId, players)
	end)
	if not ok then
		for _, plr in players do
			if plr.Parent then
				Remotes.get(Remotes.Names.Toast):FireClient(
					plr,
					"Couldn't return to the lobby automatically -- try rejoining.",
					6
				)
			end
		end
	end
end

return JoinSquareService
```

Assumption flagged: `findSquareById`/broadcast payloads assume each `JoinSquare`-tagged part has a unique `Name`. `registerSquare` falls back to `inst:GetDebugId()` when `Name` is empty, but two tiles sharing a non-empty name would collide.

**Integration touch-points this needs outside its own new files:**

- `ShiftManager.luau` — **ADD** one new public function (does not touch any existing function):
  ```lua
  function ShiftManager.beginShiftFor(occupants: { Player })
  	if state ~= "LobbyIdle" then
  		return false
  	end
  	if #occupants == 0 then
  		return false
  	end
  	participants = table.clone(occupants)
  	transition("ShiftIntro") -- the exact same internal call requestStart's own countdown uses
  	return true
  end
  ```
  This is literally the same `participants = ...; transition("ShiftIntro")` pair `requestStart`'s countdown already runs at zero — `ShiftIntro → ShiftActive → ShiftResult → RunEnd` then proceeds unmodified.
  Also **ADD** a require: `local ServerKind = require(Shared:WaitForChild("ServerKind")) :: any`, and in the `RunEnd` branch, replace the unconditional
  ```lua
  teleportTo(ctx.manifest.lobbySpawn, participants)
  ```
  with:
  ```lua
  if ServerKind.isReservedShiftServer() then
  	Util.safeCall("sendGroupHome", function()
  		ctx.services.JoinSquareService.sendGroupHome(participants)
  	end)
  else
  	teleportTo(ctx.manifest.lobbySpawn, participants)
  end
  ```
  (A live reserved shift server has no `lobbySpawn` to PivotTo — see §2 — so the run-end return trip needs to be a real teleport there instead.) **See "READ THIS FIRST" §2 above for exactly where this sits relative to the Economy/Social tracks' own edits to `RunEnd`/`onBanishResolved`.**

- `src/server/init.server.luau` (integration-owned) — **ADD** `JoinSquareService` to the `require(...)` block, `ctx.services`, and `initOrder` (placing it right after `"ShiftManager"` reads most naturally).

- `Config.luau` — see §"Config additions" below.

- `MapBuilder.luau` — see §2's conditional-build description; also note `LobbyService.setShiftSpawnActive` is *already* nil-safe for a manifest missing one spawn, so it needs no change. One real gap: in a workshop-only server, `workshopSpawn` should default `Enabled = true` at creation (not today's `false`) — there's no lobby spawn there to protect against, and arriving `TeleportAsync` players need *somewhere* enabled to land the instant the server boots.

- Heads-up, not fixed here: `DebugService`'s existing `/skipstate` etc. assume a Workshop always exists in this server. Once MapBuilder goes lobby-only vs. workshop-only for live servers, those commands should probably be guarded (they're harmless in Studio, where both rooms still build).

### 2. Two Places vs. one Place + `ReserveServer` — resolved

**Pick: one Place.** Join squares hand groups off with `TeleportService:TeleportAsync(game.PlaceId, players, teleportOptions)` where `teleportOptions.ShouldReserveServer = true` — a fresh, private, non-joinable-by-outsiders instance *of this same experience*, not a second published Place.

**The reframe that makes this an easy call:** the team's actual requirement is "nobody outside the original group can join." A reserved server gets that *for free*, by Roblox's own design. **Splitting into two Places does not avoid needing this mechanism** — a second Place would still be a normal public place unless it *also* used `ReserveServer`/`TeleportAsync`. So "two Places" isn't a real alternative to reserved servers; it's reserved servers *plus* a second Place layered on top, for zero additional privacy benefit.

| | One Place + `ReserveServer` (recommended) | Two Places |
|---|---|---|
| Privacy from outsiders | Free — Roblox's reserved-server access control | Same mechanism still required on the second place |
| Publishing/maintenance | One Rojo project, one publish button, one place to decorate/audit in Studio | Two of everything, kept in sync by hand |
| Code/config duplication | `Config`, `Remotes`, `Defs/*`, `Theme` stay single-source | Duplicated, or a shared-package build step |
| Concurrency across groups | Each reserved server is its own process with its own fresh Lua globals — `ShiftManager`/`DollService`/`GlyphService`'s existing *singleton* design works for concurrent groups completely unmodified | Same benefit, but only inside the second place |
| One-time engineering cost | `MapBuilder` needs a Lobby-only-vs-Workshop-only conditional build + small `ShiftManager`/`JoinSquareService` additions | A second place's own bootstrap, its own copy of the shift loop, its own asset decoration pass |
| Team workflow (MCP/Toolbox) | One place to `start_stop_play`, decorate, publish in | Two places to remember to do all of that in |

The one real, bounded cost: **`MapBuilder.build()` must build either the Lobby or the Workshop, not both, depending on server kind.** Using `ServerKind`:

```lua
-- ILLUSTRATIVE shape of the change inside MapBuilder.build() -- not this section's file to rewrite.
local buildLobby = ServerKind.isSameServerMode() or ServerKind.isPublicLobbyServer()
local buildWorkshop = ServerKind.isSameServerMode() or ServerKind.isReservedShiftServer()

if buildLobby then
	-- existing Lobby room builder, unchanged, PLUS the new join-square tiles (see 1.1)
end
if buildWorkshop then
	-- existing Bench room / Storage alcove / Ledger desk / Hallway / Banish room builders,
	-- unchanged, EXCEPT workshopSpawn defaults Enabled = true here (see 1.2's integration note)
end
```

Because `ServerKind.isSameServerMode()` is `true` in Studio, this is a *strict superset* of today's behavior there — Studio keeps building both rooms in one server exactly as it does now. The only servers that ever see a lobby-only or workshop-only map are live, published, non-Studio servers, which don't exist yet — this cannot regress anything currently playable.

*(Note: `PACKET_1_MAP_DESIGN.md`'s winning layout uses two separate origin constants, `HUB` and `WS`, already teleport-only — this conditional-build approach composes directly with that layout without further changes.)*

### 3. Studio-testing caveat: `TeleportService` does not function in Studio Play/Run

`RunService:IsStudio()` is the correct signal — **not** `Config.DebugMode`. They answer different questions: `IsStudio()` tells you whether `TeleportService` calls can possibly work at all. `Config.DebugMode` is an independent, team-toggleable feature flag (R7) the team may well leave **on** in a *live, published* server too. Gating the teleport branch on `DebugMode` would be wrong in both directions.

**One value-add beyond what was asked**, in R3's spirit: `ServerKind.isSameServerMode()` is actually `RunService:IsStudio() or not Config.Features.PrivateShiftServers`. That second half is a live *emergency* escape hatch — if real cross-server teleporting ever misbehaves in production, the team can flip `Config.Features.PrivateShiftServers = false` and the game reverts, server-wide, to today's exact single-shared-server behavior, because **the same flag also drives `MapBuilder`'s conditional build**, so a live public server under this flag builds both Lobby and Workshop again, exactly like Studio does.

**Concretely, what happens in Studio:** `JoinSquareUpdate`/`JoinSquareCountdown` broadcast and the bottom-of-screen UI render identically to live. When the 30s countdown reaches zero (or a player presses Start Now), `resolveSquare` takes the `ServerKind.isSameServerMode()` branch and calls `ShiftManager.beginShiftFor(occupants)` — the exact same `transition("ShiftIntro")` call the existing ready-pad's own countdown makes today. Everything downstream is **byte-for-byte the same code path already in the repo today** — nothing about the actual shift loop changes for Studio testing.

### 4. Bottom-of-screen join-square UI: `src/client/Controllers/JoinSquareUI.luau` (ADD — new file)

Shown only while the local player is standing in a join square. Follows `BanishConfirmUI.luau`'s panel-with-buttons construction, bottom-anchored (mobile-first, touch targets ≥ 64px).

```lua
--!strict
-- Bottom-of-screen action bar shown while the local player stands inside a Join Square:
-- Exit / Skip Tutorial (only once unlocked) / Start Now. Mirrors BanishConfirmUI's panel-with-
-- buttons construction, bottom-anchored instead of center-anchored (mobile-first).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local SoundKit = require(Shared:WaitForChild("SoundKit")) :: any
local Theme = require(script.Parent.Parent:WaitForChild("Theme")) :: any

local JoinSquareUI = {}

local localPlayer = Players.LocalPlayer

local gui: ScreenGui? = nil
local countdownLabel: TextLabel? = nil
local exitButton: TextButton? = nil
local skipButton: TextButton? = nil
local startButton: TextButton? = nil
local currentSquareId: string? = nil

-- TODO(integration): replace with a real read of whatever tutorialDone-equivalent flag/remote the
-- Social track's PlayerStats remote provides (stats.tutorialDone). See PACKET_1_LOBBY_SYSTEMS.md
-- "READ THIS FIRST" §5 for the open question about whether this button should exist at all.
local function isTutorialDone(): boolean
	return false
end

local function build()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local g = Theme.screenGui("PorcelainJoinSquare", 12)
	g.Enabled = false
	g.Parent = playerGui
	gui = g

	local panel = Theme.panel(g, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.new(0.94, 0, 0, 150),
		BackgroundTransparency = 0.06,
	})
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MaxSize = Vector2.new(560, 220)
	sizeConstraint.MinSize = Vector2.new(300, 150)
	sizeConstraint.Parent = panel

	countdownLabel = Theme.label(panel, {
		Position = UDim2.new(0, 16, 0, 10),
		Size = UDim2.new(1, -32, 0, 28),
		TextSize = 18,
		TextColor3 = Theme.Accent,
		Text = "",
	})

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.new(0, 16, 0, 46)
	row.Size = UDim2.new(1, -32, 0, 84)
	row.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = row

	-- Colors match the reference screenshots exactly: EXIT red, START NOW green, the middle
	-- (Skip Tutorial) button left at the theme's neutral default -- the reference shows it
	-- visibly blanked/disabled-looking whenever it's locked, which Theme.BgSoft + a disabled
	-- Active=false already achieves without a bespoke color (see isTutorialDone() gating below).
	local function actionButton(text: string, bg: Color3?): TextButton
		local button = Theme.button(row, {
			Size = UDim2.new(0.31, 0, 1, 0), -- relative width: scales down gracefully on narrow phones
			TextSize = 18,
			Text = text,
		})
		if bg then
			button.BackgroundColor3 = bg
		end
		return button
	end

	exitButton = actionButton("EXIT", Theme.Danger) -- red, matches the reference
	skipButton = actionButton("SKIP TUTORIAL")
	skipButton.Visible = false
	startButton = actionButton("START NOW", Color3.fromRGB(70, 160, 80)) -- green, matches the reference
		-- (no confirmed Theme.* "success green" token exists yet in this codebase's Theme.luau --
		-- using an explicit literal here; if the team adds one, swap this for Theme.Success instead)

	exitButton.Activated:Connect(function()
		if not currentSquareId then
			return
		end
		SoundKit.play("UiClick")
		Remotes.get(Remotes.Names.JoinSquareAction):FireServer(currentSquareId, "Exit")
	end)
	startButton.Activated:Connect(function()
		if not currentSquareId then
			return
		end
		SoundKit.play("UiConfirm")
		Remotes.get(Remotes.Names.JoinSquareAction):FireServer(currentSquareId, "StartNow")
	end)
	skipButton.Activated:Connect(function()
		if not currentSquareId then
			return
		end
		SoundKit.play("UiClick")
		Remotes.get(Remotes.Names.JoinSquareAction):FireServer(currentSquareId, "SkipTutorial")
	end)
end

local function setVisible(visible: boolean)
	local g = gui
	if not g then
		return
	end
	g.Enabled = visible
	if not visible then
		currentSquareId = nil
	end
end

function JoinSquareUI.init()
	build()

	Remotes.get(Remotes.Names.JoinSquareUpdate).OnClientEvent:Connect(function(squareId: any, data: any)
		if typeof(squareId) ~= "string" or typeof(data) ~= "table" then
			return
		end
		local occupantIds = data.occupantUserIds
		local isLocalHere = typeof(occupantIds) == "table"
			and table.find(occupantIds, localPlayer.UserId) ~= nil
		if isLocalHere then
			currentSquareId = squareId
			setVisible(true)
			if skipButton then
				skipButton.Visible = isTutorialDone()
			end
		elseif currentSquareId == squareId then
			-- we were in this square and just dropped out of its occupant list (Exit / walked away)
			setVisible(false)
		end
	end)

	Remotes.get(Remotes.Names.JoinSquareCountdown).OnClientEvent:Connect(function(squareId: any, seconds: any)
		if squareId ~= currentSquareId or not countdownLabel then
			return
		end
		countdownLabel.Text = if typeof(seconds) == "number"
			then ("Shift starts in %d… (Exit to leave the group)"):format(seconds)
			else "Waiting for your group…"
	end)
end

return JoinSquareUI
```

Add `"JoinSquareUI"` to `src/client/init.client.luau`'s `ORDER` list (integration-owned file).

### 5. Left-side lobby HUD: `src/client/Controllers/LobbyHud.luau` (ADD — new file)

**Placement/approach: pure `ScreenGui`, not a physical 3D kiosk.** A screen-anchored HUD works identically regardless of the hub's geometry (the map redesign in `PACKET_1_MAP_DESIGN.md` already puts physical kiosk buildings in the world too — Shop/Classes/Journal prompts on those buildings and this HUD bar are complementary, not exclusive, exactly as the reference screenshots show both a physical kiosk AND a HUD button working for the same feature). Left-anchored, vertically stacked bottom-up in the bottom-left corner, buttons ≥ 64px tall. Gated on `StateChanged` the way `Hud.luau` already gates its own doll-checklist visibility.

```lua
--!strict
-- Left-side lobby hub HUD: Shop / Invite / Classes / Journal, in that order (matches the team's own
-- description and the reference screenshots exactly). Pure ScreenGui (no 3D kiosk) so it drops into
-- any hub layout unchanged. Visible only in LobbyIdle, hidden during any active-shift state.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
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
	inviteButton.Activated:Connect(function()
		SoundKit.play("UiClick")
		-- NOTE: per PACKET_1_LOBBY_SYSTEMS.md "READ THIS FIRST" §3, the Social track's
		-- InviteButton.luau (SocialService-based, more current API) is the recommended
		-- implementation -- tag this button "InviteButtonTag" via CollectionService and delete
		-- this inline pcall block instead of keeping both. Left as a working fallback below in the
		-- meantime, and it's exactly what the reference's own native "Invite Friends" dialog does.
		pcall(function()
			StarterGui:SetCore("PromptSendFriendInvite", Players.LocalPlayer)
		end)
	end)
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
```

Add `"LobbyHud"` to `src/client/init.client.luau`'s `ORDER` list (integration-owned file).

**Invite is a native Roblox prompt the player operates themselves** — this is a code call the client makes on the player's own explicit tap, not something sent on anyone's behalf; no chat/social action fires without the player pressing the button.

### 6. New Remotes (ADD to `src/shared/Remotes.luau`'s `DEFS` table)

| Remote | Direction | Payload | Notes |
|---|---|---|---|
| `JoinSquareUpdate` | Server → Client | `(squareId: string, data: {count: number, max: number, occupantUserIds: {number}, phase: "Idle"\|"Waiting"\|"Locking"})` | Fired only when a square's occupant set actually changes. Drives both the world billboard/color and whether the bottom UI shows for the local player. |
| `JoinSquareCountdown` | Server → Client | `(squareId: string, secondsLeft: number?)` | Modeled on the existing `ReadyCountdown` (`nil` cancels), extended with `squareId` since multiple squares run concurrent countdowns. |
| `JoinSquareAction` | Client → Server | `(squareId: string, action: "Exit" \| "StartNow" \| "SkipTutorial")` | Folds three buttons into one remote, mirroring the existing `ConfirmBanish(confirm: boolean)` idiom. Server validates the sender is actually an occupant before doing anything. |

```lua
-- ADD to Remotes.luau's DEFS table:

	-- Server -> Client (join squares / private-server transfer)
	JoinSquareUpdate = "Event", -- (squareId: string, data: {count, max, occupantUserIds: {number}, phase: string})
	JoinSquareCountdown = "Event", -- (squareId: string, secondsLeft: number?) nil cancels -- mirrors ReadyCountdown

	-- Client -> Server (join squares)
	JoinSquareAction = "Event", -- (squareId: string, action: "Exit" | "StartNow" | "SkipTutorial")
```

### Config additions (ADD to `src/shared/Config.luau`)

```lua
-- inside the existing Features table:
Features = {
	...
	JoinSquares = true, -- R3 kill switch: false disables the whole subsystem; the old single ReadyPad
	                     -- (LobbyService + ShiftManager.requestStart) is untouched and keeps working.
	PrivateShiftServers = true, -- R3 kill switch: false makes JoinSquareService ALWAYS resolve
	                             -- in-place via ShiftManager.beginShiftFor, even live -- the same
	                             -- flag MapBuilder reads (via ServerKind) to build both rooms again.
	                             -- Emergency escape hatch if live TeleportAsync/ReserveServer misbehaves.
},

-- new top-level table:
JoinSquares = {
	MaxGroupSize = 4, -- matches PLAN.md's existing "up to 4-player co-op" cap.
	CountdownSeconds = 30, -- team-specified exact number (not a default).
	AutoStartOnFull = true, -- DEFAULT -- flag to team: collapses the countdown early once the square
	                         -- hits MaxGroupSize, matching the reference game's "party's full" feel.
	PollIntervalSeconds = 0.5, -- DEFAULT -- mirrors LobbyService's existing 2 Hz ready-pad poll rate.
	DetectHeightPadding = 6, -- DEFAULT -- box height for GetPartBoundsInBox; XZ footprint is read
	                          -- from the tile part's own Size so this self-scales.
	BillboardMaxDistance = 50, -- DEFAULT -- same order of magnitude as Config.Lobby.BillboardMaxDistance.
	ArrivalWatchdogSeconds = 15, -- DEFAULT -- R2: a reserved shift server starts with whoever has
	                              -- actually arrived after this long, even if short of the full group.
	IdleColor = Color3.fromRGB(70, 160, 220), -- UPDATED 2026-08-15 to match the reference screenshots'
	                                            -- idle join squares exactly: cyan-blue, not purple.
	OccupiedColor = Color3.fromRGB(230, 210, 40), -- UPDATED 2026-08-15 -- reference squares turn a
	                                                -- bright yellow the instant someone steps in, per
	                                                -- the team's own "turn yellow when occupied" spec.
	LockingColor = Color3.fromRGB(212, 175, 96), -- DEFAULT -- Theme.Gold; reads as "committing." No
	                                               -- reference shot happened to catch this transient
	                                               -- phase, kept as a reasonable in-between color.
},
```

**Geometry note for whoever builds the physical tiles (`MapBuilder`, per `PACKET_1_MAP_DESIGN.md`),
not this service's own code:** the reference screenshots show each join square as a **hollow neon
diamond outline** (a rotated square traced by a thin glowing border, like a picture frame on the
ground) rather than a filled tile — closer to 4 thin `Neon`-material frame parts arranged in a
rotated-square perimeter than the single filled `Part` this packet's illustrative `MapBuilder`
snippet in Track C §1.1 sketches. `JoinSquareService.colorFor`/`refreshVisual` above don't care which
construction is used (they just set `.Color` on whatever `BasePart` is tagged `JoinSquare`) — but if
the team wants the exact hollow-diamond look, the tagged part should be the frame/outline group's
primary part (or the whole thing built as a `Model` with `PrimaryPart` set to a part `refreshVisual`
can safely recolor), not a solid tile. Flag to whoever implements the real tiles.

*(Note: `PACKET_1_MAP_DESIGN.md`'s own manifest notes propose a slightly different `Config.Lobby.JoinSquareCount`/`JoinSquarePlayerCap`/`JoinSquareCountdownSeconds` naming — reconcile to this track's `Config.JoinSquares.*` table when implementing, since this track's service code is what actually reads these keys.)*

### SoundConfig additions (ADD to `src/shared/SoundConfig.luau`)

```lua
	-- Join squares
	SquareLockIn = { soundId = 0, volume = 0.7 }, -- TODO(team): satisfying "lock-in" chime when a
	                                                -- square resolves. UiClick/UiConfirm already cover ordinary button taps.
```

### DataStore / R5 applicability

**None of this section persists anything new.** No new player stat, no `getStats`/`recordRun` shape change, no new merge semantics. Coins, owned classes, and the tutorial-done flag belong to the Economy and Social tracks respectively.

### Money/purchases

**None of this section sells anything.** Join squares, the transfer mechanism, and the HUD shell are pure navigation/matchmaking scaffolding — the Economy track (which does need MASTER.md §3.3's fixed-outcome-only rule) is a different track.

### Asset policy — Toolbox suggestions for this part

All search ideas, not asset IDs — audit per MASTER.md §3.4 before use.

- Join-square dressing: **"low poly wooden queue post"** or **"velvet rope stanchion"**.
- A static "gather your dollkeepers" sign: **"antique wooden sign board"** or **"vintage shop sign"**.
- Square lock-in cue: **"music box wind-up click"** or **"wooden latch click"**.
- Left-HUD button icons (optional): **"hand-drawn ink icon pack"** or **"vintage postage stamp icon set"**.

### Open questions / defaults chosen

- **`RunService:IsStudio()` over `Config.DebugMode`** for the live-vs-in-place branch — justified in §3.
- **Single Place + `TeleportAsync`/`ShouldReserveServer`** over two Places — justified in §2.
- **`AutoStartOnFull = true`** — DEFAULT, flag if the team wants to always show the full 30s.
- **`MaxGroupSize = 4`** tied to the existing co-op cap.
- **`CountdownSeconds = 30`** is the team's own stated number, not a default.
- **`PollIntervalSeconds`, `DetectHeightPadding`, `BillboardMaxDistance`, `ArrivalWatchdogSeconds`, and the three phase colors** are all DEFAULT.
- **`JoinSquareAction` folds Exit/StartNow/SkipTutorial into one remote** — mirrors the existing `ConfirmBanish(bool)` convention.
- **`Config.Features.JoinSquares` and `Config.Features.PrivateShiftServers`** are two separate kill switches.
- **`PorcelainOpenPanel` BindableEvent** — see "READ THIS FIRST" §3 for the cross-track reconciliation.
- **`isTutorialDone()` stub always returns `false`** in `JoinSquareUI.luau` — see "READ THIS FIRST" §5.
- **`ShiftManager.beginShiftFor` and the `RunEnd` teleport-vs-`sendGroupHome` branch** — additive, don't rename or remove anything existing.
- **Left HUD placement**: bottom-left vertical column, pure `ScreenGui`, scale-sized — layout-agnostic by design.
