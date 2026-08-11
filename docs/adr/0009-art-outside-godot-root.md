# ADR 0009: Reference and Source Art Stay outside Godot Root

**Status:** Accepted — 2026-08-11

## Context

Mockups and high-resolution/generated sources should not trigger imports or enter production bundles accidentally.

## Decision

Keep `references/`, `art_source/`, docs, and repository tools outside `game/` (`res://`). Only approved game-ready generated assets enter `game/assets_generated/`.

## Consequences

Tooling must copy/transform outputs explicitly and retain provenance. Reference concepts cannot accidentally ship through Godot import/export.

## Rejected alternatives

Everything under `res://`: import noise, package bloat, rights risk. External untracked source: poor reproducibility/provenance.

## Revisit triggers

Godot project-root layout changes, while separation of source/reference and runtime assets remains required.
