# Roadmap

Sequencing protects coherence; it is not permission to remove later accepted systems.

## 0. Repository and canon bootstrap

Dependencies: none. Acceptance: authority hierarchy, useful system docs, accepted foundation ADRs, draft schemas/example pack, runnable validator, minimal Godot shell if possible, quality evidence, and explicit blockers. **Complete.**

## 1. Windows desktop-overlay technical spike

Dependencies: Godot version pin and Windows test environment. Acceptance: measured evidence for transparency, passthrough, always-on-top, dragging, DPI, taskbar edges, multi-monitor geometry, minimize/restore, saved placement, and Minimal/Small/Expanded transitions; risks and adapter contract documented. No production UI or gameplay. **Current: reusable cross-platform harness, 41 logic assertions, direct Windows 11 native diagnostics, separate Windows/macOS matrices, and supplementary native macOS findings completed. Prompt 4.8 directly confirms Alt+Tab responsiveness, minimize/restore, taskbar geometry and a 100/125% monitor inventory. Tray recovery/callback/cleanup, Show Desktop and controlled mixed-DPI parity remain open; ADR 0010 stays proposed. This pending platform gate does not block platform-neutral simulation milestones.**

## 2. Content and simulation foundation

Dependencies: platform-neutral architecture boundaries established by milestone 1; native topology acceptance is not required. Acceptance: content registry and validation, explicit experimental schema status, save envelope and migrations, clock abstraction, offline policy, feature gates, base-pack loading, missing-content quarantine, deterministic tests. **Foundation implemented: runtime registry/snapshot with schema/reference trust checks, Content API `0.1` boundary, clocks/offline policy, save v3/migration/backup/quarantine with explicit snapshot reconciliation and concurrent-writer rejection, gates/unlock ledger, bootstrap, and 112 headless foundation assertions. The Windows symlink fixture remains capability-limited; native-window acceptance remains separate.**

## 3. Single-pet classic V-pet vertical slice

Dependencies: milestone 2. Acceptance: data-defined egg choice/hatching and a coherent care lifecycle covering baseline needs, sleep, waste, attention, illness/treatment, training, save/reload, offline progress, and all three presentations. Baseline care never requires currency.

**Implemented and locally validated:** three starter eggs, deterministic pure simulation, care profiles, hatching, waste/attention/illness/treatment/training, bounded history and aggregates, save/reload/quarantine bindings, transactional failure rollback, Minimal/Small/Expanded UI, and 44 dedicated assertions. Prompt 3.5 added direct Windows product evidence and fixed confirmed UI P1 defects. Native shell and accessibility acceptance remain open.

## 4. Branching evolution, normal battles, and first dungeon

Dependencies: stable lifecycle and content registry. Acceptance: at least meaningful good-care and poor-care branches, short encounters, injuries/recovery, experience/history inputs, one multi-stage dungeon, boss and cross-system rewards.

**Implemented and validated through 2026-08-14:** automatic data-defined good/poor routes for all three starter families, deterministic stanced battles with level/experience/history/injury/recovery, one five-node dungeon with event/rest/boss flow, idempotent first-clear/repeat rewards, future habitat theme/trophy unlock storage, save v3 migration, codex/discovery records, and isolated Windows gameplay evidence. Prompt 4.8 adds exhaustive visual classification, correction and a debug-only runtime Showroom without changing domain rules. Combat interaction, evolution disclosure and final art remain provisional. Native overlay work remains parallel and ADR 0010 remains proposed.

**Prompt 4.9 (2026-08-14):** the rejected Small-mode interface was rebuilt rather than enlarged. Information architecture, feedback, input safety, window resizing, icon clarity and the readable default scale are now governed by [`PLAYER_INTERFACE.md`](PLAYER_INTERFACE.md) and [`WINDOW_MODES.md`](WINDOW_MODES.md). No domain rule, content document or save format changed, and Milestone 5 remains unstarted.

## 5. Habitat customization and unlock rewards

Dependencies: first dungeon rewards. Acceptance: layered mixable habitat components, persistent placement, functional stations, accessible editing, and rewards from progression.

**Not started. Prompts 4.5–4.8 rebuilt, animated and reviewed only the fixed presentation habitat; station routing, ambient prop reactions, Showroom tooling and effects are presentation behavior, not editing or furniture placement. Entry gate remains closed: product-owner visual approval, resolved provisional-art rights/license, usable screen-reader exposure, and the remaining native Windows DPI/tray/mixed-DPI rows are required.**

## 6. Second egg, farm reveal, residents, and idle jobs

Dependencies: mature-pet lifecycle and save safety. Acceptance: purpose-driven reveal, settled-ready eligibility, identity-preserving recall, second active raising cycle, deterministic capped offline jobs, no resident neglect death.

## 7. Trading Post and economy integration

Dependencies: dungeon materials and farm production. Acceptance: rotating orders, keep/process/sell decisions, sustainable baseline care, tunable economy, and no mandatory restaurant simulation.

## 8. Content, accessibility, packaging, and release preparation

Dependencies: coherent product MVP loop. Acceptance: final first-MVP content counts, original production assets, accessibility review, Windows packaging/signing plan, migration/recovery testing, performance/long-offline tests, onboarding polish, and release checklist.

## First product MVP definition

A coherent desktop V-pet product: one complete raising journey; meaningful branching evolution; normal battles and a dungeon; habitat rewards; a second egg and safe recallable residents; useful idle jobs; Trading Post integration; robust local saves; accessible, unobtrusive three-mode presentation. It is not merely an engine/content-loader demo.
