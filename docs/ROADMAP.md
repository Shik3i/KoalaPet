# Roadmap

Sequencing protects coherence; it is not permission to remove later accepted systems.

## 0. Repository and canon bootstrap

Dependencies: none. Acceptance: authority hierarchy, useful system docs, accepted foundation ADRs, draft schemas/example pack, runnable validator, minimal Godot shell if possible, quality evidence, and explicit blockers. **Complete.**

## 1. Windows desktop-overlay technical spike

Dependencies: Godot version pin and Windows test environment. Acceptance: measured evidence for transparency, passthrough, always-on-top, dragging, DPI, taskbar edges, multi-monitor geometry, minimize/restore, saved placement, and Minimal/Small/Expanded transitions; risks and adapter contract documented. No production UI or gameplay. **Current: reusable cross-platform harness, 41 logic assertions, separate Windows/macOS matrices, and supplementary native macOS findings completed. Acceptance remains blocked on an interactive Windows 10/11 run; ADR 0010 stays proposed. This pending platform gate does not block platform-neutral simulation milestones.**

## 2. Content and simulation foundation

Dependencies: platform-neutral architecture boundaries established by milestone 1; native topology acceptance is not required. Acceptance: content registry and validation, explicit experimental schema status, save envelope and migrations, clock abstraction, offline policy, feature gates, base-pack loading, missing-content quarantine, deterministic tests. **Complete: runtime registry/snapshot, Content API `0.1` trust boundary, clocks/offline policy, save v2/migration/backup/quarantine, gates/unlock ledger, bootstrap, and 87 headless assertions.**

## 3. Single-pet classic V-pet vertical slice

Dependencies: milestone 2. Acceptance: data-defined egg choice/hatching and a coherent care lifecycle covering baseline needs, sleep, waste, attention, illness/treatment, training, save/reload, offline progress, and all three presentations. Baseline care never requires currency.

## 4. Branching evolution, normal battles, and first dungeon

Dependencies: stable lifecycle and content registry. Acceptance: at least meaningful good-care and poor-care branches, short encounters, injuries/recovery, experience/history inputs, one multi-stage dungeon, boss and cross-system rewards.

## 5. Habitat customization and unlock rewards

Dependencies: first dungeon rewards. Acceptance: layered mixable habitat components, persistent placement, functional stations, accessible editing, and rewards from progression.

## 6. Second egg, farm reveal, residents, and idle jobs

Dependencies: mature-pet lifecycle and save safety. Acceptance: purpose-driven reveal, settled-ready eligibility, identity-preserving recall, second active raising cycle, deterministic capped offline jobs, no resident neglect death.

## 7. Trading Post and economy integration

Dependencies: dungeon materials and farm production. Acceptance: rotating orders, keep/process/sell decisions, sustainable baseline care, tunable economy, and no mandatory restaurant simulation.

## 8. Content, accessibility, packaging, and release preparation

Dependencies: coherent product MVP loop. Acceptance: final first-MVP content counts, original production assets, accessibility review, Windows packaging/signing plan, migration/recovery testing, performance/long-offline tests, onboarding polish, and release checklist.

## First product MVP definition

A coherent desktop V-pet product: one complete raising journey; meaningful branching evolution; normal battles and a dungeon; habitat rewards; a second egg and safe recallable residents; useful idle jobs; Trading Post integration; robust local saves; accessible, unobtrusive three-mode presentation. It is not merely an engine/content-loader demo.
