# ADR 0008: Versioned Content, IDs, Saves, and Migrations

**Status:** Accepted — 2026-08-11

## Context

Long-lived pets and external packs make identity and compatibility changes unavoidable.

## Decision

Version content APIs and save envelopes from the beginning; use namespaced stable content IDs and stable pet instance IDs; run ordered migrations; quarantine missing-content instances without data loss.

## Consequences

Visible names never identify data. Saves record pack requirements and histories. Atomic writes, backups, recovery, migration fixtures, and explicit override/version policy are mandatory.

## Rejected alternatives

Version later: incompatible installed saves/mods. Name-based IDs: localization/rename breakage. Delete missing objects: unacceptable loss.

## Revisit triggers

Version formats evolve through new migrations or superseding ADRs, not removal of the invariant.
