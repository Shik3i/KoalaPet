# ADR 0015: Pet Content Binding and Quarantine

## Status

Accepted for Milestone 3.

## Context

A pet depends on more than its current form. Removing an egg, family, animation, care profile, item, or ailment pack must not silently substitute content or delete the pet.

## Decision

Each pet record stores `definition_id`, `required_pack_id`, and a stable `required_content_ids` list. `ContentBindingReconciler` validates every binding before activation. Any missing binding moves the complete raw record to `quarantined_records`; restoring the content can restore that exact record.

## Consequences

- Content removal is explicit and recoverable.
- The save record carries enough identity for future migrations to reason about dependencies.
- The registry remains the authority for content ownership and availability.
