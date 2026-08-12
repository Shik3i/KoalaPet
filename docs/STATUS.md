# Project Status

**Phase:** Milestone 2 — Content and Simulation Foundation complete

## Repository state

- Windows desktop-overlay validation remains pending and ADR 0010 remains a proposal.
- Milestone 2 proceeded independently because content, time, persistence, gates, and bootstrap have no native-window dependency.
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
- Runtime discovery for bundled, external `user://mods`, and injected fixture roots through one `ContentPackRegistry`
- Deterministic dependency/priority resolution, conflict and override policy, rejected-pack diagnostics, localization index, safe asset paths, and reproducible content snapshots
- Experimental Content API `0.1` runtime trust-boundary validation aligned with the Python authoring validator, including schema/additional-property checks, local localization keys, declared asset roots, and cross-reference resolution
- Injectable system/fake clocks and explicit capped offline-time anomaly policy
- Save envelope version `2`, validated temporary replacement, previous-valid backup, fallback recovery, sequential migration fixture, and lossless missing-content quarantine/restoration
- Declarative recursive feature-gate evaluation, failed-condition explanations, unlock ledger, and idempotent rewards
- Platform-neutral application bootstrap wiring configuration, registry, snapshot, clock, save repository, migrations, gates, explicit snapshot mismatch reporting, and source-safe reconciliation persistence

## Documented only

All actual pet simulation, care effects, starter selection, hatching, production presentation UI, accepted Windows overlay behavior, evolution execution, battle, dungeon, habitat, farm, Trading Post, and production art behavior. Milestone 2 provides infrastructure and neutral fixture records only.

## Latest quality checks

- Content validation passed for 2 packs and 17 content documents.
- Godot `4.7.1.stable.official.a13da4feb` completed a headless editor import of `game/`.
- Repository-relative Markdown link validation passed for 63 local targets.
- Platform-neutral overlay tests passed with 41 assertions, including rejection of headless runs as native-window evidence.
- Milestone 2 foundation tests passed with 99 deterministic assertions across content, time, saves, quarantine, gates, and bootstrap; the Windows symlink fixture was explicitly skipped because the host returned `Failed` creating the link.
- Godot headless import and three-frame spike-scene smoke start passed on macOS.
- macOS matrix: 15 `PASS`, 10 `PASS_WITH_LIMITATION`, 4 `FAIL`, 8 `BLOCKED_NOT_RUN`, 5 `NOT_AVAILABLE`.
- Windows matrix remains unchanged: 6 `PASS`, 4 `PASS_WITH_LIMITATION`, 39 `BLOCKED_NOT_RUN`, 0 `FAIL`.
- Current hardening is covered by the fresh Godot 4.7.1 run above. No native-window evidence is implied by the headless run.

## Known blockers

- All interactive Windows compositor, input, focus, taskbar/Alt+Tab, tray, DPI, multi-monitor, recovery, transition, and performance observations remain blocked.
- macOS gaps: focused Small → Minimal does not release activation; root-window hide fails; the generated status item was not visibly recoverable; shell lifecycle coverage is incomplete.
- Licensing and several product/Windows interaction decisions remain open.

## Next recommended milestone

Begin Milestone 3 only with a data-defined single-pet classic V-pet vertical slice over the completed foundation. Keep Windows overlay validation as a parallel pending technical gate; do not accept ADR 0010 or make production window-topology assumptions until its 39 blocked rows are executed on Windows.
