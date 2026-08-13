# ADR 0017: Deterministic Battle Sessions

- Status: Accepted
- Date: 2026-08-13

## Context

Normal battles must fit a desktop V-pet, resume after save/reload, and remain reproducible without frame-dependent or global randomness.

## Decision

`BattleService` owns a bounded session containing encounter, seed/random state, round, stance, transient HP, effects, event log, result, and reward state. Content defines stats, moves, effects, encounters, drops, and balance. Aggressive, Balanced, Defensive, and Auto are the initial interaction choices. The session PRNG advances only from persisted session state; six rounds bound resolution. Experience, levels, history, drops, and injuries are written through the same application state.

## Consequences

Mid-battle save/reload is safe and identical seeds produce identical results. The stance interaction is a Milestone 4 prototype and remains open to product playtest; no action-RPG timing or paid progression is introduced.
