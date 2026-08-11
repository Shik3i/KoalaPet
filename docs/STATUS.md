# Project Status

**Phase:** Prompt 1 — Windows overlay spike, `PREPARED_BUT_BLOCKED`

## Repository state

- Prompt 0 foundation remains intact.
- Prompt 1 started from clean `main` at `9e06f25f0e4cdbc5d739f8b79a5d1f0aa0e77310`; `git pull --ff-only` returned `Already up to date.`
- A reusable overlay harness and complete evidence matrix are prepared, but no interactive Windows 10/11 environment was available.
- KoalaPet remains a replaceable codename.

## Implemented

- Repository structure and contributor/agent guidance
- Draft content API `0.1` schemas and neutral architecture fixtures
- Python JSON Schema and cross-reference validator
- Minimal Godot project metadata and blank bootstrap scene
- Stable desktop-window adapter contract and guarded Godot Windows implementation
- One-window Minimal/Small/Expanded spike scene with technical code-drawn placeholder
- Deterministic placement sanitation, per-mode spike persistence, lost-window recovery, and bounded hit-region logic
- Status-indicator recovery harness and Windows PowerShell launcher/diagnostics
- Full 49-row Windows validation matrix and privacy-safe evidence structure
- Three supplied UI-mode concept PNGs preserved byte-for-byte outside `res://`

## Documented only

All pet simulation, care, time/offline progression, production persistence, production presentation UI, accepted Windows overlay behavior, evolution, battle, dungeon, habitat, farm, Trading Post, and production art behavior. The spike does not implement gameplay or claim native Windows behavior.

## Latest quality checks

- Content validation passed for 2 packs and 17 content documents.
- Godot `4.7.1.stable.official.a13da4feb` completed a headless editor import of `game/`.
- Repository-relative Markdown link validation passed for 49 local targets.
- Platform-neutral overlay tests passed with 39 assertions.
- Godot headless import and three-frame spike-scene smoke start passed on macOS.
- Matrix state: 6 `PASS`, 4 `PASS_WITH_LIMITATION`, 39 `BLOCKED_NOT_RUN`, 0 `FAIL`.

## Known blockers

- All interactive Windows compositor, input, focus, taskbar/Alt+Tab, tray, DPI, multi-monitor, recovery, transition, and performance observations remain blocked.
- Licensing and several product/Windows interaction decisions remain open.

## Next recommended milestone

Continue Prompt 1 on an interactive Windows 10/11 machine using `tools/windows_overlay_spike/run_spike.ps1`, execute all 39 blocked rows, and record direct evidence. Do not begin Prompt 2 or accept ADR 0010 before that evidence exists.
