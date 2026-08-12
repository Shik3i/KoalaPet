# ADR 0014: Single-Pet Deterministic Simulation

## Status

Accepted for Milestone 3. Balance values remain provisional content.

## Context

The first playable slice needs hatching, care, sleep, waste, illness, treatment, training, and offline progression without tying outcomes to frame timing or a presentation mode.

## Decision

`PetSimulation` is a pure `RefCounted` state-transition boundary. Commands, accepted elapsed seconds, observed UTC timestamps, resolved content data, and persisted random state are explicit inputs. Care values use integer basis points. Profiles own rates, thresholds, durations, and caps. The simulation records bounded event history and aggregate counters in the pet record.

`PetApplication` is the only slice coordinator allowed to combine the simulation with the content registry, `OfflineProgressPolicy`, and `SaveRepository`. Minimal, Small, and Expanded consume projections of the same state.

## Consequences

- Headless tests can reproduce the same result with a fake clock and fixed seed.
- Future balance changes stay in versioned content rather than presentation code.
- New lifecycle systems must preserve the explicit state/version/migration contract.
- The current numbers are development tuning, not a final product balance commitment.
