# Architecture

## Dependency direction

- **Domain simulation:** pure pet state, lifecycle, care, evolution, battle, dungeon, residents; no Godot UI/window dependencies.
- **Content:** packs, schemas, registry, deterministic overrides, localization, asset references.
- **Application:** commands/use cases coordinating domain services and persistence.
- **Infrastructure:** JSON loading, save repository, migrations, backups, logging.
- **Time:** injectable `SimulationClock` and offline calculation policies.
- **Progression:** feature gates, unlock grants, farm jobs, economy facts.
- **Presentation:** Minimal/Small/Expanded views over shared application state.
- **Platform:** desktop-window adapter; Windows implementation isolated from domain/UI intent.
- **Art source/generated assets:** source outside `res://`; game-ready output inside a controlled generated root.

Conceptual boundaries include `ContentPackRegistry`, `ContentValidator`, `SimulationClock`, `OfflineProgressService`, `PetLifecycleService`, `CareService`, `EvolutionResolver`, `BattleService`, `DungeonService`, `FeatureGateService`, `FarmJobService`, `SaveRepository`, `SaveMigrationService`, `WindowModeController`, and a Windows desktop adapter.

Prompt 1 implements only the platform/presentation spike boundary: `WindowModeController`, `DesktopWindowAdapter`, `WindowsDesktopWindowAdapter`, capability/result/monitor/placement value objects, `OverlayPlacementSanitizer`, and bounded hit-region logic. `OverlayPlacementStore`, `WindowsOverlaySpike`, diagnostics, and its code-drawn placeholder remain spike-owned. They do not define gameplay or the production save format. Unsupported host/platform operations return explicit results instead of silently succeeding.

Commands produce explicit results/events. Identical state, content versions, timestamps, and seeds should produce identical domain outcomes. Rendering and frame timing never define balance. Content registry resolution completes before saves bind IDs; missing definitions produce recoverable quarantine, not deletion.

See ADRs for engine, presentation, content-pack, mod, asset, progression, resident, versioning, and source-boundary decisions.
