# Project Status

**Phase:** Prompt 1 — macOS supplementary pass complete; Windows validation `BLOCKED_NOT_RUN`

## Repository state

- Prompt 0 foundation remains intact.
- The reusable overlay harness now has explicit Windows and macOS adapter boundaries.
- Native macOS findings are recorded separately and make no Windows claims.
- KoalaPet remains a replaceable codename.

## Implemented

- Repository structure and contributor/agent guidance
- Draft content API `0.1` schemas and neutral architecture fixtures
- Python JSON Schema and cross-reference validator
- Minimal Godot project metadata and blank bootstrap scene
- Stable desktop-window adapter contract, shared Godot native implementation, and thin Windows/macOS adapters
- One-window Minimal/Small/Expanded spike scene with technical code-drawn placeholder
- Deterministic placement sanitation, per-mode spike persistence, lost-window recovery, and bounded hit-region logic
- Status-indicator recovery harness and Windows PowerShell launcher/diagnostics
- Full 49-row Windows validation matrix plus a separate 42-row macOS evidence matrix and privacy-safe captures
- Three supplied UI-mode concept PNGs preserved byte-for-byte outside `res://`

## Documented only

All pet simulation, care, time/offline progression, production persistence, production presentation UI, accepted Windows overlay behavior, evolution, battle, dungeon, habitat, farm, Trading Post, and production art behavior. The spike does not implement gameplay or claim native Windows behavior.

## Latest quality checks

- Content validation passed for 2 packs and 17 content documents.
- Godot `4.7.1.stable.official.a13da4feb` completed a headless editor import of `game/`.
- Repository-relative Markdown link validation passed for 49 local targets.
- Platform-neutral overlay tests passed with 41 assertions, including rejection of headless runs as native-window evidence.
- Godot headless import and three-frame spike-scene smoke start passed on macOS.
- macOS matrix: 15 `PASS`, 10 `PASS_WITH_LIMITATION`, 4 `FAIL`, 8 `BLOCKED_NOT_RUN`, 5 `NOT_AVAILABLE`.
- Windows matrix remains unchanged: 6 `PASS`, 4 `PASS_WITH_LIMITATION`, 39 `BLOCKED_NOT_RUN`, 0 `FAIL`.

## Known blockers

- All interactive Windows compositor, input, focus, taskbar/Alt+Tab, tray, DPI, multi-monitor, recovery, transition, and performance observations remain blocked.
- macOS gaps: focused Small → Minimal does not release activation; root-window hide fails; the generated status item was not visibly recoverable; shell lifecycle coverage is incomplete.
- Licensing and several product/Windows interaction decisions remain open.

## Next recommended milestone

Continue Prompt 1 on an interactive Windows 10/11 machine using `tools/windows_overlay_spike/run_spike.ps1`, execute all 39 blocked rows, and record direct evidence. Do not begin Prompt 2 or accept ADR 0010 before that evidence exists.
