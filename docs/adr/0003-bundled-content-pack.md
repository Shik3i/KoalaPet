# ADR 0003: Bundled Content Is a Versioned Pack

**Status:** Accepted — 2026-08-11

## Context

Modding cannot be reliable if official content bypasses its contracts.

## Decision

Load bundled original content through the same versioned registry, schemas, ID rules, reference resolution, and validation as external packs.

## Consequences

Base content catches real extension defects and can be disabled by total conversions. Boot depends on registry validation and explicit override semantics.

## Rejected alternatives

Hardcoded official roster: duplicate paths and retrofit risk. Editor-only Godot Resources: blocks tool-independent mod authoring.

## Revisit triggers

Performance evidence may justify generated caches, but JSON remains canonical authoring.
