# Architecture

## Dependency direction

- **Domain simulation:** pure pet state, lifecycle, care, evolution, battle, dungeon, residents; no Godot UI/window dependencies.
- **Content:** packs, schemas, registry, deterministic overrides, localization, asset references.
- **Application:** commands/use cases coordinating domain services and persistence.
- **Infrastructure:** JSON loading, save repository, migrations, backups, logging.
- **Time:** injectable `SimulationClock` and offline calculation policies.
- **Progression:** feature gates, unlock grants, farm jobs, economy facts.
- **Presentation:** Minimal/Small/Expanded views over shared application state.
- **Platform:** desktop-window adapter; shared Godot-native mechanics and OS-specific adapters isolated from domain/UI intent.
- **Art source/generated assets:** source outside `res://`; game-ready output inside a controlled generated root.

Conceptual boundaries include `ContentPackRegistry`, `ContentValidator`, `SimulationClock`, `OfflineProgressService`, `PetLifecycleService`, `CareService`, `EvolutionResolver`, `BattleService`, `DungeonService`, `FeatureGateService`, `FarmJobService`, `SaveRepository`, `SaveMigrationService`, `WindowModeController`, and desktop adapters.

Prompt 1 implements only the platform/presentation spike boundary: `WindowModeController`, platform-neutral `DesktopWindowAdapter`, shared `GodotNativeWindowAdapter`, thin host adapters, placement sanitation, and spike-owned persistence/diagnostics. It does not define gameplay or production saves.

Milestone 3 adds the first gameplay path without changing the dependency direction:

- `PetSimulation` is pure state transition logic. It receives explicit seconds, timestamps, commands, resolved content data, and persisted random state; it does not read nodes, input, OS time, or window state.
- `PetApplication` is the use-case boundary. It composes the foundation, resolves the starter pool and content records, applies `OfflineProgressPolicy`, persists one active pet, exposes commands, and builds presentation view models.
- `PetGame` owns only controls and routing. Minimal, Small, and Expanded are projections of the same application state; no mode owns separate care truth.
- Pet saves retain `required_content_ids` in addition to `definition_id` and `required_pack_id`. `ContentBindingReconciler` quarantines the complete raw record if any binding is unavailable.
- Care values use integer basis points and profile-defined rates/thresholds. The simulation records bounded event history and aggregates instead of depending on frame frequency.

Milestone 2 implements the platform-neutral foundation:

- `ContentPackRegistry` validates schemas, localization, cross-references, declared asset roots, and untrusted payloads before resolving injected bundled/external/fixture roots into immutable dictionary records and a deterministic snapshot.
- `SimulationClock`, `SystemSimulationClock`, `FakeSimulationClock`, and `OfflineProgressPolicy` isolate wall and monotonic time.
- `SaveRepository`, `SaveMigrationRegistry`, `SaveEnvelope`, and `ContentBindingReconciler` own local persistence, recovery, migrations, and quarantine. `FoundationBootstrap` compares loaded and active content snapshots and persists reconciliation metadata only from a valid primary; recovered sources require an explicit save.
- `ProgressionFacts`, `FeatureGateEvaluator`, `FeatureGateService`, and `UnlockLedger` own declarative gates and idempotent grants.
- `FoundationBootstrap` composes configuration → content → snapshot → clock → saves/migrations → gates. Dependencies are injected; it has no presentation, platform, or window-topology reference.

Commands produce explicit results/events. Identical state, content versions, timestamps, and seeds should produce identical domain outcomes. Rendering and frame timing never define balance. Content registry resolution completes before saves bind IDs; missing definitions produce recoverable quarantine, not deletion.

See ADRs for engine, presentation, content-pack, mod, asset, progression, resident, versioning, and source-boundary decisions.
