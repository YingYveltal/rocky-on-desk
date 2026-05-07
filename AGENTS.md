# AGENTS.md

This file is the entry point for coding agents working in this repository. Keep it short and operational. Deep background lives in `CLAUDE.md`.

## Project Overview

Rocky on Desk is an Electron desktop pet — a pixel-art Rocky (the Eridian engineer from *Project Hail Mary*) that lives on your desktop and reacts to Claude Code events in real time. Built on the [clawd-on-desk](https://github.com/rullerzhou-afk/clawd-on-desk) framework.

Two custom themes: **Rocky** (classic) and **Rocky Domed** (with xenonite dome).

## Common Commands

```bash
npm install              # Install dependencies
npm start                # Launch the desktop pet (node launch.js → Electron)
npm test                 # Run test suite (node --test test/*.test.js)
npm run build:win:x64    # Build Windows x64 installer
npm run build:mac        # Build macOS installer
npm run build:linux      # Build Linux installer
```

**Theme / asset tooling:**
```bash
npx electron scripts/generate-gifs.js <theme-name>   # Generate GIF previews (requires Electron)
```

**Hook management:**
```bash
node hooks/install.js     # Register Claude Code hooks into ~/.claude/settings.json
node hooks/uninstall.js   # Remove all clawd hooks from ~/.claude/settings.json
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

### State Machine (src/state.js)

Priority order (highest wins): error(8) > notification(7) > sweeping(6) > attention(5) > carrying/juggling(4) > working(3) > thinking(2) > idle(1) > sleeping(0).

ONESHOT states (attention, error, sweeping, notification, carrying) auto-return after `autoReturn` timeout.

Sleep sequence (yawning → dozing → collapsing → sleeping → waking) triggered by mouse idle.

Working tiers select different SVG based on concurrent session count: ≥3 → building, ≥2 → juggling, ≥1 → typing.

### Hook Event → State Mapping

Defined in `hooks/clawd-hook.js` `resolveState()`:
- Static mappings: SessionStart→idle, SessionEnd→sleeping, UserPromptSubmit→thinking, PostToolUseFailure→error, Stop/SubagentStop/PostCompact→attention, Notification/Elicitation→notification, PreCompact→sweeping, SubagentStart→juggling, WorktreeRemove→sweeping
- PreToolUse tool-type routing: Read/WebFetch/WebSearch/Glob/Grep→thinking, Agent/Task→juggling, EnterPlanMode→thinking, ExitPlanMode→attention, default→working
- PostToolUse probability sprinkles: 10% carrying, 5% sweeping, 85% working
- SessionEnd with source="clear" → sweeping

### Theme System

Themes live in `themes/<name>/`:
- `theme.json` — metadata, states→SVG mapping, timing, eye tracking, hitboxes, reactions, sounds
- `sounds/*.wav` — per-theme sound effects
- `assets/*.svg` — animated SVG files with CSS @keyframes

Themes are auto-discovered by `theme-loader.js`. The hook/state system sends semantic states — themes just swap which SVGs play.

## Core Files

| File | Role |
|------|------|
| `src/main.js` | Electron entry — window management, drag, sizing, tray, IPC |
| `src/state.js` | State machine — session tracking, priority resolution, sleep, working tiers, DND |
| `src/server.js` | HTTP server — `/state`, `/permission`, `/health` |
| `src/renderer.js` | Animation switching, SVG preloading, eye-tracking rendering |
| `src/theme-loader.js` | Loads + validates theme.json, discovers themes from `themes/` directory |
| `src/tick.js` | Main loop — mouse polling, eye/idle logic |
| `src/menu.js` | Tray / context menu |
| `src/prefs.js` | Preferences — load/save/migrate/validate |
| `src/settings-controller.js` | Settings system sole writer |
| `src/settings-store.js` | Immutable settings snapshot store |
| `src/updater.js` | electron-updater integration |
| `hooks/clawd-hook.js` | **The hook script** — event→state mapping, tool-type routing, probability sprinkles |
| `hooks/install.js` | Registers/unregisters clawd hooks in `~/.claude/settings.json` |
| `hooks/server-config.js` | Port discovery, runtime config, HTTP helpers |
| `launch.js` | Strips ELECTRON_RUN_AS_NODE before spawning Electron |

## Key Constraints

- HTTP server port range: `127.0.0.1:23333-23337`; runtime port written to `~/.clawd/runtime.json`
- Hook scripts must only depend on Node built-ins + `server-config.js`, `shared-process.js`, `json-utils.js`
- Registering Claude Code hooks must append, never overwrite existing user hooks
- The `<_t>` cache-bust query param on SVG `<img>` tags must not be removed — Chromium reuses animation timelines for same-URL SVGs
- Windows NSIS installers must produce per-architecture builds; `nsis.buildUniversalInstaller` must stay `false`
- WorktreeCreate hook is intentionally removed — it's a work-performing hook whose stdout is consumed by Claude Code
