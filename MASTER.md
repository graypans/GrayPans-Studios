# GrayPans Studios — Master Game Doc

**Status:** Concept research complete — game not yet chosen
**Last updated:** 2026-08-15
**Team:** 2 people (no coding experience, can place blocks in Studio) + Claude (writes all code via GitHub → Rojo)
**Budget:** ≤$100 for assets (free-first) · ChatGPT→Meshy pipeline for custom 3D
**Goal:** Max concurrent players and revenue. Monetized from day one.

---

## 1. Vision & Constraints (agreed)

- **Genre:** Kid-friendly spooky co-op survival — a blend of *99 Nights in the Forest* (survival tension) and *Animal Hospital* (creepy-cute care)
- **Players:** 1–4 friend co-op. Multiplayer is a must; solo must be genuinely playable
- **Structure:** Round-based with a clear end. Survival-focused: lose → play again. Days-survived displayed above heads in the lobby. Teammates can revive you mid-run
- **Tone:** Spooky, not scary. Jump scares ✅, chases ✅, darkness/ambience ✅. **Zero blood/gore.** Low-poly cartoony art
- **Timeline:** Playable in days
- **Publishing:** Under the existing Roblox Group (revenue split between both members)
- **Platform:** Mobile-first controls (~80% of Roblox play is mobile)

---

## 2. Market Research

### 2.1 Case study: 99 Nights in the Forest

Made by **Grandma's Favourite Games — a 3-person New Zealand team — in about 3 months** (place created March 2025, blew up June–July 2025). Peak concurrent players reported at **14.2M** (PC Gamer); ~26–28B visits by 2026; third-party revenue estimates around **$230M lifetime** (profitable.app — modeled estimate, not official). Won two Roblox Innovation Awards 2025 (Best Horror + Best Adventure).

**The loop:** plane crash in a forest → survive 99 day/night cycles around a campfire → rescue 4 kidnapped kids from cultists. Days (~3 min) = chop wood, scavenge, cook, build; nights (~1.5 min) = huddle in the campfire's light radius, feed the fire, fight raids. Fire dies → fog closes in, monsters approach. Downed teammates are revived with bandages/medkits — **or a 45 Robux instant revive** (dev product).

**Why it went viral:**
- Co-op panic is inherently clippable — Lethal Company-style "friends screaming" at kid difficulty
- Picked up hard by KreekCraft + TikTok; the "based on a true story" hook (2023 Amazon plane crash rescue) generated its own explainer virality
- Inherited the *Grow a Garden* audience at the perfect moment
- Near-weekly content updates (each one restarts the creator-coverage cycle)

**Monetization:** Diamonds (premium currency) → classes (10–600 diamonds) with talent RNG; rotating daily class shop with **99 Robux rerolls**; 45 Robux revive; 299 Robux starter pack; ~199 Robux Decorator pass. Retention: 7-day login streak, 3 daily quests, promo codes, badges.

**Documented weaknesses (our opening):**
- "99 Nights is boring" is its own TikTok topic — repetitive mid-game wood-chopping grind
- **Solo play is notably weak** (long rebuilds, nobody to revive you)
- A "true ending" run takes 20–40 hours — a huge commitment
- Community fatigue: recent updates add grind/spending, not mechanics

→ **A short, round-based (15–30 min), solo-friendly take directly attacks its three biggest criticisms.**

### 2.2 Case study: Animal Hospital (Anomaly)

Created **May 10, 2026** by the group Animal Anomaly (lead dev Roytt). Peak **736,948 CCU** on July 5, 2026 (Rolimon's); ~1.2–1.3M CCU during a 48-hour limited event (single-source); **1.5B+ visits in ~3 months** with a 95% rating. Content maturity: low — which keeps it visible to young accounts.

**The loop:** "Papers, Please meets vet clinic." Night shifts at a veterinary clinic; animals arrive at a check-in window and you verify each patient across three information layers (window view, Polaroid, CCTV) plus eyes/teeth/paperwork. Mismatch = **anomaly** = reject. Admit an anomaly and it drains sanity, kills patients, or becomes a hostile Skinwalker. Sanity meter instead of HP (coffee restores it). Endless escalating ~5–8 minute shifts; 11 classes bought with earned coins or Robux; co-op division of labor (one on CCTV, one treating, one on the door).

**Why it went viral:**
- **A built-in clip every ~30 seconds** — every check-in verdict is a potential jump-scare reveal. Near-optimal TikTok cadence
- Creepy-cute contrast (adorable pets that are secretly *wrong*) is inherently meme-able
- Spot-the-difference core understandable from a 15-second clip
- Light monetization (50–500 Robux cosmetics/classes) — CCU, not whale-hunting, is the business model

### 2.3 The kid-spooky viral formula (pattern across Piggy, DOORS, Rainbow Friends, Forsaken, Dead Rails, Animal Hospital, 99 Nights)

Every hit in this genre repeats the same skeleton:

1. **One simple verb loop** learnable from a single clip (escape / open the next door / spot the fake / survive the night)
2. **A visible escalating number** — chapters, doors, shifts, nights, miles. "I died on night 43" is shareable; a number to beat is a reason to replay
3. **Threat telegraphed by audio/visual cue → hide/defend mechanic → jump-scare payoff** (the clippable moment)
4. **Co-op with light interdependence** — revives, role-splits, shared fate. Death is funny, not punishing
5. **Short sessions** — Piggy 10-min rounds, Animal Hospital 5–8-min shifts, DOORS floor checkpoints
6. **Low-poly cartoony art with one uncanny twist** (cute thing that is *wrong*) — cheap for small teams AND the source of the meme
7. **Light monetization** — cosmetics, revives, minor perks; engagement pays via Creator Rewards

**Failure modes to avoid:**
- **Content drought is the #1 killer** — Rainbow Friends (5B+ visits) collapsed when updates stopped
- Pure clones get no algorithmic lift ("MAYA" principle — Most Advanced Yet Acceptable: familiar formula + ONE novel twist wins; see GameAnalytics on Dead Rails)
- Too scary/gory = maturity-label trap that cuts off the under-13 audience
- Too long/too hard caps the kid audience (Pressure: critically loved, ~1K CCU; DOORS: billions of visits)
- No social/clip hook: solo story horror plateaus an order of magnitude lower (Short Creepy Stories ~195M visits vs. co-op hits at 5–13B)

### 2.4 How Roblox discovery works now (2026)

The Home page "Recommended For You" is the dominant acquisition source. Confirmed ranking signals (Roblox DevForum + June 2026 "Optimizing Discovery" post):

- **QPTR (Qualified Play-Through Rate):** % of users shown your tile who click AND play ~5+ min. Driven almost entirely by **icon/thumbnail quality**. In-genre 90th percentile ≈ 3.6%; 1–2% is normal
- **Retention D1 / D2–7 / D8–28** (window expanded to 28 days in June 2026)
- **Session length & repeat play days**
- ⭐ **"7-Day Intentional Co-Play Days" (NEW, June 2026):** sessions where players *deliberately* join friends (invites, join-friend, private servers). **The algorithm now explicitly rewards friend-group co-op — our 1–4 co-op design is exactly in-meta**
- Like ratio/favorites: secondary

**Cold start:** new games get small "exploration" impression batches; if QPTR + D1 beat genre benchmarks, impressions scale. **Don't burn the cold start on a broken build** — soft-launch quietly, fix the funnel, then push.

**Sponsored ads:** ~$0.10–0.50/click; only worth it to (a) seed the algorithm once retention is proven, or (b) A/B test icons. Never to sustain CCU. Scale only if D1 ≥ ~20% and QPTR ≥ ~1.5%. $100–300 test budgets are the small-dev norm.

**External virality:** Roblox passed **1 trillion YouTube views in 2025**; ~1 in 5 TikTok gaming videos is Roblox. Design for clippable beats (Roblox's own in-app "Moments" feed launched Sept 2025). Streamers usually arrive *after* organic TikTok traction. Note: rewarding likes/favorites in-game is against ToS; rewarding *playing together* (co-op bonuses, friend revives) is the compliant invite loop.

### 2.5 Retention & monetization playbook

**Benchmarks (community/analytics estimates):** D1 20% good / 30% great / 40% excellent · D7 8% good / 15% great · D30 3% good.

**Retention levers that work:** escalating daily-login calendar (day-2 reward matters most; milestones at 7/14/30); social progression (stats above heads, friend leaderboards — cheap and clip-friendly); limited-time holiday events with exclusive cosmetics (FOMO without pay-to-win backlash); **weekly-or-biweekly update cadence** — this is the real long-term cost, not the initial build.

**Monetization (economics as of 2026):**
- Roblox takes 30% of in-experience sales. DevEx: **$0.0038/Robux** (Sept 2025), **$0.0054** for spend by verified US 18+ players (June 2026). 30K earned Robux minimum to cash out (~$114)
- Engagement payouts replaced July 2025 by **Creator Rewards:** ~**5 Robux per "active spender" per day** (10+ min in your game that day AND ≥$9.99 platform spend in past 2 months) + audience-expansion rewards. Uncapped
- **Day-one loadout (proven, goodwill-safe):** 2–4 cheap passes (50–100 R$ converts far better than 500 R$ for a new game) + a **revive dev product** + a 2x-currency pass + cosmetics. NO pay-to-win, no paywalled core loop. Reprice from data after ~2 weeks
- Typical payer conversion ~1–3% of players

**Realistic expectations (be sober):** ~85% of Roblox devs earn <$100/month; median DevEx payout ≈ $1,575/year. ~1,000 CCU ≈ $80–160/day and is the community's "success" threshold. BUT the breakouts in *exactly our genre* are all tiny teams: Dead Rails (2 people → 1.3M CCU), 99 Nights (3 people → 14.2M CCU), Grow a Garden (teen dev → 21.3M CCU record). Hits typically catch within 2–12 weeks of launch or need a relaunch/retheme — plan for iteration, not a single roll of the dice.

---

## 3. Platform Rules — VERIFIED (this section is official policy, not lore)

### 3.1 The "16+ plays" claim: **TRUE** ✅

The claim we set out to verify — *"games cannot be approved for kids unless it has enough plays from 16+"* — is **real, current policy**, under the **Roblox Kids and Select** framework (announced April 13, 2026; global June 16, 2026):

- Every new game targeting under-16s starts in a **trial phase visible only to age-checked 16+ users**
- To unlock the **Kids (5–8)** and **Select (9–15)** audiences, the game must reach **500 unique plays by "highly engaged" age-checked 16+ users within 60 days** (criteria include account tenure, playtime in your game, and any platform spend in the last 60 days) + pass an automated safety review
- Publishing to under-16s also requires: **ID-verified creator account, 2FA, and a one-time refundable publishing fee OR an active 2+ month Roblox Plus/Premium subscription** (fee refunded 90 days after eligibility)
- Optional bypass: 100,000 Robux expedited review (not for us)
- Parents can individually whitelist any non-Restricted game via parental controls

**Strategic consequence (this shapes everything):** for our first ~60 days, our *entire* audience is 16+. The game **must be genuinely fun for adults and streamers first** — that's not a nice-to-have, it's the literal gate to ever reaching kids. Design for "fun to watch, funny to fail, tense with friends" and the kid audience unlocks afterward. Source: [Kids & Select docs](https://create.roblox.com/docs/production/publishing/kids-and-select), [announcement](https://about.roblox.com/newsroom/2026/04/introducing-roblox-kids-and-select-accounts).

### 3.2 Content maturity: we target **Mild**

Labels come from the mandatory Maturity & Compliance Questionnaire. Access: Kids (5–8) can play **Minimal or Mild**; Select (9–15) up to Moderate.

- **Minimal allows NO fear content** — so a spooky game cannot be Minimal
- **Mild fear** (official wording) covers exactly our design: *"loud/heavy breathing, pounding heart, shrieking, creepy-looking NPCs, jump scares, ominous music, gameplay that builds suspense"*
- **Moderate** fear requires realistic gore — which we will never have
- → Jump scares + chases + darkness + zero blood = **Mild label, eligible for ages 5+** (after passing the 3.1 evaluation)

Compliance rules: answer for the most extreme content in the game; **retake the questionnaire after any update that changes answers**; misrepresentation = moderation strikes; title/description/thumbnail must be all-ages appropriate; a chase mechanic should also be disclosed as Mild violence (unrealistic, bodies vanish at 0 HP).

### 3.3 Monetization rules for a kids-visible game

- Plain game passes / dev products with **fixed outcomes: no special disclosure needed** ✅
- **Paid random items** (eggs, crates, spins, anything Robux-adjacent with random outcomes): must display **all outcomes with numerical odds summing to 100% before purchase**, including luck-modifier math. Must respect `PolicyService.GetPolicyInfoForPlayerAsync` (`ArePaidRandomItemsRestricted`) per region/age
- **v1 decision: fixed-outcome purchases only. No loot boxes.** Avoids the entire compliance surface
- Playable gambling mechanics are banned at every label

### 3.4 Assets, music, IP

- **Music:** never upload commercial tracks — use Roblox's licensed catalog (APM) or original audio. Flagged audio gets muted + strikes
- **Toolbox/free models:** free to use, but audit every one for (a) hidden scripts/backdoors and (b) third-party IP (DMCA takedowns hit *our* game)
- **Meshy/AI-generated assets:** we bear full responsibility for uploads regardless of how they were made — don't generate anything resembling existing IP (no "cute Huggy Wuggy," no brand characters)
- Asset uploads are moderated separately from the game label — keep even uploaded images gore-free

### 3.5 Compliance checklist (pre-launch)

- [ ] Group publishing confirmed; both members' roles/payouts configured
- [ ] Creator account ID-verified + 2FA enabled (required for under-16 publishing)
- [ ] Publishing fee paid OR Roblox Plus/Premium active 2+ months
- [ ] Maturity questionnaire: Fear=Mild, Violence=Mild/unrealistic, no blood → confirm Mild label
- [ ] All-ages title/description/thumbnail
- [ ] No paid random items in v1
- [ ] All audio from licensed catalog/original
- [ ] Every Toolbox asset audited for scripts + IP

---

## 4. What We Can Actually Build (honest capability assessment)

### Safely in reach (Claude codes all of this; proven, low-risk)
- Round-based loop state machine: lobby → run → escalating nights → win/lose → lobby
- Day/night cycle, difficulty scaling by night count and player count (1–4)
- Downed-state + teammate revive; solo-friendly self-revive item
- Monster AI: wander → detect (sight/sound radius) → chase → attack → retreat at dawn (PathfindingService)
- Interactables via ProximityPrompts (mobile-friendly by default): gather, feed, heal, fuel a fire/generator, doors, hiding spots
- DataStore persistence: best-nights-survived, currency, unlocks — shown above heads in lobby (BillboardGui)
- Full monetization wiring: game passes, dev products (revive, currency, 2x), Premium checks, PolicyService compliance
- Daily streaks, playtime rewards, badges, promo-code system
- GUI: menus, HUD, shop, results screen; mobile + PC input
- Atmosphere on the cheap: fog, darkness, flashlight/lantern, ambient audio, jump-scare stingers (lighting + sound do the scaring, not expensive assets)
- Server-authoritative logic + remote validation (basic anti-exploit)

### Risky / slow — avoid in v1
- Custom-rigged monster animations (the single hardest asset class) → mitigate with free/purchased rigged packs, simple meshes + procedural motion, and letting **sound + light** carry the scare
- Large handcrafted maps → one small dense map; free modular kits; script-scattered props
- Cutscenes, story systems, voice acting → skip
- Building/crafting systems Fortnite-style → skip v1
- PvP → co-op only avoids most netcode pain

### Design-to-this sweet spot
- One small, dense, atmospheric map
- 3–5 interaction types max in v1 · 1–2 monster types in v1
- Session 15–30 min; near-zero restart friction
- Every mechanic explainable in one sentence to an 8-year-old
- **The real cost isn't the build — it's the weekly update cadence after launch.** Scope v1 so weekly content drops stay feasible for a 2-person team

---

## 5. Candidate Concepts (scored) & Recommendation

Scoring: 1–5 against our constraints. **Buildable** = 2-person + Claude, days-to-playable. **Clippable** = jump-scare/meme moment frequency. **Co-play** = feeds the 2026 co-play algorithm signal. **MAYA** = familiar + one novel twist (not a clone). **Adult-fun** = survives the 60-day 16+ trial gate.

| Concept | Buildable | Clippable | Co-play | MAYA | Adult-fun | Total |
|---|---|---|---|---|---|---|
| **A. Creature Night-Shelter** (care + defend) | 4 | 5 | 5 | 5 | 4 | **23** |
| B. Short-run "Nights" roguelike (pure survival) | 4 | 4 | 5 | 3 | 4 | 20 |
| C. Anomaly-check shift game (Animal Hospital-like) | 5 | 5 | 4 | 2 | 4 | 20 |

### ⭐ Concept A (recommended): "Creature Night-Shelter" — working title
You run a rescue shelter for cute creatures deep in a spooky forest. **By day** (~3 min): find lost creatures out in the woods and carry them home, feed/heal/clean them, fuel the generator/lantern, board up weak points. **By night** (~1.5 min): the forest comes for your creatures — keep the lights fed, defend the shelter, survive. **The twist that makes it ours:** some rescued creatures are *wrong* (anomaly-check at the shelter door — eyes, teeth, behavior). Take in a fake and it sabotages you from the inside at night. Survive escalating nights (e.g., a 10-night run ≈ 20–25 min); lose → run ends → lobby shows your best nights above your head; teammates revive downed players; solo mode gets a self-revive item and gentler night scaling.

**Why this wins:** it is *literally* the blend requested — 99 Nights' night-defense tension + Animal Hospital's creepy-cute care and anomaly reveal — while attacking 99 Nights' documented weaknesses (20-hour commitment → 25-minute runs; weak solo → solo-tuned scaling) and dodging pure-clone death with a real MAYA twist (care + betrayal-from-within). Every night is a clip; every anomaly reveal is a clip; every "the bunny we adopted ate the generator" is a TikTok. Care tasks + defense roles split naturally across 1–4 friends (co-play signal), and it monetizes cleanly (revive token, 2x coins, cosmetic creature skins/lanterns — all fixed-outcome).

**Concept B** is the safest build but is a direct 99 Nights subset — weakest differentiation. **Concept C** is the easiest build with the best clip cadence, but it's a near-clone of a 3-month-old megahit; clones get no algorithmic lift.

*(Final concept choice = team decision — this doc recommends A.)*

---

## 6. Launch Strategy (implications from research)

1. **Build for adults/streamers first** — the 16+ trial gate makes this mandatory, and it's who makes clips anyway. Kid-friendliness is a content-rating property (no gore, Mild fear), not a tone property
2. **Soft-launch quietly** → fix funnel (QPTR, D1) → then push. Don't waste the cold-start exploration batch on a rough build
3. **Icon/thumbnail is a top-3 growth lever** (drives QPTR). Budget real effort; A/B test with small sponsored-ad spends
4. Free **private servers** on from day one (drives link-sharing AND the co-play signal)
5. Day-one monetization: revive dev product + 2x coins pass + 1–2 cosmetics at 50–100 R$. No loot boxes
6. Plan the first 4 weekly updates *before* launch (new creature, new anomaly type, new night event, holiday cosmetic) — content drought is the genre's #1 killer
7. Get 2FA + ID verification + fee/Plus subscription sorted early so the under-16 unlock clock starts at launch
8. Launch Friday afternoon US time (community lore, low cost to follow)

---

## 7. Open Decisions / Next Steps

- [ ] **Team picks the concept** (recommendation: A — Creature Night-Shelter)
- [ ] Name the game (needs an all-ages, clippable, searchable name)
- [ ] Claude builds the v1 vertical slice: lobby + day/night loop + 1 creature + 1 monster + generator/lantern + revive + basic HUD
- [ ] Asset pass: free low-poly forest/creature packs from Creator Store; Meshy for the 1–2 hero creatures/monsters
- [ ] Icon/thumbnail concepts (ChatGPT image gen → pick best 2 for A/B)
- [ ] Compliance checklist (§3.5)
- [ ] Write the 4-week post-launch update calendar

---

### Source confidence notes
Facts in §3 are from official Roblox docs/newsroom (verified against the official creator-docs GitHub mirror, Aug 2026). CCU/visit figures are from Rolimon's/press coverage (confirmed); revenue figures are third-party model estimates (directional only); items marked "community lore/consensus" are unverified best practice. Full source lists live in the research digests (see git history / ask Claude).
