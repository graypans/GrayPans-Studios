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

**Failure modes to avoid** *(summary — full autopsies in §2.7)*:
- **Content drought is the #1 killer** — Rainbow Friends (5B+ visits) collapsed when updates stopped
- Pure clones get no algorithmic lift ("MAYA" principle — Most Advanced Yet Acceptable: familiar formula + ONE novel twist wins; see GameAnalytics on Dead Rails)
- Too scary/gory = maturity-label trap that cuts off the under-13 audience
- Too long/too hard caps the kid audience (Pressure: critically loved, ~1K CCU; DOORS: billions of visits)
- No social/clip hook: solo story horror plateaus an order of magnitude lower (Short Creepy Stories ~195M visits vs. co-op hits at 5–13B)

### 2.6 Wider net — adjacent games and what to steal from each

Second research pass across care games, chase games, round games, and the 2026 anomaly wave:

| Game | Numbers (peak, sourced) | The one mechanic worth stealing | Warning it carries |
|---|---|---|---|
| **Dandy's World** (2024) | 866K CCU Apr 2025; 7B visits Jun 2026 | **The cast IS the content**: cute playable Toons + corrupted "Twisted" mirror versions of the same characters; unlockable roster = progression | Character-driven games demand constant new character art |
| **Adopt Me** (2017) | 1.92M CCU 2021 (then all-Roblox record); 40B visits | **Task-count aging**: each care action (feed/heal/comfort) ticks a visible growth meter; rarer creatures need more care | Trading economy → scams → trust collapse (see §2.7) |
| **Grow a Garden** (2025) | 22.3M CCU Aug 2025 — all-time record at the time | **Offline growth**: things progress while you're away, so every login is a discovery moment; rare "mutation" variants as collect-bait | Its scale was trend-luck; the mechanic transfers, the numbers don't |
| **Evade / Nico's Nextbots** | Evade ~9B visits, still updated; Nico's declined hard | **Funny-scary chasers with loud approach audio** — comedy and terror in the same beat; ragdoll-on-down + revive window | Pure chase games decay with their meme; chase must be one phase, not the game |
| **Scary Shawarma Kiosk → Animal Hospital → Home Alone (Anomaly)** | Home Alone: ~25K CCU, 98M visits in 3 months | **The reject/admit decision gate**: multi-signal verification (appearance + camera + behavior) with a hard consequence for wrong admits | "Anomaly horror" is 2026's hottest, most-cloned subgenre — a pure intake-checker launches into saturation |
| **Murder Mystery 2** (2014) | 1.01M CCU in 2026 — still growing at 12 years old | **Hidden roles among trusted things** — "anyone could be it" paranoia is Roblox's most durable retention engine | Its longevity leans on a trading economy, not rounds alone |
| **Flee the Facility** (2017) | 80K CCU peak Mar 2026; ~$46M lifetime est. | **Rescuing captured teammates as a mid-round heroism beat** | — |
| **Steal a Brainrot** (2025) | 25.8M CCU Oct 2025 — highest ever recorded | **Loss-threat as engagement**: "do I stay and guard or go out?" dilemma | Loss frustrates young kids — creatures can be hurt/scared, never permanently stolen or killed |
| **3008** (2018) | 3.2B visits; steady for 6+ years | **The dread clock**: a visible day/night timer that flips a calm space into a threat — predates 99 Nights, proving the loop's durability | Night-survival without progression plateaus |

**Does our exact concept already exist? No.** Targeted searches (Aug 2026) found no game combining (1) rescue/care of cute creatures, (2) night defense, and (3) hidden-anomaly infiltrators. Nearest neighbor is Animal Hospital — but it's a shift-based intake-checker with no persistent shelter, no creature bonding, no base defense. The anomaly-*checking* half is very crowded; the care + defend + anomaly *combination* is open. The window is real but not indefinite — anomaly-genre teams ship fast.

**The proven toolkit** (mechanics appearing in 3+ successful games — Creature Shelter should draw from this list and little else):
1. Cute-surface / scary-underneath duality (Dandy's World, Rainbow Friends, Piggy, Nico's)
2. Anomaly inspection/reject gate (Animal Hospital, Shawarma Kiosk, Home Alone)
3. Care-as-countable-progression — tasks age/grow the pet, rarity scales effort (Adopt Me, PS99, Grow a Garden)
4. Round/phase structure with a visible clock (MM2, Piggy, 3008, 99 Nights)
5. Collect-the-cast unlock economy (Dandy's World, PS99, Steal a Brainrot)
6. Hidden threat among trusted things (MM2, Piggy traitor mode, Animal Hospital, Forsaken)
7. Defend-what-you-own tension (Steal a Brainrot, 3008, 99 Nights)
8. Event/update cadence as a metronome (PS99 weekly, MM2 seasonal, Dandy's World holiday events)

### 2.7 Failure autopsies — why games in this genre die

Case-by-case post-mortems (full details in research digests; confidence noted where sources are community-reported):

- **Rainbow Friends** — 2.4B+ visits, then Chapter 2 took a *year* and the devs went silent. Chapter-based horror gets consumed in one session; with nothing to retain players between chapters, the audience left with the YouTube trend. **Death by content drought + creator-trend dependency.**
- **Piggy** — 1B visits in 83 days (2020), then the story *ended* (Book 2 finale 2021; regular updates ended Nov 2022). Spinoffs never recaptured it. **Death by narrative completion + solo-dev burnout.** Don't architect a game that can "finish."
- **The Mimic** — linear story horror; alive but a "heartbeat" pattern (dead between chapter drops). Also banned in Vietnam (July 2026) for extreme horror — a real maturity-rating casualty. **Replayable systems beat authored scares; keep intensity spooky-cute.**
- **Apeirophobia** — Backrooms trend game; wiki's own diagnosis: "updated slowly… players stop playing after completing available content." Then TWO ownership disputes; original creators walked away Dec 2025. **Death by slow updates on finite content + team drama with nothing in writing.**
- **Pressure** — 94% like ratio, award-winning, and roughly 1/10th of DOORS' audience. Too hard (official Discord recommends *not* playing solo), too dense, too teen-skewed. **Critical acclaim ≠ mass market; every difficulty notch trades away the 8–13 core.**
- **Dead Rails** — 2-person team hit 1.3M CCU (Apr 2025), decayed ~98% within a year. No scandal, no bugs — a shallow one-run loop with a thin endgame got out-updated by Grow a Garden and Steal a Brainrot. **A perfect viral launch buys ~2–4 months; retention systems must exist BEFORE the spike, because you can't build them during it.** (Also proof the ceiling isn't team size.)
- **Pet Simulator 99 / BIG Games** — 400K CCU at launch, ~90% down since, via cumulative trust erosion: NFT pets (2021), DMCA blitz against small devs → #BoycottBigGames (2023), escalating "gambling for kids" gacha criticism (2024–25). **In a pet game, monetization IS the reputation. Never sell randomized outcomes on creatures kids love; never DMCA clones.**
- **Adopt Me** — 1.92M CCU record (2021) → ~5–35K. Egg treadmill stopped producing novelty; endemic trading scams poisoned the core loop; the 2019 kid cohort aged out with no new cohort choosing a 6-year-old game. **Trading in kids' games breeds scams that destroy trust — escrow it or skip it.**
- **Nico's Nextbots vs Evade** — the control experiment: same genre, opposite outcomes. Nico's rode the nextbot meme down; Evade survived via relentless monthly cadence + systems depth (163+ bots, modes, economy). **Cadence and systems beat concept.** (Also: false mass-reporting once took Nico's offline for days — keep an off-platform community hub.)
- **Forsaken** — our closest structural cousin (character-driven co-op survival), 5.5B visits, ~97% down: founder scandal + ownership lawsuit (2025) plus power-creep on new characters. **Half human failure, half design failure: sign a founders' agreement now, and add new content sideways (variety), never upward (power).**

**Top 8 failure patterns, ranked most dangerous first — each with our prevention rule:**

| # | Pattern (cases) | Prevention rule for Creature Shelter |
|---|---|---|
| 1 | Content drought after viral spike (Rainbow Friends, Apeirophobia, Dead Rails, Piggy) | Public, sustainable cadence — small drops every 1–2 weeks, sized for 2 people, planned before launch |
| 2 | No replayable loop under the hype (Dead Rails, Mimic) | Build roguelite variance first: randomized anomalies, creature roster, progression — a reason for run #50 |
| 3 | Team/ownership drama, nothing in writing (Apeirophobia ×2, Forsaken) | Sign a founders' agreement (IP, revenue split, exit terms) this month, while you're still friends |
| 4 | Monetization-trust erosion in pet economies (PS99, Adopt Me) | No paid randomized outcomes on creatures; cosmetics + convenience only; no unescrowed trading |
| 5 | Difficulty/tone mismatch with the 8–13 core (Pressure, Mimic) | Default mode beatable by two 9-year-olds; depth lives in optional modifiers; spooky, never gory |
| 6 | Displacement by faster-updating rivals (Dead Rails) | Assume any hype window lasts ~8 weeks; bank 2–3 pre-built updates before any marketing push |
| 7 | Clone/trend dependency, no owned identity (Banban clones, nextbots, Backrooms) | Original, merchandisable creature cast is the moat; never build on someone else's meme |
| 8 | Power-creep on new content (Forsaken, PS99 value crashes) | New creatures/anomalies add variety, not power; audit every addition against veteran value |

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

### 2.8 The Steam-to-Roblox pipeline — mining old viral YouTube horror

The formula: take a game YouTubers (Markiplier, Jacksepticeye, CoryxKenshin, 8-BitRyan) made viral, add a twist, rebuild it Roblox-native. It's already the platform's most reliable hit machine:

| Steam/indie original | YouTube pedigree | Roblox descendant | Result |
|---|---|---|---|
| Papers Please (2013) → That's Not My Neighbor (2024) | Every major LPer | **Animal Hospital** (+ consequences twist) | 1.85B visits |
| Spooky's Jump Scare Mansion (2014) | Markiplier era | **DOORS** | 7.2B visits |
| SCP-3008 lore | SCP fandom | **3008** | ~3.2B visits |
| Lethal Company (2023) | Dominated Twitch/YT winter 2023-24 | **99 Nights in the Forest** (loop DNA) | 14.2M peak CCU |
| Phasmophobia (2020) | #6 on Twitch Oct 2020 | **Specter 1/2** | 235M+ visits |
| R.E.P.O. (Feb 2025) | 271K Steam CCU | **E.R.P.O.** (clone, shipped in weeks) | 33M visits |

**Why some loops port and others don't** (structural rules from the audit):
1. **Session shape is destiny** — 10–20 min rounds + between-round shop ports; 60-minute expeditions don't
2. **The dread must come from mechanics** (timers, resource triage, turn order, audio cues), because fidelity-based fear (photoreal gore, lighting) evaporates in low-poly
3. **Voice-comedy loops lose their engine** on Roblox (voice is 13+/ID-gated) — loops with mechanical dread keep full power
4. **One-button interactions port to touch**; physics-grab loops get clumsy on mobile
5. **Speed matters**: post-Steam-viral mining windows close in weeks (E.R.P.O.) — but **un-mined 2016–2024 loops are durable arbitrage**, because their audiences are proven and nobody is racing you

**The mining audit — what's taken and what's open:**

*Occupied (don't touch):* FNAF (Forgotten Memories 125M+), Granny (651M), Baldi's Basics (181M), Spooky's (→DOORS), Backrooms (→Apeirophobia), Phasmophobia (→Specter), Lethal Company (4+ clones), R.E.P.O. (→E.R.P.O.), Choo-Choo Charles (→Dead Rails + 62M-visit clone), Poppy Playtime, Slender, Amanda the Adventurer (61M, shallow).

*Un-mined or under-mined — the opportunity list, ranked* (pedigree × Roblox vacancy × fit to our constraints):

1. **Tattletail (2016) — care-based horror.** ⭐ The single best find of this pass. Feed/brush/recharge a needy Furby-like toy whose care tasks *make noise* while its "Mama" hunts you by sound. Markiplier/Jack/DanTDM Christmas 2016 wave. Its 100M-visit Roblox adaptation was legally forced to strip all Tattletail content (IP owner refused a license) and became a non-horror hangout — **demand proven, mechanic vacant for 9 years. This is direct evidence for the Creature Shelter thesis: care-under-threat has a massive proven audience and no Roblox owner.**
2. **Devour (2021) — the care-ritual carry loop.** Catch and carry creatures one at a time to a goal while a jump-scare antagonist accelerates. A 5-year streamer staple (Markiplier/Jack replay every map), zero Roblox equivalent. The catch-carry-deliver verb slots directly into Creature Shelter's rescue phase.
3. **Content Warning (2024) — film-for-views.** 6.2M downloads in 24h; un-mined. "Grow your in-game SpookTube channel by filming cryptids" is both mechanic and marketing flywheel. Caveat: Roblox has no real replay tech — footage must be faked (scripted playback), a medium-hard build.
4. **The Mortuary Assistant (2022) → reskinned "Haunted Toy Workshop."** Possession-deduction shift work (which toy is possessed? decide before dawn) — un-mined because the corpse surface can't ship on Roblox, which is exactly the opening. Grafts onto the checking-game lineage Animal Hospital rode, with a fresher deduction twist.
5. **Iron Lung (2022) — blind crew submarine.** No dominant Roblox version; Markiplier + film pedigree. Upgrades naturally to 1–4 co-op stations (blind pilot / map-only navigator / leak-patching engineer / photographer). One interior set = tiny art scope. "No window, trust your navigator" is streamer catnip.
6. **Buckshot Roulette (2023) × Liar's Bar (2024) — turn-based table dread.** 4M copies + 113K CCU pedigree; only shovelware clones on Roblox (literal gun content caps their discoverability). Kid-safe reskin — jack-in-the-box / cursed party cannon keeps the live/blank turn-dread math. The most mobile-friendly, cheapest-to-build format on this list.
7. **Kletka (2025) — the hungry elevator.** Descend a gigastructure in a man-eating elevator you must feed; loot floors between descents. Weak raw pedigree but the most Roblox-shaped structure imaginable (an elevator IS a lobby + round timer + difficulty ladder). "The elevator ate Dave" is high-TikTok.
8. **Dark Deception (2018) — co-op maze-chase.** Markiplier-driven kid-heavy fandom, begged-for co-op, zero Roblox adaptation despite its own DLC crossing over with Piggy and DOORS.
9. **Emily Wants to Play (2015) — rule-based doll freeze-tag.** Each doll adds one movement rule (freeze when watched / never look / keep moving); rules stack into emergent chaos. Only a tiny tribute exists on Roblox.
10. **Nuclear Nightmare (2024) — infected expedition.** Co-op survival trek where one player secretly becomes the monster — fuses 99 Nights' survival appetite with MM2's traitor paranoia; no current hit combines them.

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

*The concept space is deliberately wider than the 99 Nights × Animal Hospital box — D–G below come from the Steam-mining pass (§2.8).*

| Concept | Buildable | Clippable | Co-play | MAYA | Adult-fun | Total |
|---|---|---|---|---|---|---|
| **A. Creature Shelter** (care + defend + anomaly) | 4 | 5 | 5 | 5 | 4 | **23** |
| B. Short-run "Nights" roguelike (pure survival) | 4 | 4 | 5 | 3 | 4 | 20 |
| C. Anomaly-check shift game (Animal Hospital-like) | 5 | 5 | 4 | 2 | 4 | 20 |
| **D. Haunted Toy Workshop** (Mortuary Assistant reskin: repair toys, deduce the possessed one) | 5 | 5 | 4 | 4 | 4 | **22** |
| **E. Blind Crew Submarine** (Iron Lung × co-op stations) | 4 | 4 | 5 | 5 | 5 | **23** |
| F. Cursed Party Roulette (Buckshot/Liar's Bar table dread, jack-in-the-box reskin) | 5 | 5 | 3 | 4 | 5 | 22 |
| G. Hungry Elevator (Kletka descent, feed-or-be-eaten) | 4 | 5 | 4 | 4 | 4 | 21 |

### ⭐ Concept A (recommended): "Creature Shelter" — working title
You run a rescue shelter for cute creatures deep in a spooky forest. **By day** (~3 min): find lost creatures out in the woods and carry them home, feed/heal/clean them, fuel the generator/lantern, board up weak points. **By night** (~1.5 min): the forest comes for your creatures — keep the lights fed, defend the shelter, survive. **The twist that makes it ours:** some rescued creatures are *wrong* (anomaly-check at the shelter door — eyes, teeth, behavior). Take in a fake and it sabotages you from the inside at night. Survive escalating nights (e.g., a 10-night run ≈ 20–25 min); lose → run ends → lobby shows your best nights above your head; teammates revive downed players; solo mode gets a self-revive item and gentler night scaling.

**Why this wins:** it is *literally* the blend requested — 99 Nights' night-defense tension + Animal Hospital's creepy-cute care and anomaly reveal — while attacking 99 Nights' documented weaknesses (20-hour commitment → 25-minute runs; weak solo → solo-tuned scaling) and dodging pure-clone death with a real MAYA twist (care + betrayal-from-within). **Validation from the wider-net pass (§2.6): no game on Roblox currently combines care + night defense + hidden anomalies** — the anomaly-checking half is crowded, but this combination is open, and every mechanic in the concept appears in the proven toolkit. Every night is a clip; every anomaly reveal is a clip; every "the bunny we adopted ate the generator" is a TikTok. Care tasks + defense roles split naturally across 1–4 friends (co-play signal), and it monetizes cleanly (revive token, 2x coins, cosmetic creature skins/lanterns — all fixed-outcome).

**The Steam-mining pass strengthened A rather than replacing it.** Two of the top three un-mined loops slot directly into Creature Shelter: **Tattletail's** care-tasks-make-noise-while-hunted mechanic (proven audience, vacant on Roblox for 9 years) becomes the shelter's night-care tension, and **Devour's** catch-carry-deliver verb becomes the daytime rescue phase. Concept A is now backed by four evidence lines: 99 Nights (night defense), Animal Hospital (creepy-cute + anomaly), Tattletail (care-under-threat), Devour (carry-rescue).

**On the runners-up:** **E (Blind Crew Submarine)** ties A at 23 and is the most original, most streamer-baity concept on the list. Its original weakness — needing 3–4 coordinated players — is solved by the team's **two-queue design (Sea of Thieves model): a 1–2 player mini-sub where every station is within arm's reach, and a 3–4 player big sub where no one can run it alone.** Iron Lung was a solo game, so the fantasy works alone by design. Remaining considerations vs A: station gameplay must be fun on a phone screen (solvable — station UIs are touch-native), and it rewards organized friend groups where A tolerates chaotic pub lobbies better; A retains younger kids longer via pet attachment. With the queue fix, **A vs E is a genuine coin-flip** — A has the broader kid-retention engine, E has zero competition and the stronger 16+-trial-gate appeal. **D (Toy Workshop)** and **F (Party Roulette)** are the cheapest builds on the board and both would make excellent fast-follow or fallback projects. **Concept B** is a direct 99 Nights subset — weakest differentiation. **C** is a near-clone of a megahit in a subgenre now drowning in clones.

*(Final concept choice = team decision. Whichever of A/E is chosen, the other is the studio's second game.)*

---

## 6. Clippability — Designing for Streamers

The thesis (confirmed by research): on Roblox, creator content isn't a marketing channel — **it's the discovery mechanism.** 2025's record-breakers (Grow a Garden 22.3M CCU, 99 Nights 14.2M) were driven by YouTube/TikTok creators, where a single video can catapult a game to millions of concurrents. Games are increasingly designed backward from the clip.

### 6.1 What creators actually film (and what enables each format)

| Video format | Example | What the game must provide |
|---|---|---|
| First-play scream video | DOORS pulled KreekCraft, Flamingo, iShowSpeed | A first hour with 2–3 reliable scares + one "WHAT is that" reveal. Scares must be *conditioned* (audio cue → payoff), not random loud noises |
| Traitor/betrayal episode | Piggy Traitor Mode → DanTDM "DON'T TRUST ANYONE!" | A staged reveal moment with a distinct sound/visual sting (the Among Us reveal sound became a universal editing meme) |
| Challenge/milestone run | "Surviving all 99 Nights", DOORS speedruns | A **named countable number** in the HUD — the number IS the thumbnail |
| Update reaction | KreekCraft's "(New Update)" streams; LankyBox's unlock-everything playbook | One new *visible character* per content drop |
| Lore/fan-animation content | Dandy's World & Forsaken fandoms run on fan art of the cast | A small cast of named, strongly-designed characters with personalities — not generic mobs |

### 6.2 The voice chat reality (important constraint)

Hearing friends scream is a proven clip engine (Lethal Company's proximity voice is credited as core to its virality) — **but you cannot build a kids' game around voice.** Since Jan 2026, all Roblox chat requires facial age estimation or ID; voice needs 13+ and age-banding. Most of our eventual audience will be voice-ineligible. The fix, per what works elsewhere: **the characters scream so the players don't have to** — panic emotes with loud character voice barks (Forsaken model), proximity text bubbles, and creature vocalizations. 99 Nights' Deer scream became a TikTok meme with zero player voice involved.

### 6.3 Clippability design checklist for Creature Shelter (ranked by content-value-per-effort)

1. **Named creatures + name surfaced at betrayal** *(small effort)* — players name every adopted creature; the reveal shows "MR. SNUFFLES WAS THE ANOMALY" in the feed, death screen, and end-of-run recap. Adopt Me attachment × Among Us reveal economy. The cheapest story-generator we can build
2. **Directed reveal sting** *(small)* — a unique 2–3s sound + portrait flash + music cut when an anomaly turns (Forsaken stages its finale like a broadcast). Make our sting distinctive enough to become an editing meme
3. **Roblox Moments Captures API hooks** *(small)* — auto-prompt clip capture at the exact frame of: anomaly reveal, night survived, clutch revive. The API is live (Sept 2025); almost no small studio wires it to designed moments yet
4. **Night counter big in HUD + title** *(small)* — "Night 12" always visible = free thumbnails and challenge-run formats
5. **One iconic screamer with a meme-able vocalization** *(medium)* — one anomaly form whose scream/face is the game's mascot-horror export (the Deer's scream carries whole TikTok pages)
6. **Panic emotes + character voice barks + proximity text** *(small)* — the under-13 substitute for voice chat; emotes become sellable cosmetics later (Evade model)
7. **Ragdoll-on-down + revive window** *(medium)* — launched ragdoll → downed → friend drags you back: comedy AND clutch clips from one system (Evade, Content Warning)
8. **Death spectate of living friends** *(small)* — dead players follow-cam the survivor being chased; doubles clips per wipe (Lethal Company pattern)
9. **Visible single point of failure** *(small)* — one lantern/generator whose light visibly dies = legible stakes in any 15-second clip; let an anomaly *eat it* on camera
10. **End-of-run story recap card** *(small)* — nights survived, creatures adopted, "traitor: Mr. Snuffles, revealed Night 9," closest call. Screenshot-shareable; it scripts the creator's video narrative for them
11. **Scary-funny oscillation** *(design discipline)* — never more than ~2 minutes of dread without a slapstick valve; this balance is the documented reason 99 Nights fits Roblox's audience
12. **Suspicion tells, not certainty** *(medium)* — anomalies show rare subtle tells (wrong eye glint, eats too fast) so groups argue on camera. The debate is the content; the reveal is the clip (Among Us's engine)
13. **Private servers + streamer-safe toggle** *(small)* — free private servers; a toggle that hides usernames (showing creature names instead) fixes documented stream-sniping pain
14. **One new creature + one new anomaly per update** *(ongoing)* — feeds the update-reaction format and the fan-art community that sustained Dandy's World
15. **Creator freecam in private servers** *(small, last priority)* — owner-only cinematic camera for thumbnails and fan animations

## 7. Launch Strategy (implications from research)

1. **Build for adults/streamers first** — the 16+ trial gate makes this mandatory, and it's who makes clips anyway. Kid-friendliness is a content-rating property (no gore, Mild fear), not a tone property
2. **Soft-launch quietly** → fix funnel (QPTR, D1) → then push. Don't waste the cold-start exploration batch on a rough build
3. **Icon/thumbnail is a top-3 growth lever** (drives QPTR). Budget real effort; A/B test with small sponsored-ad spends
4. Free **private servers** on from day one (drives link-sharing AND the co-play signal)
5. Day-one monetization: revive dev product + 2x coins pass + 1–2 cosmetics at 50–100 R$. No loot boxes
6. Plan the first 4 weekly updates *before* launch (new creature, new anomaly type, new night event, holiday cosmetic) — content drought is the genre's #1 killer
7. Get 2FA + ID verification + fee/Plus subscription sorted early so the under-16 unlock clock starts at launch
8. Launch Friday afternoon US time (community lore, low cost to follow)

---

## 8. Open Decisions / Next Steps

- [x] **Team picked the concept: D, evolved** — the Mortuary Assistant loop, rethemed (not toy *repair*). Full port design in §9
- [ ] **Team picks the theme skin** (§9.4: haunted dolls vs. creepy-cute creatures) and the name (§9.5)
- [ ] **Sign a simple founders' agreement** (IP ownership, revenue split, exit terms) — team drama killed Apeirophobia and Forsaken; failure pattern #3
- [ ] Claude builds the v1 vertical slice (§9.6)
- [ ] Asset pass: free low-poly interior packs from Creator Store; Meshy for the mascot + patient characters
- [ ] Icon/thumbnail concepts (ChatGPT image gen → pick best 2 for A/B)
- [ ] Compliance checklist (§3.5)
- [ ] Write the 4-week post-launch update calendar

---

## 9. CHOSEN DIRECTION — "The Assistant" (working title): Mortuary Assistant → Roblox Port Design

**Decision state:** the team picked Concept D's loop as the game, rethemed away from toy repair. Theme skin (dolls vs. creatures) and final name still open — candidates in §9.4/§9.5. The Sea-of-Thieves-style two-queue idea (1–2 player small site, 3–4 player large site) carries over from the Concept E discussion.

### 9.1 The original loop, in its entirety (The Mortuary Assistant, DarkStone Digital 2022)

Solo dev, one small building (~6 rooms), ~$3–5.6M gross, CoryxKenshin's video ~15M views, Markiplier series, its own film adaptation. A shift works like this:

1. **Arrive → paperwork → 3 bodies in cold storage.** One is host to a demon. Process all three while deducing which.
2. **The task chain (per body, 11 steps, order-gated):** wire jaw → eye caps → mix 5 fluids into the pump (forgetting the special *Reagent* silently voids the ritual later) → incision → clamp tubing → run pump (a *wait state* — this is when you watch the bodies) → suture → cavity fluid → clean the machine → cosmetics → return to storage.
3. **The deduction layer, running in parallel:**
   - *Which body?* — "tells": twitching, eyes reopening, position changes between glances, marks appearing over time. **Crucially, the demon fires FAKE tells on innocent bodies to frame them** — you weigh frequency + intensity per body, never trusting one event. Certainty is engineered to never reach 100%.
   - *Which demon?* — carry a **letting strip** that smokes near hidden sigils (hot/cold detector); find 4 sigils (spawns randomized nightly); match their ordered sequence against a 12-demon reference database on the office computer.
4. **The burn — one irreversible decision per shift:** target body fully processed *with Reagent* + correct 4-sigil Mark placed on it → cremate. Right = banished. Wrong body, wrong sigils, missing reagent, or timer expiry = **possession ending** (the demon takes you).
5. **The clock is a hidden possession meter,** not a wall clock: fills constantly, accelerates after the 3rd body, and *surges if you rush* (anti-speedrun rubber-band). You read it diegetically by scribbling on a notepad — your doodles degrade from straight lines to the demon's own symbol as possession deepens.
6. **The Haunt System:** a large randomized pool of scare events (peripheral figures, audio, moved objects, fake tells) drawn fresh each run and **gated by the meter tier** — quiet early, hallucination set-pieces late. Dev's design thesis: "tension through routine" — scares fire during wait-states and in your peripheral vision, while your hands are busy center-screen.
7. **Replay:** demon, host body, sigil spawns, and haunt draws re-randomize every run; 6 endings + drip-fed lore; knowledge is the progression (veterans process bodies faster, freeing attention for deduction — and the rubber-band pushes back).

### 9.2 Why this loop is perfect for us

- **Dual-attention is the whole game**: busy hands + scanning eyes. It's mechanically scary (survives low-poly, per §2.8 porting rule #2), needs zero gore to work, and every interaction is a tap-and-hold minigame (mobile-native, rule #4)
- **One tiny map** (~6 rooms) — the smallest art scope of any concept on our board
- **Engineered uncertainty + one irreversible group decision** = the Phasmophobia/Among Us argument engine, on camera, every round
- **The fail state is the jump scare** — no combat to build, no gore to rate

### 9.3 The Roblox port blueprint (theme-agnostic)

| Original | Our port | Notes |
|---|---|---|
| Rebecca (assistant) | The players (1–4), new hires of the **mascot boss** | Job title = the game's name |
| The mortuary | One small workshop/clinic building; small site (1–2p) & large site (3–4p) queues | Sea of Thieves model; large site has more rooms + more patients |
| 3 cadavers/shift | **3–5 "patients"/shift** (dolls or creatures), scaling with player count | "Patient" = the unit of the brag stat |
| 11-step embalm chain | **6–8-step care chain** per patient, order-gated, each step a 5–15s touch minigame | v1: 6 steps; add steps in updates |
| The demon | **The Hollow One** (or theme equivalent) — 12 spirit identities in a lookup book | 12 identities = content lever, launch with 6 |
| Possession meter + notepad doodles | **The Presence meter**, read diegetically: lobby music detunes, lights flicker more, your character's hummed tune goes wrong, drawings on the wall change | Never show a bar; the *room* is the meter |
| Tells + fake tells | Identical system: real tells on the marked patient, framed tells on innocents | The core deduction, ported 1:1 |
| Letting strips + 4 sigils + database | **A detector toy/compass** that rattles near hidden **glyph tokens**; match ordered glyphs in the boss's ledger | Invent original cartoon glyphs — no real occult symbols (maturity questionnaire + policy safety) |
| Reagent in the fluid mix | A **special final care step** (e.g., a silver ribbon/bell) that must be included or the banish silently fails | Preserves the "did we do EVERYTHING right" dread |
| The burn (cremate) | **The Banish Box / Moonlight Door** — wheel the chosen patient in, all players confirm, slam it | Group-confirm = the argument clip; no fire, no destruction of a cute thing on screen |
| Possession ending | The Presence takes the shift: lights out, mascot's true face, **shift counter resets** | The jump scare IS the fail state |
| Hallucination set-pieces | Short **"taken" sequences**: one player is briefly pulled into a dark mirror-room minigame, friends see them sleepwalking | Co-op twist: friends can wake them (revive-equivalent) |
| Haunt System pool | Same architecture: event pool × meter tier × random draw; ship ~15 events at launch, add per update | Each new haunt event is clip fuel |
| 6 endings + lore | Shift-milestone story beats (notes from previous assistants; the boss's secret) | Cheap: text + staging |

**Structure & counters (the team's requirement):**
- Runs measured in **Shifts** — endless, escalating (Animal Hospital model: players chase "Shift 50"). **Best Shift + total Patients cleared display above heads in the lobby**
- Per shift: process all patients + banish correctly → shift survived → next shift harder (more patients, faster Presence, subtler tells, more fake tells)
- **One mistake doesn't end the run**: a wrong banish or missed reagent-step triggers a scare + a "strike" (sanity-style); the run ends on meter max. Softer than the original's instant fail — kid-friendlier, and preserves "how far can we get without messing up" as a *perfect-shift* bonus stat
- Session: ~5–8 min per shift, natural stopping points, 15–25 min typical sessions
- **Co-op split (the loop's natural roles):** task-runner(s) on the care chain, detector-carrier hunting glyphs, everyone watching for tells — then one group decision. Solo: fewer patients, slower meter, all roles yours

### 9.4 Theme skins (team decision)

- **Skin 1 — Haunted Dolls: "The Dollmaker's Assistant."** Patients = dolls prepared for adoption (brush hair, paint face, dress, wind the music box, tie the silver ribbon). Boss/mascot = **The Dollmaker**. Scariest per dollar; dolls are TikTok's favorite horror aesthetic; add the *moves-when-unwatched* rule as a tell type
- **Skin 2 — Creepy-cute creatures: "The Night Nanny" / "The Keeper's Assistant."** Patients = baby cryptids at a night nursery (feed, burp, brush, tuck in, nightlight). Boss/mascot = **The Keeper**. Warmer, broader kid appeal, pet-attachment betrayal ("MR. SNUFFLES WAS THE HOLLOW ONE"); slightly closer to Animal Hospital's turf
- Either way: patients are **nameable** (clippability item #1), and the mascot's "true face" is our Deer-equivalent meme export

### 9.5 Name candidates

"The Dollmaker's Assistant" · "The Toymaker's Assistant" · "The Night Nanny" · "The Keeper's Assistant" · "Night Shift" variants. Rule: job title that implies the boss; boss is the mascot; all-ages words only (no "demon/blood/death" in title — §3.2 requires all-ages metadata).

### 9.6 v1 vertical slice (build target)

Lobby (stats above heads) → 1 small site → 3 patients → 6-step care chain → tells + 1 fake tell → detector + 3 glyphs vs 6-identity ledger → Presence meter with 2 haunt tiers (~8 events) → Banish Box group-confirm → shift counter + recap card → mobile + PC input. Two-queue and the large site come after the slice proves fun.

---

### Source confidence notes
Facts in §3 are from official Roblox docs/newsroom (verified against the official creator-docs GitHub mirror, Aug 2026). CCU/visit figures are from Rolimon's/press coverage (confirmed); revenue figures are third-party model estimates (directional only); items marked "community lore/consensus" are unverified best practice. Full source lists live in the research digests (see git history / ask Claude).
