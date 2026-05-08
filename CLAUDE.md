# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Identity

This is **Rocky on Desk** — a custom theme + hook configuration built on the open-source [`clawd-on-desk`](https://github.com/rullerzhou-afk/clawd-on-desk) Electron desktop pet framework. The pet lives on your desktop and reacts to Claude Code events (tool calls, thinking, errors, etc.) in real time.

The upstream engine is `clawd-on-desk`. This repo is an independent fork with two custom themes (Rocky, Rocky Domed) and enriched hook mappings.

**Development is Windows-native** (migrated from WSL). All commands should be run from Windows PowerShell / cmd, not WSL.

## Commands

```bash
npm install              # Install dependencies (Electron + gif-encoder-2 + pngjs)
npm start                # Launch the desktop pet (uses launch.js → spawns Electron)
npm test                 # Run test suite (node --test test/*.test.js)
npm run build            # Build Windows installer (electron-builder --win)
```

**GIF preview generation** (requires Electron):
```bash
npx electron scripts/generate-gifs.js <theme-name>   # e.g. "rocky" or "rocky-domed"
```

**Hook management:**
```bash
node hooks/install.js    # Register clawd hooks into ~/.claude/settings.json
node hooks/uninstall.js  # Remove all clawd hooks from ~/.claude/settings.json
```

## Architecture

### Event Pipeline

```
Claude Code event (PreToolUse, PostToolUse, etc.)
  → ~/.claude/settings.json hooks[] fires command hook
  → hooks/clawd-hook.js receives event + stdin JSON payload
  → maps event → state (EVENT_TO_STATE + resolveState())
  → HTTP POST { state, session_id, tool_name, ... } to 127.0.0.1:23333/state
  → src/server.js HTTP server receives it
  → src/state.js updateSession() updates per-session state
  → resolveDisplayState() picks highest-priority active state
  → getSvgOverride() resolves working tiers / display hints → final SVG file
  → Electron renderer plays the animation
```

### Key Modules

| File | Role |
|------|------|
| `src/main.js` | Electron entry — window management, drag, sizing, tray, IPC |
| `src/state.js` | State machine — session tracking, priority resolution, sleep sequence, working tiers, DND |
| `src/server.js` | HTTP server — `/state` (event ingestion), `/permission` (permission UI), `/health` |
| `src/theme-loader.js` | Loads + validates `theme.json`, discovers themes from `themes/` directory |
| `hooks/clawd-hook.js` | **The hook script** — event→state mapping, tool-type differentiation, probability sprinkles |
| `hooks/install.js` | Registers/unregisters clawd hooks into `~/.claude/settings.json` |
| `hooks/server-config.js` | Port discovery, runtime config, HTTP client helpers shared by hook and server |
| `launch.js` | Strips `ELECTRON_RUN_AS_NODE` before spawning Electron (CC sets this) |

### State Machine (src/state.js)

**Priority order** (highest wins): `error(8)` > `notification(7)` > `sweeping(6)` > `attention(5)` > `carrying/juggling(4)` > `working(3)` > `thinking(2)` > `idle(1)` > `sleeping(0)`

**ONESHOT states** (`attention`, `error`, `sweeping`, `notification`, `carrying`) — auto-return to previous state after `autoReturn` timeout.

**Sleep sequence** (`yawning` → `dozing` → `collapsing` → `sleeping` → `waking`) — triggered by mouse idle, fully automatic.

**Working tiers** — Selects different SVG based on concurrent active session count:
- ≥3 sessions → `building` SVG
- ≥2 sessions → `juggling` SVG  
- ≥1 session → `typing` SVG

### Theme System

Themes live in `themes/<name>/`:
- `theme.json` — metadata, states→SVG mapping, timing, eye tracking, hitboxes, reactions
- `assets/*.svg` — animated SVG files with CSS `@keyframes`

Themes are auto-discovered by `theme-loader.js` scanning the `themes/` directory. Each theme's `theme.json` maps logical states (idle, working, thinking, etc.) to SVG files. The hook/state system sends semantic states — themes just swap which SVGs play. No hook changes needed when adding a theme.

**Required states:** `idle`, `working`, `thinking` (plus `yawning`, `dozing`, `collapsing`, `waking` for full sleep sequence).

### Sound System

Rocky has a 5-word voice vocabulary generated via Windows TTS + organic UFO bed synthesis. Each theme ships its own sounds in `themes/<id>/sounds/`.

**Adding a new sound** requires 3 steps:
1. Add entry to `$soundDefs` in `scripts/generate-rocky-sounds.ps1`
2. Add `playSound()` trigger in `src/state.js` (if new state mapping)
3. Add `"soundName": "soundName.wav"` to `theme.json` → `"sounds"`

See `docs/guides/sound-design.md` for the full pipeline, parameter reference, and tuning guide.

### Hook Event → State Mapping

Defined in `hooks/clawd-hook.js` `resolveState()`:

- **Static mappings**: SessionStart→idle, SessionEnd→sleeping, UserPromptSubmit→thinking, PostToolUseFailure→error, Stop/SubagentStop/PostCompact→attention, Notification/Elicitation→notification, PreCompact→sweeping, SubagentStart→juggling, WorktreeRemove→sweeping
- **PreToolUse tool-type routing**: Read/WebFetch/WebSearch/Glob/Grep→thinking, Agent/Task→juggling, EnterPlanMode→thinking, ExitPlanMode→attention, default→working
- **PostToolUse probability sprinkles**: 10% carrying, 5% sweeping, 85% working (so rare states get screen time)
- **SessionEnd with source="clear"**: sweeping (not sleeping)

### Important: WorktreeCreate Deprecation

The upstream clawd-on-desk intentionally **removed** `WorktreeCreate` from CORE_HOOKS (see `hooks/install.js:33-36`). It's a work-performing hook — Claude Code expects stdout containing the new worktree path. Our notification-only handler breaks `claude -w`. Do not register this hook.
