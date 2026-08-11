# Save Data and Migrations

## Implemented envelope v2

The Milestone 2 envelope records `save_format_version`, UTC creation/update timestamps, the deterministic content snapshot, neutral `simulation_state.records`, progression facts, feature-gate unlock ledger, complete quarantined records, migration history, and recovery metadata. It intentionally contains no production pet state yet.

## Safety invariants

- Write a temporary file, flush it, parse-validate it, preserve the previous valid primary as `.bak`, rotate the primary through recoverable `.swap`, then publish by rename.
- Load a valid primary first, then `.bak`, then `.swap`. Recovery source and primary failure are explicit; recovery does not silently overwrite the malformed primary.
- Never mutate the only copy in place.
- Migrations are ordered, versioned, deterministic, idempotence-tested where practical, and preserve unknown/raw fields needed for recovery.
- Corruption recovery presents explicit choices and never silently replaces a newer save with an older one.
- Clock rollback and implausible elapsed time use documented caps and diagnostics.

If required content is missing, retain the complete raw instance in a quarantine/missing-content state. The pet remains visible as unavailable/recoverable, not deleted or coerced into another form. Restoring the pack or choosing an explicit migration can recover it. Pack removal never silently overwrites saves.

`foundation.v1_to_v2` is the first real migration fixture. It adds gate/quarantine/recovery fields while preserving unknown raw values. Migration registration is sequential and current-version re-evaluation is idempotent.

`ContentBindingReconciler` currently binds neutral records by `definition_id` and `required_pack_id`. Missing requirements move the entire raw record into quarantine and prevent activation. Re-enabling the pack restores the exact record deterministically.
