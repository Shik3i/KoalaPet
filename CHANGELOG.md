# Changelog

All notable changes will be documented here. The format follows Keep a Changelog principles; versions will use semantic versioning once releases begin.

## Unreleased

### Added

- Prompt 0 repository, canonical documentation, draft content schemas, neutral example pack, validation tooling, and minimal Godot shell.
- Prompt 1 Windows overlay validation harness: adapter contract, one-window mode spike, placement/recovery logic, status-indicator recovery, PowerShell diagnostics, 49-row evidence matrix, and 39 platform-neutral assertions. Interactive Windows validation remains blocked.
- Prompt 1 supplementary macOS validation: shared Godot-native adapter, macOS-specific minimize handling, headless/native evidence gate, neutral underlay, 42-row matrix, privacy-safe screenshots, and 41 platform-neutral assertions. Native findings do not provide Windows evidence.
- Milestone 2 content and simulation foundation: deterministic runtime pack registry/snapshots, experimental Content API `0.1` gate/manifest updates, untrusted pack checks, injected clocks/offline policy, save v2/backups/migration/quarantine, declarative gates/unlock ledger, platform-neutral bootstrap, consolidated checks, and 99 headless assertions after hardening.
- Supplied Expanded, Small, and Minimal concept PNGs preserved byte-for-byte under `references/ui-modes/`.

### Fixed

- Hardened runtime content loading with schema/additional-property validation, localization and cross-reference checks, declared asset-root parity, safe override namespace handling, and base-pack policy parity with authoring validation.
- Made malformed feature-gate operands fail closed, including nested `not` and `any` conditions.
- Added explicit content-snapshot mismatch reporting and source-safe bootstrap reconciliation persistence; recovered saves require an explicit save before replacing their snapshot.
