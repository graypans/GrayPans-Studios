# CHECKLIST 1 — Lobby / Map Re-imagining + First-Playtest Bug Fixes

**Naming convention:** `CHECKLIST_<n>.md` at repo root, one per work batch. `CHECKLIST_1` = this file. Future batches:
`CHECKLIST_2.md`, `CHECKLIST_3.md`… each with a one-line title. Items are `[ ]` todo / `[x]` done / `[~]` in progress /
`[?]` needs a team decision. Each item has an ID (`L1`, `S3`, `A2`, `B7`…) so chat can reference it ("do L1–L4 first").

**Status:** Team gave the green light 2026-08-15. 11 agents drafted full implementation specs (map layouts + patches +
lobby systems) the same day — **see §7 below**. Drive folder was then shared publicly and reviewed the same day; all
9 reference screenshots' concrete details (button order, join-square shape/colors, kiosk style, bottom action-bar
colors, two-leaderboard split, billboard content) are folded into the packets below. Team also confirmed keeping
Classes as its own separate screen (not merged into Shop) — done, see §7. Nothing has been coded yet; the specs are
ready for the cloud Claude session to review, resolve the flagged conflicts, and implement. Local Claude will verify
each landed piece in Studio.
**Source of the lobby model:** Animal Hospital (Anomaly) lobby — team's own written description plus 9 reference
screenshots (https://drive.google.com/drive/folders/1or2UfCS4asCnXeMOsVsNTrJnaAtWQexz, reviewed 2026-08-15).
**Bug source:** `docs/PLAYTEST_REPORT_2026-08-15.md` (first-ever run, 2026-08-15).

---

## §7 — IMPLEMENTATION PACKETS (ready for cloud Claude)

Three documents, ~11 agents' worth of grounded, code-ready specs, produced 2026-08-15:

- **[docs/packets/PACKET_1_MAP_DESIGN.md](docs/packets/PACKET_1_MAP_DESIGN.md)** — 3 competing hub+workshop layouts
  ("Thimble Row" dead-end street, "Hollow Court" claustrophobic atrium, "Hollow Square" town square+fountain) plus a
  judge/synthesis pass. **Recommendation: "Hollow Square" as the base, with 3 named grafts from the other two** — read
  §4 of that doc for the full reasoning, scoring table, and the final "ready to build" room list + coordinates.
- **[docs/packets/PACKET_1_PATCHES.md](docs/packets/PACKET_1_PATCHES.md)** — exact before/after Luau for every blocker
  (A1–A4) and bug (B1–B13), grounded in the real current file contents. **Has its own "READ THIS FIRST" merge-order
  note** — two of the four patch clusters both give full replacements of `ShiftManager.transition()`/`armWatchdog()`
  and must be merged by hand, not pasted sequentially.
- **[docs/packets/PACKET_1_LOBBY_SYSTEMS.md](docs/packets/PACKET_1_LOBBY_SYSTEMS.md)** — full specs for Economy
  (coins/classes/shop), Social (journal/quests/invite/tutorial-gate), and Join Squares (private-server transfer +
  left-nav HUD), each with real Luau for every new file. **Also has a "READ THIS FIRST" section** — the 3 tracks
  independently invented conflicting `DataService.luau` rewrites, a `ShiftManager.luau` insertion order that layers on
  top of the patches packet's own merge, and two incompatible panel-open UI conventions. All flagged with a
  recommended resolution.

**Before coding starts, the team should skim each packet's "READ THIS FIRST"/judge section and either approve the
recommended defaults or override them** — nothing is blocked on this (every open question has a stated default), but
cheaper to correct now than after cloud Claude has built against it.

**Updated 2026-08-15 after reviewing the team's Drive screenshots:** all three packets now also have a section
folding in concrete details confirmed against the actual reference (button order, join-square shape/colors, kiosk
style, the bottom action-bar's exact colors, a two-leaderboard split, and per-player billboards showing the equipped
class) — see `PACKET_1_MAP_DESIGN.md` §5 and `PACKET_1_LOBBY_SYSTEMS.md`'s updated Track A §6b/Track C sections.
Classes is confirmed as its own separate screen (not merged into Shop) per the team's decision.

---

## §0 — Order of operations (updated)

1. `[x] O1` Team reviewed this checklist → green light given 2026-08-15.
2. `[~] O2` **Blockers A1–A4** — stopgap patches for the CURRENT map are drafted in `PACKET_1_PATCHES.md` §P1/§A4 so a
   run can be finished today even before the redesign lands. Not yet applied to the repo.
3. `[~] O3` **Map re-imagining** (§1) — 3 layouts + judge synthesis done, see `PACKET_1_MAP_DESIGN.md`. Awaiting team
   sign-off on the recommended "Hollow Square" synthesis (or a different pick) before cloud Claude implements L12.
4. `[~] O4` **Lobby systems** (§2) — full specs done for join squares → coins → classes/shop → journal → invite →
   tutorial-gate, see `PACKET_1_LOBBY_SYSTEMS.md`. Awaiting the team's read of that doc's integration-conflicts
   section before cloud Claude implements.
5. `[~] O5` **Bug list B1–B13** (§4) — specs done in `PACKET_1_PATCHES.md`, batchable with O3/O4.
6. `[ ] O6` Re-playtest via local Claude + humans (§5 items need hands/multi-client) — after O2–O5 land.

---

## §1 — MAP RE-IMAGINING (design)

### 1A. Zones (in player order)
- `[~] L1` **Spawn area (outdoors, "hub").** `[?]` **Resolved by the judge pass:** a dead Victorian town square built
  around a broken fountain, facing the Dollmaker's one lit shopfront ("Hollow Square") — see
  `PACKET_1_MAP_DESIGN.md` §4. Team can override; the other two proposals (dead-end street, claustrophobic alley+atrium)
  are preserved in full in that same doc if preferred.
- `[~] L2` **Join squares.** Full server + client spec (occupancy, countdown, colors, billboard, Exit/Start
  Now/Skip Tutorial) in `PACKET_1_LOBBY_SYSTEMS.md` Track C §1/§4. Physical tile placement is part of the picked map
  layout (§L1).
- `[~] L3` **Shop kiosk / storefront window.** Physical building in the "Hollow Square" layout (`ShopKiosk` tag);
  service+UI in `PACKET_1_LOBBY_SYSTEMS.md` Track A.
- `[x] L4` **Classes.** `[?]` **Resolved — team confirmed 2026-08-15: keep as its own separate screen**, not folded
  into Shop. Physical `ClassesKiosk` building in the map layout (matches the reference's round-glow kiosk); dedicated
  `Classes.luau` client Controller (list + lock icons + equip, styled after the reference) added in
  `PACKET_1_LOBBY_SYSTEMS.md` Track A §6b. `Shop.luau` stays the buy surface.
- `[~] L5` **Journal / noticeboard.** Physical `JournalKiosk` building in the map layout; service+UI in
  `PACKET_1_LOBBY_SYSTEMS.md` Track B.
- `[~] L6` **Leaderboard + best-shift billboards.** Facing-direction fix in `PACKET_1_PATCHES.md` B1; relocated onto
  the Shop facade in the picked map layout.
- `[~] L7` **The workshop.** Redesigned as one continuous floor/ceiling slab with zero interior walls (open archways
  only) in `PACKET_1_MAP_DESIGN.md` §4.3.2 — structurally cannot reproduce the A1/A2 sealed-room bugs, not just
  carefully avoids them. Reached only by `ShiftIntro`'s existing teleport, no walked corridor.
- `[~] L8` **Tutorial variant.** `[?]` **Resolved (recommendation):** no separate map — guided one-time hints on shift
  1 only, suppressed once `tutorialDone`. See `PACKET_1_LOBBY_SYSTEMS.md` Track B §6 for full rationale. This also
  raises an open question about whether the "Skip Tutorial" button still makes sense — see that doc's "READ THIS
  FIRST" §5.

### 1B. Process
- `[x] L9` 3 design agents ran, each committed to one angle without seeing the others — see `PACKET_1_MAP_DESIGN.md` §1–3.
- `[x] L10` Judge/synthesis agent scored all 3 and produced a final recommendation — `PACKET_1_MAP_DESIGN.md` §4.
- `[ ] L11` **Still needed:** feed the picked/synthesized layout to ChatGPT image gen for a bird's-eye reference (art
  direction only); local Claude places Creator Store props via MCP once the code layout exists in Studio.
- `[ ] L12` **Still needed:** cloud Claude rewrites `MapBuilder` from `PACKET_1_MAP_DESIGN.md` §4's "ready to build"
  section (includes the doorway-gap-discipline code and slab-based Workshop builder already written out).

---

## §2 — LOBBY SYSTEMS (new gameplay/economy)

Full specs for all of S1–S10 are in **`PACKET_1_LOBBY_SYSTEMS.md`** (3 tracks: Economy, Social, Join Squares) —
read that document's "READ THIS FIRST" section before implementing any of the items below, since several of them
touch the same files.

- `[~] S1` **Join squares → private servers.** `[?]` **Resolved (recommendation):** single Roblox Place +
  `TeleportService:TeleportAsync` with `ShouldReserveServer = true` — not two separate places. Full rationale +
  comparison table in Track C §2. Studio fallback (`RunService:IsStudio()` branch) preserves today's in-place testing.
- `[~] S2` **Coins.** `[?]` **Resolved (defaults):** 7 coins/doll cared for, +15 perfect-shift bonus, +3/shift above 1
  capped at shift 6 (max +15). Full `DataService` merge-rule design in Track A §1–2.
- `[~] S3` **Classes.** `[?]` **Resolved (defaults):** 6-class launch roster (Apprentice free/none, Ribbon-Ready 100,
  Swift Hands 120, Keen Eye 140, Steady Nerves 150, Penny-Pincher 200) — full `Defs/Classes.luau` code in Track A §3.
  Kept as its own dedicated screen (`Classes.luau`, Track A §6b) per the team's decision — buy in Shop, equip in
  Classes. Reference screenshots also show a per-class outfit + level/XP system — explicitly deferred to a future
  checklist, not part of this batch (see `PACKET_1_MAP_DESIGN.md` §5).
- `[~] S4` **Shop menu.** Full `Shop.luau` client Controller + `ClassService.luau` server in Track A §4/§6.
- `[~] S5` **Journal (quests).** 10-quest launch roster (7 milestone + 3 easter-egg) with full `Defs/Quests.luau`,
  `QuestService.luau`, `Journal.luau` in Track B §1/§3/§4.
- `[~] S6` **Invite button.** Full `InviteButton.luau` (SocialService-based) in Track B §5 — note Track C
  independently wrote a second, older-API invite implementation inline in its HUD; `PACKET_1_LOBBY_SYSTEMS.md`
  "READ THIS FIRST" recommends keeping Track B's version.
- `[x] S7` **Left-side lobby HUD.** Full `LobbyHud.luau` in Track C §5 — all 4 buttons, order confirmed against the
  reference screenshots: Shop, Invite, Classes, Journal.
- `[~] S8` **Tutorial gate.** `tutorialDone` flag (OR-merge) + `Skip Tutorial` button spec in Track B §6/Track C §4 —
  see the open "does Skip Tutorial still make sense" question in `PACKET_1_LOBBY_SYSTEMS.md` "READ THIS FIRST" §5.
- `[~] S9` **Return-to-lobby flow.** Recap card already shows dolls cleared/coins implicitly via the Shop's live
  balance on return; no dedicated "coins earned this run" line was specced — flag if the team wants one added to
  `RecapUI` specifically.
- `[ ] S10` **Debug commands** (`/coins N`, `/class <id>`, `/quest complete <id>`, `/tutorial done`) — not yet
  specced by name in the packets; straightforward additions to `DebugService.luau` following its existing pattern,
  left for cloud Claude to add alongside the rest of this batch.

---

## §3 — BLOCKERS from playtest (must fix before anyone can finish a run)

Full before/after Luau for all four in **`PACKET_1_PATCHES.md`** §P1 (A1–A3) and §P2 (A4).

- `[~] A1` **Banish room sealed.** `MapBuilder.luau:289` bench room has no `E` gap; line 376 "BanishDoorwayFloorPatch"
  is a solid 2.5×14×8 block in the doorway. → `E = true` + delete the patch. *(Superseded once the map redesign
  lands — stopgap only.)*
- `[~] A2` **Void gaps at ledger-room and storage-alcove doorways** — no floor, no baseplate → players fall out of
  the world. → doorway floor bridge segment. *(Superseded once the map redesign lands — stopgap only.)*
- `[~] A3` **Glyph markers 9 & 10 are in the corridor behind the shift-locked door.** → moved inside the workshop
  rooms in the full corrected `GlyphSpawns` array. *(Superseded once the map redesign lands — stopgap only.)*
- `[~] A4` **Ribbon-less banish of the CORRECT doll consumes the traitor → unwinnable shift.** → strike + surge but
  return the doll to its slot via new `DollService.returnToBench()`, distinct "The box would not close…" toast, never
  consume the marked doll. Full merged `transition()`/`onBanishResolved()` code in `PACKET_1_PATCHES.md` §P2 — **this
  fix is NOT superseded by the map redesign**, it's pure game logic.

## §4 — BUGS from playtest (real, reproducible)

Full before/after Luau for all thirteen in **`PACKET_1_PATCHES.md`** §P1 (B1, B13), §P2 (B2–B4, B7, B8, B11), §P3
(B9), §P4 (B5, B6, B10).

- `[~] B1` Lobby chalkboard / leaderboard / ready-pad sign SurfaceGuis face AWAY from the room — derived (not
  guessed) fix per part in §P1. *(Superseded once the map redesign lands — stopgap only.)*
- `[~] B2` HUD objective stuck on "Find the glyphs" — new `ShiftManager.refreshObjective()` called from both
  `GlyphService` entry points. Fix in §P2.
- `[~] B3` BanishConfirm modal stuck open after RunEnd — `BanishService.reset()` now always broadcasts `cancelled`;
  client also closes on `StateChanged` RunEnd/LobbyIdle as a backstop. Fix in §P2.
- `[~] B4` Strike pips not reset in LobbyIdle — reset now runs before the broadcast; client also defensively zeroes
  on LobbyIdle. Fix in §P2 (folded into the same merged `transition()` as A4).
- `[~] B5` Ledger UI never closes on walk-away or shift transitions — closes on `ShiftResult`/`ShiftIntro` too, plus
  a new distance watch (`Config.Ledger.AutoCloseDistance`). Fix in §P4. *(Not map-geometry — unaffected by the
  redesign.)*
- `[~] B6` Mash minigame button tofu-box emoji — replaced with a procedurally-drawn brush icon (same technique as
  `GlyphRender.luau`). Fix in §P4.
- `[~] B7` Recap shift-number/traitor-name — `shiftReached` now matches the HUD's live banner number; traitor name
  snapshotted at mark-time so it survives the doll being destroyed. Folded into A4's merged code in §P2.
- `[~] B8` Consumed doll stays in the HUD checklist — `DollService.consume` now fires `DollUpdate {removed=true}`;
  Hud grays out that row. Fix in §P2.
- `[~] B9` Presence pacing — found and fixed a real math bug (surge was injecting ~4× its nominal amount), retuned
  `LastDollAccelMultiplier`/`StrikeSurge`/`WrongBanishSurge`, and tagged `RunEnd` with a `reason` so a watchdog
  timeout no longer masquerades as a possession scare. Full worked math + fix in §P3.
- `[~] B10` Naming picker offers the doll's own current name — picker now excludes it while sampling. Fix in §P4.
- `[~] B11` Post-wrong-banish objective copy reads backwards — now branches on the actual outcome
  (`lastBanishOutcome`). Folded into A4's merged code in §P2.
- `[ ] B12` (doc-only) `GlyphFound.slots` replicates as `{false,false,false}`; `LedgerUI` already tolerates it —
  no fix needed, just documented.
- `[~] B13` GlyphSpawn7 overlaps the Banish Box prompt — relocated in the same array rewrite as A3. Fix in §P1.
  *(Superseded once the map redesign lands — stopgap only.)*

## §5 — Verified working (no action) / still untested
Working: clean console all session; full loop; all 4 minigames open; naming; glyph collect + shared toast; ledger match;
ribbon; carry; deposit + solo countdown; gold reveal; shift++; wrong banish strike/surge/consume; ribbon-less fail;
Presence tiers → lighting; Presence max → Dollmaker → recap → lobby; billboards; all haunts + /sound no-ops; debug cmds.
Untested (needs humans / 2 clients): minigame feel by hand · ledger tapping · 2-player quorum + shared ledger · leave
mid-shift · detector rattle · panic emote · mobile layout · tells over a real shift.

## §6 — Open team decisions (`[?]` above, collected — now with the agents' recommendations)
1. **Spawn/hub theme** — recommended: "Hollow Square" (dead town square + broken fountain + fountain-doll statue),
   see `PACKET_1_MAP_DESIGN.md` §4. Team can pick either of the other two proposals in that doc instead.
2. **Place structure for private servers** — recommended: single Place + `TeleportService:ReserveServer`, not two
   places. See `PACKET_1_LOBBY_SYSTEMS.md` Track C §2 for the full comparison table.
3. **Coins per doll + perfect-shift bonus numbers** — recommended defaults: 7/doll, +15 perfect, +3/shift above 1
   (cap +15). See `PACKET_1_LOBBY_SYSTEMS.md` Track A §2.1 for the worked rationale.
4. **Launch class list + prices** — recommended 6-class roster, see `PACKET_1_LOBBY_SYSTEMS.md` Track A §3.
5. **Tutorial: separate map or guided first shift** — recommended: guided first shift, no separate map. See
   `PACKET_1_LOBBY_SYSTEMS.md` Track B §6. Raises a new open question: does "Skip Tutorial" still make sense under
   this design? (See that doc's "READ THIS FIRST" §5.)
6. **Recap "shift reached" semantics** — resolved: matches the HUD's live "SHIFT N" banner number (not "shifts fully
   survived"). See `PACKET_1_PATCHES.md` §P2 B7.
7. **Dedicated Classes kiosk/button** — **resolved 2026-08-15: yes, keep it separate.** `Classes.luau` (buy stays in
   Shop, equip happens in Classes) added in `PACKET_1_LOBBY_SYSTEMS.md` Track A §6b; `LobbyHud.luau` restored to all
   4 buttons in Shop/Invite/Classes/Journal order.
8. **Drive folder access** — **resolved 2026-08-15: shared, reviewed, findings folded into all 3 packets** (see
   `PACKET_1_MAP_DESIGN.md` §5 addendum and `PACKET_1_LOBBY_SYSTEMS.md`'s updated Track A/C sections).
9. **NEW — hub theme: town square (Hollow Square, judge's pick) vs. the reference's actual dead-end
   parking/alley (closer to Proposal 1).** Both are fully specced and buildable; `PACKET_1_MAP_DESIGN.md` §5 lays out
   the tradeoff. Team's call.
10. **NEW — per-class outfits + a leveling/XP system**, spotted in the reference's Classes screen, deliberately not
    built in this batch (bigger scope than what was briefed — see `PACKET_1_MAP_DESIGN.md` §5). Worth a CHECKLIST_2
    if the team wants it.
