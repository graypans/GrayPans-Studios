# GrayPans Studios

Source-controlled Roblox game project, synced into Roblox Studio with [Rojo](https://rojo.space/).

## Project layout

```
src/
  client/   -> StarterPlayer.StarterPlayerScripts.Client   (runs on each player's device)
  server/   -> ServerScriptService.Server                  (runs on the server only)
  shared/   -> ReplicatedStorage.Shared                     (code shared by client + server)
default.project.json  -> Rojo project file, maps src/ into the Roblox instance tree
```

## Getting set up (on the PC running Roblox Studio)

1. Install [Rokit](https://github.com/rojo-rbx/rokit) (Roblox toolchain manager).
2. In this repo folder, run:
   ```
   rokit install
   ```
   This installs the pinned version of Rojo from `rokit.toml`.
3. Install the [Rojo Studio plugin](https://rojo.space/docs/v7/getting-started/installation/#installing-the-studio-plugin) (or `rojo plugin install`).
4. Start the Rojo server from this folder:
   ```
   rojo serve
   ```
5. In Roblox Studio, open your place, click the Rojo plugin button, and hit **Connect**.

Your Studio place will now live-sync with everything in `src/`. Edit code here (or have Claude edit it), save, and it appears in Studio instantly.

## Working with Claude

- **Claude Code on the web / this repo**: writes and pushes code changes directly to this repository.
- **Claude in Roblox Studio (MCP)**: the `Roblox_Studio` MCP server (Studio → Assistant Settings → MCP Servers) lets a local Claude Code CLI or Claude Desktop talk directly to Studio for things like placing parts, editing instances, and building out the map interactively. That only works when Claude is running on the same machine as Studio.

## Status

This is a clean-slate scaffold — no gameplay yet. Next steps: decide on the game concept (obby, tycoon, simulator, roleplay, etc.) and start building systems in `src/`.
