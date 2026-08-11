# ADR 0004: Initial Mods Are Data and Assets Only

**Status:** Accepted — 2026-08-11

## Context

Extensibility is required, but executable mods materially expand security, support, and save-integrity risks.

## Decision

Initial packs contain validated JSON and allowlisted safe media only. Reject GDScript, DLLs, native libraries, and executable payloads.

## Consequences

Systems need expressive declarative definitions. Validation, limits, normalized paths, deterministic loading, and actionable diagnostics are mandatory.

## Rejected alternatives

Arbitrary scripts/native plugins: unacceptable initial trust boundary. No modding until later: would bake official-only assumptions into the core.

## Revisit triggers

An explicit use case impossible declaratively plus a separately accepted sandbox/threat-model ADR.
