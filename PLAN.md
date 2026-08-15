# PROJECT PORCELAIN — Overnight Beta Build Plan (v2, post-review)

**Placeholder codename** (final name TBD by team). Theme: **haunted dolls** — The Dollmaker's workshop, per MASTER.md §9.
**Goal:** by morning, a playable beta of the core loop exists in this repo, ready for the team to open in Roblox Studio and playtest.
**v2 note:** this plan was adversarially reviewed by 3 independent critics (50 findings) before the build started; the structure below is milestone-ordered (close the loop first, widen second) so the repo always contains a *playable* game even if the night runs short. Every milestone gets a git tag as a known-good fallback.
Owner tags: **[CLAUDE]** overnight · **[TEAM]** needs a human · **[LATER]** deliberately deferred.

---

## 1. What the beta IS (scope contract)

One place file, one small workshop site:

> Lobby (stats above heads) → ready-up pad → Shift starts → 3 dolls on the bench → run each doll's care chain → watch for tells (real + fake) → hunt glyphs with the detector → match the spirit in the ledger → group-confirm the Banish Box → correct = shift survived → next shift, harder. Strikes soften mistakes; The Presence maxing out ends the run with the scare. Stats persist (once published) and display in the lobby.

Solo-first (the team's first test is solo Play), up to 4-player co-op. Mobile-friendly (touch-only playable). All visuals are code-built placeholders; the *game* is real.

## 2. Honest capability split

**Claude CAN do overnight:** 100% of the code; the whole map procedurally from parts; parts-based doll rigs with procedural (tweened) motion; all UI via code; lighting/atmosphere; audio *wiring*; static validation (rojo build + luau analysis — verified feasible in this container via direct binary downloads); unit tests for the pure-logic deduction core (Luau CLI); commit/push + a built `.rbxlx` artifact so the team can double-click open.

**Claude CANNOT do from here:** run the game (no Roblox runtime — the team's Studio session tomorrow is the FIRST run ever; a bug-fix round is expected and planned for); publish/create the experience, questionnaire, dashboard products **[TEAM]**; real art/audio assets **[TEAM + Meshy]**; upload ANY assets — which forces three hard constraints baked into every item below: **zero Animation assets** (all motion is procedural TweenService/Motor6D), **zero image assets** (drawings/glyphs/marks are SurfaceGui compositions or part geometry; moonlight via SpotLight through translucent parts, never texture-less Beams), **zero hardcoded catalog audio IDs** (all cues ship ID=0 + silent no-op; only built-in `rbxasset://` files hardcoded; every audio tell has a visual co-cue).

## 3. Engineering rules (apply to every item; from the critique)

- **R1 — Solo is the golden path.** Every multiplayer gate has a solo/timeout fallback; the full loop completes with 1 player.
- **R2 — Nothing blocks forever.** Every state has a Config watchdog max-duration (loud on-screen warning + force-advance); every minigame/interaction lock auto-releases.
- **R3 — Everything has a kill switch.** Per-haunt `Enabled` flags, master flags per system (FakeTells, Detector, Naming, DataStore, Taken); every haunt execution pcall-wrapped so one bad event can't kill the scheduler.
- **R4 — No raw strings across the wire.** Remote names exist once, as keys in one shared registry module; world instances reached via CollectionService tags/manifest, WaitForChild always with logged timeout. Final static grep pass checks every remote/path reference.
- **R5 — DataStore failure is invisible to gameplay.** All calls pcall'd behind `Config.DataStoreEnabled`; in-memory fallback keeps billboards/recap working; PlayerAdded never waits on a DataStore.
- **R6 — No free physics.** Doll carrying = massless/CanCollide-false weld to the carrier (or visual clone), never unanchored welds; detector = Handle tool, welded massless, CanBeDropped=false, passive Heartbeat intensity (no Activated dependency).
- **R7 — Debug tooling ships day one** (it's for the team, not just Claude): chat commands behind `Config.DebugMode` + username allowlist (`/skipstate /shift N /reveal /completedoll /strike /presence N /haunt <name> /endrun /resetrun`), debug overlay (Presence value/tier, per-doll watched/unwatched, next haunt), error panel (last 10 errors via LogService, screenshot-able), version stamp (Config.Version + git hash + build time) in HUD corner.
- **R8 — StreamingEnabled = false, explicitly** (tiny map; streaming is a [LATER] concern for the large site). Deprecated FilteringEnabled property removed from the project file.

---

## 4. THE BUILD — milestone checklist

### M0 — Toolchain FIRST (validation strategy for the whole night)
- [x] Download rojo 7.4.4 + luau analyzer binaries directly from GitHub release URLs (verified reachable; rokit needs the blocked API — skipped in container, rokit.toml kept for team machines) **[CLAUDE]**
- [x] `rojo build` the scaffold immediately; keep it green after every milestone **[CLAUDE]**
- [x] GitHub Actions workflow: rokit → rojo build → `.rbxlx` artifact on every push (backup path to a place file) **[CLAUDE]**
- [x] `dist/` exception in .gitignore; built `.rbxlx` committed every milestone so "download → double-click" always works **[CLAUDE]**
- [x] Fix default.project.json per R8 **[CLAUDE]**

### M1 — TRACER BULLET: the loop closes (tag `m1-loop`)
*Minimal form of every beat, fully wired: state machine + 1 doll + 1 care step + auto-filled ledger + banish + recap. If the night died here, the team could still play a round.*
- [x] Shared foundation: Config (every tunable), remote registry (R4), defs modules (6 spirits × ordered 3-glyph codes, care steps, tells, haunts, ~20 curated doll names) **[CLAUDE]**
- [x] Pure-logic core as `game`-free modules + Luau CLI unit tests: glyph-order matching, escalation curve, strike/Presence math, tell/haunt scheduling draws **[CLAUDE]**
- [x] Map builder: lobby + workshop (bench room, storage alcove, ledger desk, hallway, Banish Box room), per-room pcall segments, on-screen banner naming any failed segment; base lighting only **[CLAUDE]**
- [x] State machine per §3.2 of v1 plus the review's topology rules: ready-up pad zone w/ countdown starts the shift for players in the zone; workshop locks during ShiftActive ("Shift in progress" billboard); mid-shift joiners/lobby idlers auto-join at next ShiftIntro; empty participant set aborts to LobbyIdle with cleanup; watchdogs per R2 **[CLAUDE]**
- [x] 1 doll spawn (parts rig), 1 care step (brush hair) as ProximityPrompt minigame — prompts configured per review (Exclusivity, RequiresLineOfSight=false, MaxActivationDistance≈8, server occupancy lock, Enabled toggled during minigames), dolls spaced 4+ studs **[CLAUDE]**
- [x] Banish flow v1: prompt-carry (R6) → Box room → confirm UI (quorum = present players, recomputed on leave; all-confirm OR majority + visible 30s timer; solo = 10s override) → staged resolution beat (music hard-cut → sting slot → camera focus → name card slam: "MR. BUTTONS WAS THE HOLLOW ONE" / "…WAS INNOCENT") **[CLAUDE]**
- [x] **Shift-survival rule (fixed per review):** Banish Box unlocks only when every doll's care chain is complete; correct banish → shift++ ; **wrong banish → strike + Presence surge + the innocent doll is consumed + return to ShiftActive** (banish again until correct or Presence maxes); counter increments only on correct banish **[CLAUDE]**
- [x] Leave/reset glue (review): central PlayerRemoving/Died/CharacterAdded — carried doll dropped in place (never destroyed), detector respawns at rack, minigame locks released, mid-shift respawns at workshop spawn **[CLAUDE]**
- [x] Minimal HUD: shift number, objective line (state-driven FTUE: "Care for the dolls" → "Find the glyphs" → "Match the ledger" → "Banish"), strikes, recap card; lobby chalkboard with the four beats **[CLAUDE]**
- [x] rojo build green + logic tests pass + commit + tag **[CLAUDE]**

### M2 — The real game: deduction + full care chain (tag `m2-deduction`)
- [x] All care steps as distinct touch minigames — **5 listed steps** (Brush hair → Polish eyes → Paint face → Dress → Wind music box); doll reads "DONE" after 5; **the silver ribbon is a separate, un-listed 6th act** the banish silently requires (taught once on the lobby chalkboard/ledger page) — preserves the forgettable-reagent dread (review fix) **[CLAUDE]**
- [x] Doll naming: tap-to-pick from curated list (default name auto-assigned at spawn so reveals are never blank); optional free-text behind pcall'd FilterStringAsync + GetNonChatStringForBroadcastAsync (broadcast filter — the correct one), timeout-defaulted, dialog anchored top-half (mobile keyboard); Studio-filters-nothing note in PLAYTEST **[CLAUDE]**
- [x] Tells: marked-doll selection; real-tell scheduler (head snap, eyes follow, position shift between glances, music-box crank visibly turning = the audio tell's visual co-cue, marks appearing as SurfaceGui doodles); **fake tells on innocents**, rate scales per shift **[CLAUDE]**
- [x] Moves-when-unwatched: client streams Camera CFrame ~8 Hz via UnreliableRemoteEvent → server sanity-checks (camera near head) → authoritative FOV-cone + occlusion raycast → doll movable only when no validated camera sees it; HRP-facing-cone fallback for silent clients; per-doll watched status on the debug overlay so the team can verify the rule in 30 seconds **[CLAUDE]**
- [x] Detector + glyphs: R6 tool; passive rattle intensity from server-replicated glyph *positions*; 3 randomized glyph spawns; **found-set is server-authoritative shared state** — every player's ledger shows it + "Glyph found" notification (review fix: co-op split works) **[CLAUDE]**
- [x] Ledger UI: 6 spirits, ordered codes, slot-the-found-glyphs matching **[CLAUDE]**
- [x] Solo scaling: doll count capped at 3 solo; fewer simultaneous tells; slower meter **[CLAUDE]**
- [x] rojo build + tests + commit + tag **[CLAUDE]**

### M3 — The Presence: fear + escalation (tag `m3-presence`)
- [x] Hidden meter: constant fill + rush-surge rubber-band + last-doll acceleration; strikes surge it; server replicates a single PresenceTier IntValue — **each client renders its own** flicker/detune/color-grade locally (review fix: no global-lighting fights, no replication spam) **[CLAUDE]**
- [x] Diegetic tier feedback: lighting warms→sickens, lamp flicker rate, wall doodles change (SurfaceGui), music detune slot **[CLAUDE]**
- [x] Haunt scheduler: tier-gated random draws, cooldowns, never during minigame lock, R3 kill switches; ~8 events (peripheral silhouette, door creak-slam, lights-out beat, doll head snap, whisper pass slot, window figure, music-box swell, bench rattle) **[CLAUDE]**
- [x] **Taken sequence: STUB ONLY tonight (review cut):** trance-in-place (screen darkens, tap-to-wake or friend-shake prompt, guaranteed 20s auto-release, never run-ending; excluded from solo draw pool), behind `Config.Haunts.TakenEnabled = false` by default — full mirror-room version is the first post-playtest feature **[CLAUDE]**
- [x] Run-end scare: lights die, The Dollmaker placeholder reveal + scream slot, recap card (shift reached, dolls cleared, traitor name + reveal shift, closest call) **[CLAUDE]**
- [x] Atmosphere pass (moved here from v1 plan): dust motes (default particle sparkle), SpotLight moonlight, fog **[CLAUDE]**
- [x] rojo build + tests + commit + tag **[CLAUDE]**

### M4 — Persistence, polish, handoff (tag `m4-beta`)
- [x] DataService per R5: UpdateAsync merge-only (bestShift = max, counters = sums — no session locking, deliberately, per review), 3-retry backoff reads, flush on PlayerRemoving + BindToClose; stats: best shift, dolls cleared, perfect shifts, runs **[CLAUDE]**
- [x] Lobby social proof: head billboards on every CharacterAdded (Adornee=Head, DisplayDistanceType=None, lobby-scoped), **two lines: "Best Shift: N / Dolls Cleared: M"** (review fix), async-safe; top-best-shift server leaderboard board **[CLAUDE]**
- [x] SoundConfig: every cue one line, all IDs = 0 + TODO, silent no-op on unset/failed; rbxasset:// built-ins for detector tick + UI clicks; in-Studio **audio test board** (one button per cue) for the team's 20-minute fill session **[CLAUDE]**
- [x] Panic emote button (procedural pose + screen shake + voice bark slot) **[CLAUDE]**
- [x] Mobile pass, timeboxed per review: touch-only playable, no keyboard requirements, minigame GUIs bottom-anchored for thumbs; deeper device polish [LATER] **[CLAUDE]**
- [x] R4 static sweep: grep every remote reference against the registry, every tagged path against the map builder **[CLAUDE]**
- [x] `PLAYTEST.md` with the review-mandated contents: **expected weirdness list** (empty baseplate in edit mode is NORMAL — world builds on Play; silent audio; placeholder dolls), click-by-click open steps (.rbxlx download path AND repo/Rojo path), Studio multi-client steps (Test → Clients and Servers → 2), **publish-to-private-place + Enable Studio API Services step for persistence** (local play is memory-only BY DESIGN), DebugMode how-to + full command list, kill-switch flag table ("if X misbehaves set Y=false"), audio fill guide, bug template (version stamp + error-panel screenshot), milestone fallback tags **[CLAUDE]**
- [x] Final: rojo build, commit `dist/PorcelainBeta.rbxlx`, tag, push **[CLAUDE]**

---

## 5. MORNING CHECKLIST [TEAM]

- [ ] Read PLAYTEST.md first (2 min — it prevents 90% of false bug reports)
- [ ] Download `dist/PorcelainBeta.rbxlx` from the branch → double-click → press Play → full solo run
- [ ] Test → Clients and Servers → 2 players → co-op run (banish quorum, shared ledger, shake-awake stub)
- [ ] File bugs via the PLAYTEST.md template → send to Claude → fix rounds begin
- [ ] Publish to a **private** place + enable Studio API access when ready to test persistence
- [ ] 20-min audio fill session from Creator Store (test board included)
- [ ] Decide the real name · start Meshy pipeline (6 dolls + The Dollmaker)

## 6. NOT in the beta [LATER] (deliberate)

Full mirror-room Taken sequence (stub ships tonight) · large site + two-queue matchmaking · custom prompt styling ("thumb-zone" prompts) · real session locking (needed only when economy data exists) · monetization wiring (needs dashboard products) · Moments/Captures hooks · badges · streamer-safe toggle · StreamingEnabled revisit for the large site · seasonal events · spirits 6→12 · real art/audio/animations (animations REQUIRE Studio upload — all beta motion is procedural by constraint) · publishing + questionnaire + Kids/Select track (MASTER.md §3).

---

*Checklist maintained by Claude during the overnight build — every `[x]` and tag lands as a commit on this branch.*
