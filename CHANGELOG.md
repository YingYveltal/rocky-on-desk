# Changelog

## v1.0.0 (2026-05-07)

Initial public release.

### Features
- **Rocky theme** — 18 animated SVG states: idle, thinking, working (3 tiers), sleeping (5-stage sequence), juggling, carrying, sweeping, error, happy, notification, click reactions
- **Rocky Domed theme** — Rocky with protective xenonite dome, same animation set
- **Sound effects** — 5-word Rocky vocabulary across both themes (complete, confirm, error, thinking, waking)
- **Cursor tracking** — Sonar sensor crystals track cursor position
- **Working tiers** — Typing (1 session) → Juggling (2+) → Building (3+)
- **Full sleep sequence** — Yawn → Doze → Collapse → Sleep → Wake
- **Click reactions** — Drag to dangle, double-click to flail
- **Hook state mapping** — Tool-type differentiation (Read→thinking, Agent→juggling, etc.) + probabilistic rare-state sprinkles

### Build
- Windows x64 NSIS installer (`Rocky-on-Desk-Setup-x64.exe`)
- macOS DMG
- Linux AppImage + deb
- GitHub Actions CI/CD with auto-release on tag push
