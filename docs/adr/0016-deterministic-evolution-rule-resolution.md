# ADR 0016: Deterministic Evolution Rule Resolution

- Status: Accepted
- Date: 2026-08-13

## Context

Evolution must use care history without coupling behavior to a presentation mode or hardcoding starter-specific branches. Unsafe states must not lose an eligible transition.

## Decision

`EvolutionResolver` evaluates namespaced, content-defined graph rules from persisted evidence. Higher priority wins; equal priorities use lexical rule ID order. Minimum stage age is part of the rule. The resolver persists diagnostics, evidence, content fingerprint, and a pending transition when the pet is sleeping, sick, injured, in battle, or in an unresolved dungeon encounter. The application always persists resolver state, including pending state, and applies one atomic transition at a safe point.

## Consequences

Identical state, content, timestamps, and seed produce the same route. The six bundled juvenile routes are content scope, not engine limits. Exact evidence is available to development diagnostics; normal discovery disclosure remains provisional.
