# ADR 0019: Idempotent Inventory and Reward Grants

- Status: Accepted
- Date: 2026-08-13

## Context

Battles and dungeons need minimal inventory support without currency, essential-care scarcity, or duplicated unique unlocks after retries or reloads.

## Decision

Battle sessions own an applied reward state; repeatable encounter drops add deterministic stack quantities. Dungeon first-clear rewards write a stable `dungeon:first_clear:<dungeon_id>` grant into `reward_grants` atomically with dungeon flags and unlocks. Unique items are data-marked and first-clear rewards are separated from repeat rewards. Baseline food, cleaning, medicine, and injury treatment remain available without inventory stock.

## Consequences

A replay, stale result, or save/reload cannot duplicate a first-clear grant. Inventory and unlock records remain namespaced and recoverable through the existing content-binding/quarantine path.
