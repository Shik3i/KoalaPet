# Testing and Quality

Evidence must match claims. Repository checks cover schemas/examples, cross-references, Godot headless open/import, Markdown links/local paths, references, prohibited terminology, generated artifacts/binaries, final tree, contradictions, and `git diff --check`.

## Prompt 1 overlay evidence

- `game/tests/platform/run_all.gd`: 41 deterministic assertions for placement, recovery, persistence envelopes, transition invariants, near-edge mode switching, stress transitions, hit-region bounds, platform adapter selection, and the headless/native evidence gate.
- `game/scenes/spikes/windows_overlay_spike.tscn`: parser/runtime smoke target; successful headless startup is not native-window proof.
- `docs/evidence/windows-overlay/test-matrix.json`: all 49 required rows with environment, configuration, method, expected, actual, status, artifacts, notes, and timing fields.
- Current matrix: 6 `PASS`, 4 `PASS_WITH_LIMITATION`, 39 `BLOCKED_NOT_RUN`, 0 `FAIL`.
- `tools/windows_overlay_spike/run_spike.ps1`: exact-version Windows launcher and evidence path.
- `docs/evidence/macos-overlay/test-matrix.json`: separate macOS results with direct native, headless-only, unavailable, and blocked cases kept distinct.
- macOS matrix: 15 `PASS`, 10 `PASS_WITH_LIMITATION`, 4 `FAIL`, 8 `BLOCKED_NOT_RUN`, 5 `NOT_AVAILABLE`.
- `tools/macos_overlay_spike/`: exact-version native runners plus deterministic pointer probes used for direct input and drag reproduction.

Headless, macOS, API presence, synthetic geometry, and unit tests must never be reported as evidence of Windows compositor, shell, input routing, DPI movement, tray, or performance behavior. Headless macOS validates logic only; `DisplayServer=headless` is explicitly rejected by the native adapter gate.

## Milestone 2 foundation evidence

- `game/tests/foundation/run_all.gd`: 87 deterministic assertions.
- Content coverage: bundled/external common loader, stable snapshot, topology/priority, required/optional dependencies, conflicts, disabled/total-conversion policy, explicit and unauthorized overrides, skin restrictions, duplicate packs/IDs, invalid IDs/API/manifests/documents, logical diagnostics, traversal, absolute paths, unsupported media, executable payloads, symlinks, localization, and reference explanations.
- Time coverage: normal/zero elapsed, rollback, negative drift, forward jump, cap, missing/invalid UTC, and fake wall/monotonic clocks.
- Save coverage: v2 round trip, validated replacement, backup, malformed-primary recovery, both-invalid failure, v1 migration/idempotence, content snapshot, quarantine, raw preservation, and restoration.
- Gate/bootstrap coverage: pass/fail, `all`/`any`/`not`, explanations, repeat determinism, idempotent grants, duplicate prevention, and injected platform-neutral service composition.
- `tools/run_foundation_checks.py`: JSON parse, in-memory Python compile, Python content validation, Markdown links, mod payload/symlink scan, terminology scan, repository artifact/cache scan, Godot import, foundation tests, platform-neutral regressions, and `git diff --check`.

Headless tests prove only platform-neutral foundation behavior. They preserve the existing rule that native Windows validation remains pending.

Future quality layers:

- Pure pet-domain unit tests with fake clock and fixed seeds
- Atomic-write failure injection beyond the successful replacement/recovery paths
- Long offline intervals, clock rollback, cap, and version-transition tests
- Scene/UI interaction tests across Minimal, Small, and Expanded modes
- Rendered screenshots at compact sizes, DPI scales, and accessibility settings
- Windows hardware/VM matrix for overlay behavior and multi-monitor recovery
- Content-pack contract fixtures, including the bundled base pack

Automated screenshots/video and AI review support art QA, but do not replace runtime/accessibility evidence. CI is deferred until the first workflow can run deterministically on supported environments.
