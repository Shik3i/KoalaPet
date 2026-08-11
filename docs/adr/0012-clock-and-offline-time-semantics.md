# ADR 0012: Clock and Offline-Time Semantics

**Status:** Accepted — 2026-08-12

## Context

Simulation outcomes must not depend on frame rate, local timezone, or uncontrolled system-time reads. Offline elapsed time may contain rollback, drift, or implausible jumps.

## Decision

Inject a `SimulationClock`. Persist UTC timestamps with `T…Z`; use monotonic process time for in-session elapsed measurement. Production uses `SystemSimulationClock`; tests use `FakeSimulationClock`.

`OfflineProgressPolicy` returns raw observed seconds, accepted simulation seconds, anomaly state, and an explicit reason. Negative drift within tolerance accepts zero. Larger rollback also accepts zero. Forward jumps are reported. Durations above the configured cap are clamped. Missing or invalid timestamps are rejected with zero accepted time.

## Consequences

Clock rollback never punishes the player and cannot wrap into a positive duration. Local timezone is not a simulation input. This policy computes elapsed time only; no care or gameplay decay exists in Milestone 2.

## Rejected alternatives

Direct system-time reads throughout services: untestable. Frame delta for offline time: unavailable after exit. Absolute value of negative elapsed time: destructive rollback behavior.

## Revisit triggers

Platform evidence that monotonic time is unavailable where needed, or product decisions changing offline caps and anomaly presentation.
