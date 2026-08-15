# Project Porcelain — GrayPans Studios

Kid-friendly haunted-doll co-op horror for Roblox (placeholder codename; final name TBD). A 2-person
non-coder team + Claude. Read `MASTER.md` (strategy/research/design), `PLAN.md` (build checklist),
`PLAYTEST.md` (how to test), `docs/INTERFACES.md` (module contract) before making changes.

## The game in one line

Shift-based: care for dolls via prompt minigames → spot the marked doll through real-vs-fake tells →
hunt glyphs, match the spirit in the ledger → tie the silver ribbon → group-confirm the Banish Box.
Escalating shifts, strikes, the Presence meter. Mortuary Assistant's loop, rethemed, made co-op.

## Architecture (do not fight it)

- **Rojo project** (`default.project.json`): `src/shared` → ReplicatedStorage.Shared, `src/server` →
  ServerScriptService.Server, `src/client` → StarterPlayerScripts.Client
- The **entire map is code-built at runtime** by `MapBuilder` — edit mode shows an empty baseplate; that is correct
- Server services in `src/server/Services/` talk only via the `ctx.services` table (no cross-requires)
- All tunables in `src/shared/Config.luau` (incl. kill switches + DebugMode); remotes ONLY via
  `src/shared/Remotes.luau` registry; sounds ONLY via SoundConfig/SoundKit (ids may be 0 = silent no-op)
- Engineering rules R1–R8 are in `PLAN.md` §3 — solo-first, watchdogs, kill switches, no raw strings
  across the wire, DataStore degradation, no free physics, debug tooling, StreamingEnabled=false

## Validation (no Roblox runtime needed)

`./tools/check.sh` = sourcemap → luau-lsp analyze (needs the toolchain; see tools/check.sh header) →
`luau tests/logic.spec.luau` (pure-logic unit tests, keep them passing) → `rojo build` into `dist/`.
Never commit code that fails this gate.

## RULES FOR LOCAL CLAUDE SESSIONS USING THE STUDIO MCP (Roblox_Studio server)

1. **NEVER edit scripts through the MCP** (`multi_edit`, script-writing `execute_luau`). All code
   changes go through this repo → commit → rebuild/republish. Studio-side script edits get overwritten
   by the next sync and drift the place from GitHub. MCP script tools are READ-ONLY helpers here.
2. MCP is for: world decoration, inserting Creator Store assets, terrain, `screen_capture`,
   playtesting (`start_stop_play`, `get_console_output`, input simulation), inspecting instances.
3. After MCP world-building sessions, remind the user to save/publish the place — world changes live
   in the place file, not the repo.
4. Before any large/destructive MCP operation, tell the user to publish first (restore point).
   Keep `execute_luau` chunks small; long calls time out.
5. Audio: fill `SoundConfig.luau` ids from the Creator Store; test cues in-game with the `/sound <Cue>`
   chat command (DebugMode). Debug commands: `/reveal /completedoll /skipstate /shift N /presence N
   /haunt <id> /strike N /endrun /sound <cue>`.

## Git

Branch: `claude/roblox-game-dev-0x3o8s`. Commit early, push often; `dist/ProjectPorcelain.rbxlx` is
rebuilt by `tools/check.sh` and committed so the team can always double-click the latest build.
