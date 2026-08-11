# Prompt 002: Content and Simulation Foundation

**Executed:** 2026-08-12

## Durable intent

Build the platform-neutral foundation required before pet gameplay: one runtime path for official/external content, deterministic snapshots, injected time, safe offline elapsed calculation, versioned local saves/migrations/backups, lossless missing-content quarantine, declarative gates, and an injectable bootstrap.

Pending interactive Windows validation remains required for overlay architecture acceptance but does not block these services. ADR 0010 stays proposed; no overlay topology is assumed.

## Result

- Runtime Content API `0.1` registry with deterministic relationship/override policy, localization, untrusted-path/payload checks, logical diagnostics, and SHA-256 snapshot fingerprints.
- System/fake clocks and explicit rollback/drift/jump/cap results.
- Save envelope v2, validated temporary replacement, previous-valid backup, recovery fallback, sequential v1→v2 migration, and lossless quarantine/restoration.
- Recursive feature gates, read-only facts, explanations, unlock ledger, and idempotent grants.
- Platform-neutral bootstrap and deterministic Godot headless foundation suite.

No pet care, starter, hatching, battle, dungeon, farm, production UI/art, or native-window repair was implemented.
