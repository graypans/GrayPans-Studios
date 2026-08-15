# Connecting Claude (Desktop + Code CLI) to Roblox Studio — verified Aug 2026

How the local setup works and the exact steps for both apps on Windows. Sources: official Roblox MCP docs, Anthropic's Claude Code docs, DevForum announcements.

## How it works (the 30-second version)

Roblox Studio itself is now an **MCP server** (the toggle you enabled). When Claude Desktop or Claude Code starts, it launches a tiny proxy program (`%LOCALAPPDATA%\Roblox\mcp.bat`) that bridges messages between the Claude app and your open Studio window:

```
Claude Desktop / Claude Code  ⇄  mcp.bat proxy  ⇄  Roblox Studio (your open place)
```

Studio must be **open with a place loaded** for the tools to do anything. The panel's "No clients connected" flips to a green counter once a Claude app is actually attached. Multiple Studio windows are supported — one is the "active" target at a time.

## What a connected Claude can do (the 2026 toolset, ~26 tools)

- **Scripts:** read, search, grep, and multi-edit any script in the place
- **World:** inspect the data model, insert Creator Store assets by ID, search assets
- **AI generation:** generate meshes, materials, and procedural models from text (!)
- **Run code:** execute arbitrary Luau in edit mode OR in a running playtest (server or client side)
- **Playtesting:** start/stop Play, read console output, **take viewport screenshots**, simulate keyboard/mouse input and character movement — a connected Claude can literally playtest the game and look at it
- **Sessions:** list open Studio instances and pick which one to control

## Claude Desktop setup (you're 90% done)

1. ✅ Studio → Assistant Settings → MCP Servers → "Enable Studio as MCP server" ON
2. ✅ Quick Connect → **Claude Desktop** toggle ON — this writes the connection into Claude Desktop's config file (`%APPDATA%\Claude\claude_desktop_config.json`) for you
3. **Fully restart Claude Desktop** — quit it from the system tray (right-click → Quit), not just the window ✕, then reopen
4. Verify: new chat → the tools icon under the message box should list Roblox tools; Studio's MCP panel should show a green connected count
5. Use it: with your place open, just chat — "take a screenshot of the workshop", "insert a low-poly Victorian chair near the ledger desk", "press Play and tell me if any errors appear in the console"

⚠️ **Known gotcha:** if you installed Claude Desktop from the **Microsoft Store**, its config editing is buggy (servers silently fail). If the tools never appear, reinstall Claude Desktop from claude.com's direct installer.

## Claude Code CLI setup (Windows)

1. Install **native Windows** Claude Code (do NOT use WSL for this — the `cmd.exe`/`%LOCALAPPDATA%` command Studio generates is written for native Windows). In PowerShell:
   ```powershell
   irm https://claude.ai/install.ps1 | iex
   ```
   Also install [Git for Windows](https://git-scm.com/download/win) if you don't have it.
2. Clone this repo (once): `git clone https://github.com/graypans/GrayPans-Studios.git`
3. Copy the Quick Connect command from Studio's panel (the copy button on the "Claude Code CLI" row) and run it in any terminal, **adding `--scope user`** so it works from every folder:
   ```
   claude mcp add --scope user --transport stdio Roblox_Studio -- "cmd.exe" /c "%LOCALAPPDATA%\Roblox\mcp.bat"
   ```
4. Open a terminal **in the repo folder**, run `claude`, then type `/mcp` — Roblox_Studio should show as connected, and Studio's green counter should tick up.
5. This local Claude now has BOTH the repo (all the game code + MASTER.md/PLAN.md context via CLAUDE.md) AND live hands in Studio.

## The ground rules (important — also encoded in CLAUDE.md)

1. **The repo is the source of truth for ALL code.** Never let the MCP edit scripts in Studio — Rojo-managed scripts edited in Studio get overwritten by the next sync, and the place drifts from GitHub. MCP script-editing tools are for reading/debugging only.
2. **MCP is for what the repo can't do:** placing/decorating the world, inserting Creator Store assets, terrain, screenshots, running playtests, reading console errors.
3. **Anything the MCP builds in the world lives in the PLACE, not the repo** — save/publish the place after MCP sessions.
4. **Safety:** a connected client can read and modify everything in the open place and execute arbitrary code (Roblox's own warning). Only connect clients you trust, and **publish/commit before big AI sessions** so there's a restore point. Undo (Ctrl+Z) mostly works but is unreliable for big operations.
5. Long tool calls can time out (a known play/stop timeout bug exists) — keep requests small and incremental.

## How this fits our pipeline

- **Cloud Claude (this session) + GitHub:** all game code, systems, docs — the authoritative build
- **Local Claude Code + Studio MCP:** in-Studio verification and decoration — run the beta, screenshot bugs, read console errors, place props, insert assets
- The dream loop: cloud Claude pushes a fix → you pull/re-publish → local Claude presses Play, reads the console, and screenshots the result
