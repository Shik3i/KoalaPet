# Project Status / Ist-Stand

**As of:** 2026-08-12

**Phase:** Milestone 2 — Content and Simulation Foundation complete
**Readiness:** Foundation-ready; not a playable product, release build, or accepted Windows overlay

## Executive status

KoalaPet is a Windows-first, local-first desktop virtual-pet project. The repository currently contains a coherent technical foundation and a presentation/overlay spike. It does not yet contain the actual pet-care game loop.

Implemented and verified:

- deterministic content-pack loading and runtime trust-boundary validation
- versioned content snapshots and safe override policy
- injectable clocks and bounded offline-time policy
- local save envelopes, atomic replacement, backups, migrations, recovery, and missing-content quarantine
- recursive feature gates and idempotent unlock grants
- platform-neutral application bootstrap
- Minimal/Small/Expanded presentation contracts and a technical overlay spike
- Python authoring validation, Godot headless checks, platform-neutral tests, and evidence matrices

Not yet product-ready:

- no playable pet, care loop, starter selection, hatching, or production UI
- no official bundled pet content; `koalapet.base` is intentionally content-empty
- no accepted native Windows overlay behavior
- no export, packaging, signing, release, or deployment pipeline

## Repository and Git state

- Working branch: `main`
- Working tree: clean after the status-document commit
- Latest implementation commit: `330618f fix: harden content and save foundation`
- `origin/main`: `773edfa5921112e69e7077a2b549388517043f04`
- Local branch contains unpushed commits relative to `origin/main`; no push was performed
- `git pull --ff-only`: already up to date before implementation
- Project identity remains the replaceable codename `KoalaPet`
- No final product name, license, release version, or distribution channel is established

## Implemented areas

### Product shell and presentation

- Godot 4.x project metadata and bootstrap scene
- Shared presentation contract for Minimal, Small, and Expanded modes
- One-window technical overlay spike with code-drawn placeholder presentation
- Mode-specific placement persistence, sanitation, recovery, hit regions, and status diagnostics
- Presentation remains separate from simulation truth

### Desktop and platform adapters

- Stable desktop-window adapter contract
- Shared Godot-native adapter
- Thin Windows and macOS adapter boundaries
- Windows PowerShell launcher and diagnostics
- macOS probe tooling and evidence capture support
- Native behavior is not accepted yet; headless tests only prove platform-neutral logic

### Content and modding

- Experimental Content API `0.1`
- JSON schemas for packs, localization, starter pools, eggs, families, forms, animations, evolution, moves, items, encounters, dungeons, habitats, furniture, farm jobs, and feature gates
- One `ContentPackRegistry` path for bundled, external, and fixture roots
- Deterministic dependency, priority, conflict, disable, total-conversion, and override handling
- Runtime schema validation with required-field and additional-property checks
- Runtime localization-key and cross-reference validation before pack application
- Safe relative paths, declared asset-root enforcement, safe-media allowlist, file-count/size limits, and executable payload rejection
- Skin overrides restricted to presentation definitions
- Stable namespaced IDs and logical diagnostics
- Deterministic content snapshots with pack/file fingerprints
- Bundled base pack exists but has no entry points or official gameplay definitions
- `mods/examples/example.neutral` is a neutral architecture fixture with 17 content documents, not official product content

### Time, persistence, and recovery

- `SimulationClock`, system clock, fake clock, and deterministic offline-progress policy
- Save envelope version `2`
- Validated temporary writes, flush, atomic replacement, `.bak` preservation, and `.swap` recovery
- Sequential `foundation.v1_to_v2` migration fixture with idempotence coverage
- Complete raw-record preservation when required content is missing
- Deterministic quarantine and restoration through `ContentBindingReconciler`
- Persisted content snapshots compared against the active registry snapshot during bootstrap
- Snapshot mismatch remains explicit in recovery metadata
- Primary-source migration/reconciliation changes are persisted automatically
- Backup/swap recovery is never silently written over the malformed primary; `FoundationBootstrap.save_current()` is the explicit acknowledgement boundary

### Progression

- Read-only `ProgressionFacts`
- Recursive `all`, `any`, and `not` gate evaluation
- Failed-condition paths and deterministic repeated evaluation
- Invalid gate operands fail closed, including nested negation and `any` branches
- Idempotent `UnlockLedger` grants with duplicate-grant prevention
- No onboarding UI or production progression content

### Architecture boundaries

- Domain layer is reserved for future pure pet/lifecycle/care/evolution/battle/dungeon/resident logic
- Infrastructure owns persistence, migrations, recovery, and quarantine
- Content loading is isolated from application coordination
- Presentation and platform code do not own simulation state
- Art source remains outside `res://`; generated/runtime assets have a controlled boundary
- Initial mod model is JSON plus safe media only; no scripts, DLLs, native code, or executable payloads

## Current product/content state

| Area | State |
|---|---|
| Pet domain simulation | Not implemented |
| Care loop | Not implemented |
| Starter choice and hatching | Not implemented |
| Evolution execution | Documented/data contract only |
| Battles and dungeon runtime | Documented/data contract only |
| Habitat customization runtime | Documented/data contract only |
| Farm, residents, and idle jobs | Documented/data contract only |
| Trading Post/economy | Roadmap only |
| Production UI/art | Not implemented; technical placeholder only |
| Official base content | Intentionally empty |
| Neutral example content | Present for registry/validator coverage |
| Local saves | Foundation implementation complete |
| Mod scripts/network/accounts/telemetry | Out of current core scope |
| Playable build/export | Not present |
| Release/signing/deployment | Not present |

## Validation evidence

Latest full foundation gate with Godot `4.7.1.stable.official.a13da4feb`:

- Content validator: `2` packs, `17` content documents — PASS
- JSON parse: `43` files — PASS
- Python in-memory compile: `3` source files — PASS
- Repository-relative Markdown links: `63` targets — PASS
- Godot headless editor import — PASS
- Foundation suite: `99` assertions — PASS
- Platform-neutral overlay suite: `41` assertions — PASS
- Mod payload, neutral-terminology, repository-artifact, and whitespace checks — PASS
- Symlink fixture: explicitly skipped because this Windows host returned `Failed` while creating the test link; production symlink rejection remains implemented and documented
- Headless results are not native-window evidence

Recorded platform evidence remains separate:

- Windows matrix: `6 PASS`, `4 PASS_WITH_LIMITATION`, `39 BLOCKED_NOT_RUN`, `0 FAIL`
- macOS matrix: `15 PASS`, `10 PASS_WITH_LIMITATION`, `4 FAIL`, `8 BLOCKED_NOT_RUN`, `5 NOT_AVAILABLE`
- macOS headless import and three-frame spike smoke start: recorded PASS
- Existing macOS native gaps remain open; they do not establish Windows behavior

## Known blockers and risks

- 39 interactive Windows rows remain blocked: compositor transparency, input passthrough, focus, taskbar/Alt+Tab, tray/status recovery, DPI, multi-monitor placement, mode transitions, recovery, and performance
- macOS native gaps: focused Small → Minimal activation release, root-window hide, visible status-item recovery, and shell lifecycle coverage
- No playable vertical slice exists yet, so domain balance, save semantics for real pets, onboarding, and product usability are unvalidated
- No final licensing decision or production asset-rights package exists
- Final branding, care profile, lifecycle endpoint, combat input, evolution disclosure, habitat placement, and MVP content counts remain open
- Godot headless validation cannot replace interactive Windows acceptance

## Next work

Milestone 3: build a data-defined single-pet classic V-pet vertical slice over the completed foundation.

Required scope:

- starter-pool selection and hatching
- one active pet with save/reload identity
- baseline food, cleaning, sleep, attention, waste, health, illness, treatment, and training
- deterministic offline progress through the injectable clock
- one authoritative simulation rendered through Minimal, Small, and Expanded modes
- migration/recovery tests against real pet records

Keep Windows overlay validation running in parallel. Do not accept ADR 0010 or make production window-topology assumptions until the blocked Windows rows are executed on an interactive Windows 10/11 desktop.
