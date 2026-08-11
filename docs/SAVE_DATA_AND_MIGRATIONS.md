# Save Data and Migrations

## Envelope

A save envelope will record save schema version; game build and content API version; required pack IDs/versions; stable pet instance IDs; namespaced content IDs; pet/evolution history; active/resident state; timestamps; feature gates; inventory; unlocks; and migration metadata.

## Safety invariants

- Write a new file, flush where supported, validate/read it, then atomically replace the primary save.
- Keep rotating known-good backups and a last-migration backup.
- Never mutate the only copy in place.
- Migrations are ordered, versioned, deterministic, idempotence-tested where practical, and preserve unknown/raw fields needed for recovery.
- Corruption recovery presents explicit choices and never silently replaces a newer save with an older one.
- Clock rollback and implausible elapsed time use documented caps and diagnostics.

If required content is missing, retain the complete raw instance in a quarantine/missing-content state. The pet remains visible as unavailable/recoverable, not deleted or coerced into another form. Restoring the pack or choosing an explicit migration can recover it. Pack removal never silently overwrites saves.
