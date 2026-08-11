# ADR 0005: AI-First Layered Art without a Generic Tileset

**Status:** Accepted — 2026-08-11

## Context

The target is polished compact pixel art, and production must not depend on manual user art labor.

## Decision

Use AI-generated source plus deterministic processing for layered backgrounds, ground, props, stations, effects, and transparent creatures. A generic RPG tileset is not required.

## Consequences

Prompts/provenance, reproducible transforms, dimension/alpha/frame validators, contact sheets, runtime screenshots, and regeneration loops are first-class production assets.

## Rejected alternatives

Mandatory hand-drawn cleanup: conflicts with AI-first workflow. Generic tileset: weak fit for compact bespoke habitats.

## Revisit triggers

Measured generation consistency or runtime composition problems; individual tools remain replaceable.
