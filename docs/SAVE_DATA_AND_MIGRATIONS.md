# Save Data and Migrations

## Implemented envelope v3

The v3 envelope records `save_format_version`, UTC creation/update timestamps, the deterministic content snapshot, pet `simulation_state.records`, progression facts, feature-gate unlock ledger, complete quarantined records, migration history, and recovery metadata. Pet records now carry stage/evolution evidence and history, pending/discovered routes, battle/level/experience state, active battle sessions, injury state, inventory/reward grants, active dungeon runs, dungeon/boss flags, and codex records.

## Safety invariants

- Write a temporary file, flush it, parse-validate it, preserve the previous valid primary as `.bak`, rotate the primary through recoverable `.swap`, then publish by rename.
- Load a valid primary first, then `.bak`, then `.swap`. Recovery source and primary failure are explicit; recovery does not silently overwrite the malformed primary.
- Never mutate the only copy in place.
- Migrations are ordered, versioned, deterministic, idempotence-tested where practical, and preserve unknown/raw fields needed for recovery.
- Corruption recovery presents explicit choices and never silently replaces a newer save with an older one.
- Clock rollback and implausible elapsed time use documented caps and diagnostics.
- Bootstrap compares the persisted content snapshot with the active registry snapshot. A mismatch remains explicit in recovery metadata and is not silently adopted.
- Migration and missing-content reconciliation changes are persisted only when the source was the valid primary. Backup/swap recovery reports `save_persistence_required` and waits for an explicit `save_current()` call.

If required content is missing, retain the complete raw instance in a quarantine/missing-content state. The pet remains visible as unavailable/recoverable, not deleted or coerced into another form. Restoring the pack or choosing an explicit migration can recover it. Pack removal never silently overwrites saves.

`foundation.v1_to_v2` is the first real migration fixture. It adds gate/quarantine/recovery fields while preserving unknown raw values. Migration registration is sequential and current-version re-evaluation is idempotent.

`milestone4.pet_adventure_state` migrates v2 pet records to v3 by adding adventure defaults, stage timestamps, evolution/discovery fields, battle/injury/inventory fields, dungeon/codex fields, and the bounded summaries needed by the new domain services. The fixture `game/tests/fixtures/saves/save_v2_milestone3.json` is based on an existing Milestone 3 record. The migration preserves instance identity, nickname, care history, unknown fields, and deterministic random state; repeated migration is idempotent.

`ContentBindingReconciler` binds records by `definition_id`, `required_pack_id`, and optional `required_content_ids`. The vertical-slice pet records the egg, form, family, animation profile, care profile, and later ailment/item IDs it requires. Missing requirements move the entire raw record into quarantine and prevent activation. Re-enabling the pack restores the exact record deterministically.

`FoundationBootstrap.save_current()` is the explicit acknowledgement boundary for a recovered or content-mismatched save. It updates the persisted content snapshot to the active snapshot only at that boundary.
