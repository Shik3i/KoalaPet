# Testing and Quality

Evidence must match claims. Prompt 0 checks schemas/examples, cross-references, Godot headless open/import, Markdown links/local paths, references, prohibited terminology, generated artifacts/binaries, final tree, contradictions, and `git diff --check`.

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
