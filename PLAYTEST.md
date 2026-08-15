# PROJECT PORCELAIN — Playtest Guide (read me first, ~3 minutes)

This prevents 90% of false bug reports. The build was written overnight by Claude **without ever running it** — your Studio session is the first run in history. Bugs are expected; that's what today is for.

---

## 1. How to open and play

**Easiest path:**
1. On the GitHub branch, download **`dist/ProjectPorcelain.rbxlx`** (Raw / Download button)
2. Double-click it → Roblox Studio opens
3. Press **Play** (F5)
4. Walk onto the **glowing purple pad**, wait for the countdown — your shift begins

**Multiplayer test (needed for co-op confirm + shared ledger):**
Studio top bar → **Test** tab → **Clients and Servers** → Players: **2** → **Start**. Two windows open; play both.

## 2. EXPECTED WEIRDNESS — not bugs, don't report these

- **The world is INVISIBLE in edit mode.** An empty baseplate before pressing Play is normal — the entire map is built by code when the server starts.
- **The game is (mostly) SILENT.** Every sound cue ships with id 0 on purpose (Claude can't verify audio ids from the cloud; wrong ids would spam errors). Only tiny built-in clicks/ticks play. Filling in real sounds is your job today — see §5.
- **Stats don't save in a local file.** DataStores only work after you **publish** the game (File → Publish to Roblox as a PRIVATE place) **and** enable Game Settings → Security → **Enable Studio Access to API Services**. Until then the game deliberately runs memory-only (billboards still work, they just reset).
- **Chat filtering does nothing in Studio.** Doll names use a curated safe list anyway.
- **Dolls and the map are placeholder blocks.** Meshy/Toolbox art replaces them later; today is about whether the LOOP is fun.
- **The "Taken" haunt is off** (`Config.Features.Taken = false`) — its full version is a post-playtest feature.

## 3. What to actually test (in order)

1. **Solo full run:** pad → shift starts → do all 5 care steps on all 3 dolls (approach a doll, use the prompt) → grab the **Spirit Compass** from the rack near the ledger desk → follow its rattle to 3 glyphs → open the **Ledger**, slot the glyphs in the right order to match a spirit → **take a silver ribbon from the spool and tie it on the doll you suspect** (the chalkboard warned you!) → pick the doll up → carry it to the **Banish Box** → confirm. Did the reveal feel good? Did the shift counter go up?
2. **Get it wrong on purpose:** banish an innocent → you should get a strike + a Presence surge, and the run continues.
3. **Forget the ribbon on purpose:** correct doll + correct ledger, no ribbon → the banish should FAIL (this is the hidden "reagent" mechanic).
4. **Let the Presence max out** (idle around) → lights die, the Dollmaker's face, recap card.
5. **2-player run:** both must confirm the banish; glyphs found by one appear in the other's ledger; billboards show stats above heads in the lobby.
6. **Leave mid-shift** (one client quits while carrying the doll) → the doll should drop, the game should not break.

## 4. Debug tools (DebugMode is ON in this build)

Type in chat:
| Command | Effect |
|---|---|
| `/reveal` | tells you the marked doll + spirit + glyph order |
| `/completedoll` | finishes all care steps on all dolls |
| `/skipstate` | force-advances the game state |
| `/shift 12` | jump to shift 12 difficulty |
| `/presence 80` | set the Presence meter (tier 3 starts at 85) |
| `/haunt DoorCreakSlam` | force a haunt (ids: BenchRattle, DoorCreakSlam, MusicBoxSwell, SilhouetteDoorway, WindowFigure, DollHeadSnap, LightsOutBeat, WhisperPass) |
| `/strike 1` | add a strike |
| `/endrun` | end the run (triggers the scare + recap) |
| `/sound StingReveal` | test any SoundConfig cue by name |

On screen: the **left panel** shows live state/Presence/who's-marked/watched-status; the **🐞 button** (bottom-left) shows the last 10 client errors — screenshot it for bug reports. The **version stamp** is bottom-right.

**Kill switches** (edit `src/shared/Config.luau`, or in Studio: ReplicatedStorage → Shared → Config): if a haunt misbehaves set `Config.Haunts.Events.<Name> = false`; if fake tells confuse testing set `Features.FakeTells = false`; naming off via `Features.Naming = false`.

## 5. Your 20-minute audio session (biggest atmosphere win available)

Open `src/shared/SoundConfig.luau` (in Studio: ReplicatedStorage → Shared → SoundConfig). Every cue is one line with `soundId = 0` and a TODO describing what it should sound like. In Studio: **Toolbox → Audio → search** (e.g. "music box", "door slam", "whisper"), right-click an audio → Copy Asset ID → paste the number over the 0. Test each with `/sound <CueName>` in chat. The five that matter most: `MusicBoxLoop`, `StingReveal`, `StingWrong`, `DollmakerScream`, `AmbienceBase`.

## 6. Bug report template (send to Claude)

```
BUILD: (version stamp, bottom-right corner)
WHAT I DID: (steps)
WHAT HAPPENED: (vs. what you expected)
SCREENSHOTS: (🐞 error panel + Studio Output window if red text)
SOLO OR MULTIPLAYER: 
```

## 7. Known limitations (deliberate, already tracked)

- Mid-run joiners wait in the lobby until the current RUN ends (not just the shift)
- The panic "!!" billboard is only visible to yourself
- No monetization, badges, or Moments hooks yet ([LATER] in PLAN.md)
- Tag pushes are blocked by the repo token, so milestone fallbacks are commits: foundation `ec9bda2`, server `7932d17`, full game `4d5471f`+

## 8. After the playtest

Send every bug + every "this felt boring/confusing/great" note. Claude fixes in rounds. Then: real art (Meshy pipeline for the 6 dolls + The Dollmaker), the real name decision, publish-as-private for DataStore testing, and the §9.6 MASTER.md road to launch.
