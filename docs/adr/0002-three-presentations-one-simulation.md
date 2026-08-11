# ADR 0002: Three Presentations over One Simulation

**Status:** Accepted — 2026-08-11

## Context

The pet must be unobtrusive all day yet expose care and management when requested.

## Decision

Minimal, Small, and Expanded are presentation states over one authoritative application/domain state. Mode transitions never duplicate or reset simulation.

## Consequences

Views cannot own pet truth. Commands, persistence, time, and events are shared. Window mechanics require platform adapters and transition tests.

## Rejected alternatives

Independent mini/full games: synchronization and save divergence. Permanent full-screen manager: contradicts desktop-companion intent.

## Revisit triggers

Only evidence that a platform cannot host the presentations without breaking shared-state guarantees.
