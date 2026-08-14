# Changelog

All notable changes will be documented here. The format follows Keep a Changelog principles; versions will use semantic versioning once releases begin.

## Unreleased

### Added

- Prompt 0 repository, canonical documentation, draft content schemas, neutral example pack, validation tooling, and minimal Godot shell.
- Prompt 1 Windows overlay validation harness: adapter contract, one-window mode spike, placement/recovery logic, status-indicator recovery, PowerShell diagnostics, 49-row evidence matrix, and 39 platform-neutral assertions. Interactive Windows validation remains blocked.
- Prompt 1 supplementary macOS validation: shared Godot-native adapter, macOS-specific minimize handling, headless/native evidence gate, neutral underlay, 42-row matrix, privacy-safe screenshots, and 41 platform-neutral assertions. Native findings do not provide Windows evidence.
- Milestone 2 content and simulation foundation: deterministic runtime pack registry/snapshots, experimental Content API `0.1` gate/manifest updates, untrusted pack checks, injected clocks/offline policy, save v2/backups/migration/quarantine, declarative gates/unlock ledger, platform-neutral bootstrap, consolidated checks, and 99 headless assertions after hardening.
- Milestone 3 single-pet classic V-pet vertical slice: three data-defined starter eggs, pure deterministic hatching/care simulation, offline cap, waste/attention/illness/treatment/training, bounded history and aggregates, pet save/reload/quarantine bindings, Minimal/Small/Expanded presentation, 42 provisional generated assets, and 28 dedicated assertions.
- Supplied Expanded, Small, and Minimal concept PNGs preserved byte-for-byte under `references/ui-modes/`.
- Prompt 3.5 interactive Windows product review: isolated-save walkthrough for all three starters, hatch/care/sickness/sleep/relaunch evidence, native overlay diagnostics, DPI/taskbar inventory, and idle performance measurements.
- Milestone 4 branching evolution, normal battles, and first dungeon: six juvenile routes across three families, deterministic evolution evidence/pending transitions, stance-based battles, levels/history/drops/injuries, a five-node dungeon with boss, idempotent rewards/unlocks/codex records, save v3 migration, 62 dedicated assertions, 109 validated provisional assets, and isolated gameplay review.
- Prompt 4.5 complete player-presentation rebuild: coherent Minimal/Small/Expanded modes, transparent walking desktop pet, layered Quiet Canopy habitat, shared pixel UI/component library, 19-source provisional art batch covering all current creatures/enemies/boss/eggs/icons, deterministic processing/provenance, 121 presentation assertions, and privacy-safe native screenshots plus interaction video.
- Prompt 4.6 product polish: genuine eight-frame locomotion for all nine playable forms, animation-state/one-shot controller, anchored habitat actions and bounded roaming, versioned presentation preferences, larger Small/Expanded layouts, independent UI/text/pet scaling, stricter alpha/geometry validation, native Windows screenshots/GIFs/video and seven-scenario performance evidence; no Milestone 5 gameplay.
- Prompt 4.7 living-animation expansion: 29 multi-frame states for every current playable form, five combat/reaction states for every current enemy, marker-driven family VFX, deterministic ambient/Minimal behavior, bounded priority queues, richer Reduced Motion/preferences, native Movie Writer evidence and eight-scenario performance measurements; no Milestone 5 gameplay.
- Prompt 4.9 animation and interface polish: real six- and eight-frame egg cycles generated from the accepted egg art, a 290-sequence animation audit gate covering frame count, cycle length, real motion and pops, habitat station highlighting while the pet walks to an action, a per-round battle log, contextual-tab progress summaries, and a one-time first-care hint.
- Prompt 4.9 interactive UI/UX rescue: rebuilt Small and Expanded information architecture, four labelled care meters with text alternatives, contextual alerts and contextual action replacement, gated Adventure navigation, responsive habitat frame, shared `UiMetrics` spacing/type/icon scale, nine generated symbol icons plus crisp 2x twins, genuinely resizable Small and Expanded with remembered per-mode size, localized feedback for every command outcome, duplicate-input protection, an in-engine privacy-safe capture path and a closed-loop interactive action matrix; no Milestone 5 gameplay.
- Prompt 4.8 visual-acceptance gate: debug-only runtime Animation Showroom for 16 entities/290 sequences, exhaustive classifications, concise reels/contact sheets, complete visual-rights register, asset optimization audit and direct Windows DPI/keyboard/shell evidence; no Milestone 5 gameplay.

### Fixed

- Hardened runtime content loading with schema/additional-property validation, localization and cross-reference checks, declared asset-root parity, safe override namespace handling, and base-pack policy parity with authoring validation.
- Made malformed feature-gate operands fail closed, including nested `not` and `any` conditions.
- Added explicit content-snapshot mismatch reporting and source-safe bootstrap reconciliation persistence; recovered saves require an explicit save before replacing their snapshot.
- Fixed application content-root typing for injected test/runtime configurations and expanded quarantine checks to every persisted pet content binding.
- Fixed starter-card clipping/import visibility, German localization fallbacks, hatch-progress visibility, mode-refresh resizing, Expanded/status clipping, and Small sickness-action clipping in the Godot product shell.
- Fixed stale feature-gate test expectations after adding adventure gates, Python/runtime evolution-schema parity for stage-age fields, and application-layer loss of pending evolution states at unsafe transition points.
- Fixed the three starter eggs animating as a two-frame flicker at 10 fps, which was the first animation every new player saw and made hatching unreadable as an event.
- Fixed contextual alert chips rendering as a bare icon: an ellipsis overrun collapses a Label's minimum width, so the alert text never appeared.
- Fixed Battle and Dungeon offering the same command twice, once in the centre panel and once in the contextual action column, and offering "next stage" while the player was standing on a dungeon branch.
- Fixed the Inventory, Codex and Evolution context columns showing a heading above empty space.
- Fixed the status toast landing on the Expanded tab row and on the Small status bars.
- Fixed the player interface printing raw `error_code`/`reason` text, accepting duplicate commands from one double click, allowing a rebuild to re-enter itself, and letting the status toast intercept clicks aimed at the interface behind it.
- Fixed `auto` UI scale never leaving 100% on Windows, where `screen_get_scale()` always reports `1.0`; the whole interface rendered at roughly 80% of its intended physical size on a 125% display. Auto now derives from display DPI.
- Fixed Small and Expanded being unable to resize: a non-zero `content_scale_size` pinned the root viewport and therefore the native client area to the project boot size.
- Fixed player-facing icons resolving to unrelated art (`close` showed the injury plaster, `minimize` the Minimal glyph, `discipline` the training log, `call` the health cross).
- Fixed the Adventure action disabling itself while the battle it advances was running, and Expanded overflowing its window because an autowrapping caption collapsed to one character per line inside a narrow grid column.
- Fixed non-idempotent repeated hatch completion, stale native HWND capture after transparent-window reconfiguration, missing DE/EN inventory localization, unreadably narrow localized reward slots, and invalid review-fixture adventure commands leaking player-facing errors into care captures.
- Hardened saves and commands against stale concurrent writers, false numeric snapshot mismatches, malformed versions/records/command values, oversized input, failed persistence, partial transactions, stale action timers, and silent no-op actions.
- Bounded visual-review paths, rates, durations, image dimensions and memory use; closed content/image handles; added Ruff/GDLint policy, pinned Pillow, dependency audit evidence, and cache-complete `.gitignore` coverage.
- Replaced two-pose idle/care/sleep/combat placeholders, prevented duplicate/overflowed animation events and marker skipping, returned nonterminal opponents to idle, suspended hidden playback, debug-build-gated mutating review/dev flags, rejected blank Vulkan `PrintWindow` captures, isolated performance saves and removed stale diagnostic reuse.
- Removed helper-hand/source-cell contamination from 63 care/call/sleep sequences, corrected two-frame egg markers and loop-override caching, validated marker order/range, and forced Windows CLI/test tooling to use the Godot console executable instead of the GUI executable.
- Fixed the player UI crash caused by freeing the active button during its own `pressed` signal; state-changing UI callbacks are deferred, presentation trees use queued release, and signal-faithful integration coverage now exercises feed/care, navigation, battle and settings controls.
