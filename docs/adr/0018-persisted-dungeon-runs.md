# ADR 0018: Persisted Dungeon Runs

- Status: Accepted
- Date: 2026-08-13

## Context

The first dungeon must be reusable content, survive application close, and grant a first-clear reward exactly once without adding offline adventure simulation.

## Decision

`DungeonService` persists a run ID, dungeon ID, seed/random state, current/completed nodes, choices, transient HP, encountered enemies, rewards, and result. Nodes resolve from data and can start a battle with dungeon/node context. A five-node bundled dungeon demonstrates encounter, event, encounter, rest, and boss. Failure returns safely. First-clear state uses dungeon flags and an explicit reward-grant ledger; repeat clears use repeat rewards.

## Consequences

Completed nodes cannot reroll on reload, stale battle results cannot advance the wrong node, and first-clear rewards are idempotent. Habitat editing consumes the stored unlock only in a later milestone.
