# ADR 0011: Deterministic Runtime Content Registry

**Status:** Accepted — 2026-08-12

## Context

Official content, external packs, and development fixtures need one runtime path without allowing discovery order, filename order, or undeclared collisions to change behavior.

## Decision

Discover immediate pack directories from injected roots. Validate manifests and untrusted payloads before resolution. Resolve required and present optional dependencies topologically, then numeric priority, then lexical pack ID. Load lower priority first so later explicit overrides are deterministic. Reject duplicate pack IDs, dependency cycles, active conflicts, incompatible content APIs, unsafe paths, forbidden payloads, undeclared ID collisions, and missing override targets.

`koalapet.base` uses the same registry. A `total_conversion` may explicitly disable it. A `skin` may explicitly replace presentation definitions only. Ordinary `content` packs act as replacement packs only for IDs listed in `overrides`. Content API `0.1` remains experimental.

Each resolved snapshot records ordered pack versions, API versions, content IDs, per-pack JSON/safe-media source fingerprints, and a stable aggregate fingerprint.

## Consequences

Pack roots and disabled IDs are injectable. Diagnostics expose logical source labels and JSON paths without publishing private absolute paths. Runtime records remain dictionaries instead of one wrapper class per schema. Python validation remains the authoring gate; runtime repeats trust-boundary checks needed before loading.

## Rejected alternatives

Filesystem order: nondeterministic. Last file silently wins: unsafe overrides. Separate official loader: violates ADR 0003. Executable plugins: violates ADR 0004.

## Revisit triggers

Content API `0.2`, measured registry performance requiring a generated cache, or a declarative use case not expressible by the current pack policy.
