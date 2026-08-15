# Playtest Report — first run ever (2026-08-15, local Studio Claude via MCP)

BUILD: `0.1.0-beta beta-2026-08-15` (commit 4bb0ee8) · SOLO · Studio Play (F5) · DataStores memory-only (expected)

Console was CLEAN for the entire ~50-minute session: zero server errors, zero client errors (🐞 panel empty).
Only console lines: MapBuilder 0 failures, DataStore degraded-to-memory (expected), one `WATCHDOG: state 'ShiftActive' exceeded 900s`.
The loop closes: care → glyphs → ledger → ribbon → carry → Banish Box → "MOMO WAS SISTER WICK" → shift 2. All 4
minigame kinds open, wrong banish strikes, ribbon-less banish fails, Presence max ends the run with recap, billboards update.

Testing caveat: input simulation through the MCP is slow (mouse actions land ~10s late, y is offset by the 58px GUI inset,
tap-mash minigames can't be finished before the 12s lock), so care steps were driven by pressing E for the real prompt then
firing `MinigameDone` from the client exactly as the controller does; ledger slots via `SlotGlyph`; movement past broken
geometry via character teleport. Everything server-side was exercised for real. Humans still need to hand-test the
minigame *feel*, ledger tapping, and all multiplayer items (§3.5/§3.6) — the MCP drives one client only.

---

## A. BLOCKERS — a legit solo run cannot finish (all in `src/server/Services/MapBuilder.luau`)

**A1. Banish room is sealed off.** Bench room `room(SHOP, 44, 36, H, {W,N,S})` (line 289) has NO east gap, so its east
wall at x=262 is solid, and line 376 adds `BanishDoorwayFloorPatch` = a solid 2.5×14×8 wood block *in* the doorway
(comment says "doorway connector"; it is a plug). Horizontal raycast from (255,5,0)→+X hits it at x=260.8.
Fix: give the bench room `E = true` (the room() helper carves the 8-stud gap + lintel) and delete the patch, or make the
patch a real 1-stud-thick FLOOR strip.

**A2. Void gaps at two doorways.** Adjacent rooms don't share floor: bench floor ends at z=±18, ledger-room floor starts
at z=24, storage-alcove floor starts at z=−26. Raycasts at (240,0,19..23) and (240,0,−19..−25) hit NOTHING; there is no
baseplate, so walking to the ledger desk or storage = fall into the void → die → respawn. Same for the wall segments:
between the two rooms' walls there's an 8-stud open-air corridor with no floor/ceiling. PathfindingService also refuses
to route there. Fix: bridge each doorway with a floor (and ceiling/side walls) strip, or make room floors overlap.

**A3. Glyphs spawn behind the locked door.** `GlyphSpawn9` (120,2,4) and `GlyphSpawn10` (150,8,−4) are in the corridor
west of the WorkshopDoor, which ShiftManager keeps `CanCollide=true` for the whole shift (`setDoorLocked(true)` in
ShiftIntro). Both runs tonight drew a corridor glyph → uncollectable. Fix: move those markers inside the workshop rooms
(≥8 markers still fine), or leave the door passable for participants.

**A4. (Design) Ribbon-less banish of the CORRECT doll consumes the traitor → shift unwinnable.** ShiftManager treats every
non-correct banish identically: strike + surge + `DollService.consume(dollId)`. When the doll is the marked one but the
ribbon was forgotten, the Hollow One is destroyed and the player can only strike out / time out with no feedback (recap
then shows `traitor="…someone"`). Suggest: if `dollId == marked` and only the ribbon is missing → strike + surge, but
return the doll to its slot (maybe a distinct toast: "The box would not close…"), never consume it.

## B. Bugs (real, reproducible)

B1. **Lobby signs face the wrong way** (MapBuilder 193–228). Chalkboard at z=−21.4 with default CFrame → Front = −Z
(into the wall/outside; room center is +Z). Leaderboard at x=−21.4 rotated +90° → Front = −X (away). ReadyPadSign at
z=−7 → Front = −Z (away from the pad). All SurfaceGuis (incl. LobbyService's leaderboard gui) use `Front`. Rooms show
blank boards. Also verify the WorkshopDoor sign (line 277, yaw −90 → Front = +X, i.e. facing INTO the workshop, away
from arriving lobby players). Fix: flip the CFrames 180° or use `NormalId.Back`.

B2. **HUD objective never advances past "Find the glyphs — 0 of 3 found."** GlyphService.collect/slot don't trigger a
ShiftManager objective recompute; only StateChanged rebroadcasts update it. It stayed at "0 of 3" with all 3 found and
"MATCHED: Sister Wick" showing. Needs objective refresh on GlyphFound (found count → "Match the spirit in the ledger" →
"Bring … to the Banish Box").

B3. **BanishConfirm modal stuck open after RunEnd.** Run 2 ended (Presence max) while the solo 10s banish countdown was
at 9; BanishService kept counting (8,7,6,5 seen AFTER RunEnd), then reset() at LobbyIdle without broadcasting
`{cancelled=true}` → the modal "Banish Barnaby? Banishing in 5…" is still on screen in the lobby. Fix: BanishService.reset()
should broadcast cancelled; BanishConfirmUI should also close on StateChanged RunEnd/LobbyIdle.

B4. **Strike pips not reset in LobbyIdle.** After the run ended with 2 strikes, the lobby HUD still shows 2 red pips
(LobbyIdle StateChanged is broadcast with `strikes=2` before the reset). Broadcast after reset, or Hud clears on LobbyIdle.

B5. **Ledger UI never closes when you walk away, nor at ShiftResult/ShiftIntro.** It closes only on X, LobbyIdle, RunEnd
(LedgerUI.luau 313–318). It stayed open across shift 1→2 (contents did reset correctly). Close on ShiftResult, and on
distance > ~10 studs from the LedgerDesk (or on any other prompt trigger).

B6. **Minigame button emoji renders as a tofu box.** Mash button text "🪮" (MinigameController.luau 113) is not in the
theme font — shows "?" in a box. Same risk for any other emoji in Theme buttons (😱 panic and 🐞 render fine — different
font/label). Use a text glyph or a Frame-drawn brush.

B7. **Recap card wording after strike-out/timeout**: `shiftReached=1` while the HUD said "SHIFT 2" (it reports shifts
*completed*); `traitorName="…someone"` when the marked doll was consumed. Decide semantics ("You reached Shift 2" vs
"1 shift survived") and keep the marked doll's name after consume for the recap.

B8. **Consumed doll stays in the HUD checklist** (Lord Wobble still listed with 5 ticks after being consumed).

B9. **Presence climbs much faster than the 0.1/s comment suggests late in a shift** — from ~40 to 100 in ~50s during
shift 2 (after 2 strikes, all dolls done). Escalation × LastDollAccel × strike surges compound; verify PresenceMath vs the
intended "~16 quiet minutes". Related: on the slow first run the **900s ShiftActive watchdog fired BEFORE Presence maxed**
(87/100), giving a slow solo player the same death scare with no cause. Consider watchdog > Presence-max time, or a
distinct "the night is over" message.

B10. **Naming picker offers the doll's own current default name** as one of the 6 choices ("Momo" appeared while the doll
was already Momo). Exclude the current name.

B11. **Wrong-banish objective copy**: after a wrong banish the objective reads "Bring the WRONG doll to the Banish Box." —
right after being punished for banishing a wrong doll that's confusing (INTERFACES said "That wasn't it. Find the REAL
one."). Also consider "the marked/hollow doll" wording generally.

B12. `GlyphFound` payload sends `slots` as `{false,false,false}` (nil holes can't replicate). LedgerUI handles it (checks
`typeof(v)=="string"`), just documenting for anyone else consuming it.

B13. HollowStar glyph spawn `GlyphSpawn7` (286,2,6) is 6 studs from the Banish Box deposit prompt; both prompts show at
once and E picks the box. Move the marker a few studs away.

## C. Worked / verified OK
Map builds 0 failures · HUD title/objective/pips/version stamp · debug overlay incl. per-doll watched eyes · 🐞 panel ·
ready pad + countdown → teleport → 3 named dolls with billboards · all 4 minigame kinds open with correct titles ·
`MinigameDone` → DollUpdate → gold ticks · naming picker after first step · prompt text advances per step → "Pick Up /
Tie Ribbon" · glyph tokens + Collect prompt + shared GlyphFound toast · Spirit Compass tool at rack with 3 GlyphTargets ·
Ledger book (6 spirits, drawn glyphs, slots, tray, MATCHED banner, live update) · ribbon take/tie (private ribbon
DollUpdate) · carry clone (real doll hidden) · Banish deposit (hold 0.5s) → solo 10s countdown → gold "X WAS Y" card →
ShiftResult → shift 2 with new dolls · wrong banish → strike/surge/consume/no spirit leak · ribbon-less → fail ·
Presence tiers change lighting · Presence max → DollmakerReveal → Recap → lobby, billboard "Best Shift: 1 · Dolls: 3" ·
all 8 haunts + /sound cues fire without errors even in LobbyIdle · all debug commands (/reveal /completedoll /presence
/haunt /sound) · watchdogs (minigame 12s, ShiftActive 900s) · R3/R5 degradation.

## D. Not tested (needs humans / multi-client)
Minigame feel by hand (mash/hold/sequence/timing) · ledger tapping by finger · 2-player quorum + shared ledger + Taken
stub · leave-mid-shift doll drop · detector rattle feel · panic emote · mobile layout · tells/fake-tells observation over a
real 5-minute shift · countdown timing precisely (looked ≈10s).
