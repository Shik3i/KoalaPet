# ADR 0013: Save Envelope, Backup, Migration, and Quarantine

**Status:** Accepted — 2026-08-12

## Context

Long-lived records must survive format changes, interrupted writes, malformed files, and removed content packs without silent substitution or loss.

## Decision

Use save envelope version `2` with UTC creation/update timestamps, resolved content snapshot, neutral simulation records, progression facts, gate ledger, quarantined records, migration history, and recovery metadata.

Writes serialize to a temporary file, flush and parse-validate it, preserve the previous valid primary as `.bak`, rotate the current primary through a recoverable `.swap`, and publish the temporary file by rename. Loads prefer a valid primary, then backup, then swap, and report the recovery source. Both-invalid is an explicit failure and never overwrites either file.

Migrations are registered sequentially and run on a deep copy. The real `foundation.v1_to_v2` fixture preserves unknown fields. Missing-content reconciliation moves the complete raw record into quarantine, prevents activation, records missing IDs/packs, and restores the exact record only when requirements resolve again.

## Consequences

No unresolved record is coerced into unrelated content or deleted. A recovered backup is returned with explicit metadata but does not silently replace the malformed primary. Save services depend on injected clocks and resolved content, not presentation or platform windows.

## Rejected alternatives

In-place mutation: corruption risk. Name-based binding: rename/localization loss. Delete or substitute missing records: unacceptable data loss. Skip-version migrations: nondeterministic evolution.

## Revisit triggers

Save format `3`, rotating backup-count policy, encrypted saves, or platform evidence requiring a stronger native replace primitive.
