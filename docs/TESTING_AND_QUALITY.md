# Testing and Quality

Evidence must match claims. Repository checks cover schemas/examples, cross-references, Godot headless open/import, Markdown links/local paths, references, prohibited terminology, generated artifacts/binaries, final tree, contradictions, and `git diff --check`.

## Prompt 1 overlay evidence

- `game/tests/platform/run_all.gd`: 39 deterministic assertions for placement, recovery, persistence envelopes, transition invariants, near-edge mode switching, stress transitions, and hit-region bounds.
- `game/scenes/spikes/windows_overlay_spike.tscn`: parser/runtime smoke target; successful headless startup is not native-window proof.
- `docs/evidence/windows-overlay/test-matrix.json`: all 49 required rows with environment, configuration, method, expected, actual, status, artifacts, notes, and timing fields.
- Current matrix: 6 `PASS`, 4 `PASS_WITH_LIMITATION`, 39 `BLOCKED_NOT_RUN`, 0 `FAIL`.
- `tools/windows_overlay_spike/run_spike.ps1`: exact-version Windows launcher and evidence path.

Headless, macOS, API presence, synthetic geometry, and unit tests must never be reported as evidence of Windows compositor, shell, input routing, DPI movement, tray, or performance behavior.

Future quality layers:

- Pure deterministic domain unit tests with fake clock and fixed seeds
- Schema, dependency, collision, override, and malicious-path tests
- Save round-trip, atomic-write failure, corruption recovery, migration, and missing-pack tests
- Long offline intervals, clock rollback, cap, and version-transition tests
- Scene/UI interaction tests across Minimal, Small, and Expanded modes
- Rendered screenshots at compact sizes, DPI scales, and accessibility settings
- Windows hardware/VM matrix for overlay behavior and multi-monitor recovery
- Content-pack contract fixtures, including the bundled base pack

Automated screenshots/video and AI review support art QA, but do not replace runtime/accessibility evidence. CI is deferred until the first workflow can run deterministically on supported environments.
