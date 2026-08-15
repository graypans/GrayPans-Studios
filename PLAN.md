# PROJECT PORCELAIN — Overnight Beta Build Plan

**Placeholder codename** (final name TBD by team). Theme: **haunted dolls** — The Dollmaker's workshop, per MASTER.md §9.
**Goal:** by morning, a playable beta of the core loop exists in this repo, ready for the team to open in Roblox Studio and playtest.
**This file is the build checklist.** Claude ticks items as they're completed overnight (`[x]`). Owner tags: **[CLAUDE]** = done autonomously overnight · **[TEAM]** = needs a human (Studio, dashboard, accounts) · **[LATER]** = deliberately not in the beta.

---

## 1. What the beta IS (scope contract)

One place file, one small workshop site, the full §9.6 vertical slice with the dolls skin:

> Lobby room (stats above heads) → start a Shift → 3 dolls arrive → run each doll's 6-step care chain → watch for tells (real + fake) → hunt 3 glyphs with the detector → match the spirit in the Dollmaker's ledger → group-confirm the Banish Box → shift survived → next shift, harder. Strikes soften mistakes; The Presence maxing out ends the run with the scare. Best Shift + Patients cleared persist and display in the lobby.

Solo playable; up to 4 players co-op in one server. Mobile + PC input. Everything visual is code-built low-poly placeholder (parts-based dolls and rooms) — the team replaces looks later with Meshy/Toolbox assets; the *game* is fully real.

## 2. Honest capability split

**Claude CAN do overnight, from this cloud environment:**
- 100% of the game code (Luau, server + client), the entire systems list below
- Build the whole map procedurally from parts (workshop interior, lobby, furniture, Banish Box) — no Studio needed
- Parts-based placeholder dolls (distinct silhouettes/colors per doll) with code-driven motion for tells
- All UI (HUD, minigames, ledger, recap) built via code (no image assets required)
- Lighting/atmosphere (fog, flicker, color grading by Presence tier) and audio *wiring* (every sound is a config entry pointing at a Roblox catalog asset ID — defaults set, team-swappable)
- Static validation: `rojo build` the place file + Luau static analysis (will install the toolchain in the cloud container; if the network blocks it, validation falls back to review-only and the team's first Studio open is the real test)
- Commit + push everything to this branch, with a written playtest guide

**Claude CANNOT do from here (physics of the situation, not policy):**
- Actually RUN the game — this environment has no Roblox runtime. First real playtest is the team's, in Studio. Expect bugs on first open; report them and Claude fixes in rounds
- Publish the place, create the game on the group, fill the maturity questionnaire, create game passes/dev products/badges, upload images/meshes/audio — all dashboard/Studio actions **[TEAM]**
- Make real art: mesh dolls, the Dollmaker model, icons/thumbnails **[TEAM + Meshy/ChatGPT pipeline]**

---

## 3. THE BUILD CHECKLIST

### 3.0 Foundation
- [x] Rojo project scaffold, folder structure, Git repo **[CLAUDE]** *(done pre-plan)*
- [ ] Shared config module (all tunables in one file: timings, meter rates, strike count, escalation curve) **[CLAUDE]**
- [ ] Remote event/function registry with server-side validation on every remote **[CLAUDE]**
- [ ] Definition modules: 6 spirits (3-glyph ordered codes), 6 care steps, tell types (real + fake), haunt event pool, glyph set (original cartoon glyphs, no real occult symbols) **[CLAUDE]**
- [ ] Luau toolchain in cloud container (rojo build + static analysis) — best effort **[CLAUDE]**

### 3.1 Map (code-built, placeholder-visual)
- [ ] Lobby room: spawn area, stats billboards, shift-start door/pad **[CLAUDE]**
- [ ] Workshop site: main workbench room, doll storage alcove, ledger desk, back hallway, Banish Box room (~5 spaces, small & dense) **[CLAUDE]**
- [ ] Atmosphere pass: dim warm lighting, dust motes, flickering lamps, window moonlight, fog **[CLAUDE]**
- [ ] Parts-based doll models ×6 visual variants (distinct silhouette + palette so tells are readable) **[CLAUDE]**
- [ ] Replace parts-dolls with Meshy/Toolbox meshes **[TEAM, post-beta]**

### 3.2 Shift loop (the state machine)
- [ ] States: LobbyIdle → ShiftIntro → ShiftActive → BanishDecision → ShiftResult → (next shift | RunEnd) **[CLAUDE]**
- [ ] 3 dolls per shift spawn on the bench; count/difficulty escalate per shift (more fake tells, faster Presence, +1 doll at defined milestones) **[CLAUDE]**
- [ ] Strike system: wrong banish / missed final ribbon step = strike + scare, not instant fail; run ends at strike cap or Presence max **[CLAUDE]**
- [ ] Perfect-shift tracking (no strikes, all steps correct) as bonus stat **[CLAUDE]**
- [ ] Solo scaling: fewer simultaneous tells, slower meter when 1 player **[CLAUDE]**

### 3.3 Care chain (the hands-busy half)
- [ ] 6 order-gated steps per doll, each a 5–15s ProximityPrompt minigame: Brush hair → Polish eyes → Paint face → Dress → Wind music box → **Tie the silver ribbon** (the "reagent" — forgettable on purpose) **[CLAUDE]**
- [ ] Touch-first minigame interactions (tap/hold/drag-free; no keyboard requirements) **[CLAUDE]**
- [ ] Per-doll progress checklist on the HUD; naming prompt when a doll is first picked up **[CLAUDE]**

### 3.4 Deduction layer (the eyes-busy half)
- [ ] Marked-doll selection per shift; real tells scheduler (head turn when unwatched, eyes follow, position shift between glances, music box self-play, marks appearing) **[CLAUDE]**
- [ ] **Fake tells on innocent dolls** (framing), rate scales with shift number **[CLAUDE]**
- [ ] Moves-when-unwatched logic (line-of-sight check across all players — the Weeping Angels rule) **[CLAUDE]**
- [ ] Detector toy: held tool, rattle/glow intensity by distance to hidden glyphs **[CLAUDE]**
- [ ] 3 glyph tokens, randomized spawn points per shift **[CLAUDE]**
- [ ] Dollmaker's ledger UI: 6 spirit entries, ordered 3-glyph codes, player slots found glyphs to match **[CLAUDE]**

### 3.5 The Presence (meter + haunts)
- [ ] Hidden meter: constant fill + surge-on-rush rubber-band + acceleration after last doll finished **[CLAUDE]**
- [ ] Diegetic readout only (no bar): lighting warms→sickens, lamp flicker rate, music detune, wall drawings change at tier thresholds **[CLAUDE]**
- [ ] Haunt system: ~8 launch events (peripheral silhouette, door creak-slam, lights-out beat, doll head snap, whisper pass, window figure, music box swell, bench rattle), tier-gated random draws, cooldowns, never during minigame lock **[CLAUDE]**
- [ ] "Taken" sequence (1 co-op event): a player is pulled to the dark mirror-room for a 20s escape minigame; friends see them sleepwalking and can shake them awake **[CLAUDE]**
- [ ] The scare (run end): lights die, The Dollmaker's true face (placeholder model + sound), recap card **[CLAUDE]**

### 3.6 Banish
- [ ] Banish Box in its own room; carry/wheel the chosen doll in **[CLAUDE]**
- [ ] All-players confirm UI (with a 10s solo-override so solo isn't blocked) **[CLAUDE]**
- [ ] Resolution: correct doll + correct glyph order + ribbon tied = banished (shift survived); anything wrong = strike + consequence scare; reveal card shows the doll's NAME ("MR. BUTTONS WAS THE HOLLOW ONE") **[CLAUDE]**

### 3.7 Persistence & lobby social proof
- [ ] DataStore: best shift, total dolls cleared, perfect shifts, runs played (with retry/session-locking hygiene) **[CLAUDE]**
- [ ] Lobby billboards above heads: "Best Shift: N" **[CLAUDE]**
- [ ] Lobby leaderboard board (top best-shift this server) **[CLAUDE]**

### 3.8 GUI/UX
- [ ] HUD: shift number (big — it's the thumbnail), doll checklists, strikes, held-item slot **[CLAUDE]**
- [ ] Shift intro/result banners, end-of-run recap card (shift reached, dolls cleared, traitor name + reveal shift, closest call) **[CLAUDE]**
- [ ] Naming prompt with filter via Roblox TextService (required for kid safety) **[CLAUDE]**
- [ ] Mobile layout pass: thumb-reachable prompts, no tiny targets; PC bindings **[CLAUDE]**
- [ ] Panic emote button (character voice bark placeholder) **[CLAUDE]**

### 3.9 Audio (wired, swappable)
- [ ] SoundConfig module: every cue one line — ambience bed, tier layers, detector rattle, music box, stingers, reveal sting, Dollmaker scream **[CLAUDE]**
- [ ] Default IDs from Roblox's free audio catalog; team swaps favorites later **[TEAM, post-beta]**

### 3.10 Hygiene
- [ ] Server-authoritative everything; remotes validated; no client trust on care steps/banish/stats **[CLAUDE]**
- [ ] Streaming-safe, ~60s soft cleanup between shifts (no part leaks) **[CLAUDE]**
- [ ] Playtest guide: `PLAYTEST.md` — how to open, sync, test solo + multiplayer, known-placeholder list, bug report template **[CLAUDE]**

---

## 4. MORNING CHECKLIST **[TEAM]**

- [ ] Pull the branch (or download the built `.rbxlx` if the toolchain worked — see PLAYTEST.md)
- [ ] Open in Studio, press Play — try a full run solo; then Test → 2+ players for co-op & the Taken event
- [ ] Write down everything broken/confusing/boring (template in PLAYTEST.md) → send to Claude for fix rounds
- [ ] Decide the real name (then Claude renames the project cleanly)
- [ ] Start the Meshy pipeline: 6 dolls + The Dollmaker (concept images → 3D)

## 5. NOT in the beta **[LATER]** (deliberate)

Large site + two-queue matchmaking (after the loop proves fun) · monetization wiring (needs dashboard products first — code slots are stubbed ready) · Moments/Captures API hooks · badges · streamer-safe toggle · seasonal events · additional spirits (6→12), haunts, care steps · private-server perks · real art/audio pass · publishing + questionnaire + Kids/Select track (MASTER.md §3).

---

*Checklist maintained by Claude during the overnight build — every `[x]` lands as a commit on this branch.*
