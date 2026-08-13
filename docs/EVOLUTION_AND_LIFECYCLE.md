# Evolution and Lifecycle

Evolution is a declarative graph of form IDs and prioritized rules, not hardcoded branches. Candidate predicates may inspect stage time, care mistakes, training totals, weight/overfeeding, mood/discipline/energy/health history, sleep disruption, sickness/injury, battle count, win ratio, experience/level, defeated enemies, dungeon/boss flags, used/held items, traits, achievements, habitat affinity, and lineage.

Resolution must be deterministic for identical state, content versions, and declared random seed. Rule priority and tie-breaking are explicit. Validation rejects missing targets, impossible graph references, ambiguous duplicate priorities where prohibited, and malformed predicates. Save history records source form, target form, rule ID, timestamp, and relevant evidence for debugging/migration.

Good-care and high-care-mistake paths are both first-class. Poor-care forms may offer unique stats, abilities, jobs, affinities, codex records, rewards, redemption branches, or deliberate challenge routes; they are not automatic trash states.

## Milestone 4 runtime

`EvolutionResolver` evaluates the current family graph from persisted pet state. The bundled slice has six rules: good-care and rough-care branches for moss, ember, and tide. Rules carry priority, declarative predicates, and a minimum stage age; equal priorities use lexical rule ID order. Current evidence includes stage time, active/offline time, care mistakes, resolved calls, training, care values, sickness/treatment, battle history, experience/level, defeated encounters, dungeon flags, used items, and traits.

The resolver returns candidate/rejected diagnostics and persists the selected rule, source/target forms, timestamp, evidence snapshot, content fingerprint, priority, and tie-break. Application is atomic: instance ID, nickname, origin, care state, aggregates, history, and random state remain intact while form, stage, traits, animation/profile bindings, and required content bindings update. A transition is applied once only.

If the pet is sleeping, sick, injured, in a battle, or in an unresolved dungeon encounter, the eligible result is persisted as `pending_evolution` and applied at the next safe point. Missing targets fail explicitly and preserve the record for recovery. The normal UI shows discovered forms/routes; undiscovered content is intended to use a silhouette and broad hints. Exact evidence remains a development diagnostic. This disclosure policy and the presentation effect are provisional.

Lifecycle profiles preserve room for different death/retirement/rebirth/legacy policies. The endpoint is open. Do not implement irreversible pet deletion as a default. Settled-ready eligibility is separate from evolution and prevents newborn storage from bypassing care.
