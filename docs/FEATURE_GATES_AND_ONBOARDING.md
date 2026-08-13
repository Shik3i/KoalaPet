# Feature Gates and Onboarding

Feature gates are versioned content definitions evaluated from stable progression facts. UI queries gate state; it does not invent unlock rules. Gates can be hidden, hinted, available, or completed, with product-specific rules controlling presentation.

Milestone 2 implements read-only `ProgressionFacts`, recursive `all`/`any`/`not` conditions, boolean/equality/inequality and numeric min/max comparisons, collection membership, explicit failed-condition paths, and deterministic repeated evaluation. Gate IDs, feature IDs, and reward IDs are namespaced. Invalid conditions fail closed; malformed operands cannot pass through `not` or `any`.

`UnlockLedger` grants each reward ID at most once and records its originating gate. Re-evaluating a passing gate is safe and returns `ALREADY_GRANTED` rather than duplicating effects. Definition changes cannot remove a consumed ledger grant. Milestone 4 gates Battle after hatching, Dungeon after battle history, the first dungeon clear, the future canopy theme, and the boss memory flag. The theme/trophy unlock is stored but has no habitat editor consumer yet. No farm reveal is implemented.

Intended phases:

1. Egg and single-pet V-pet: care, training, sleep, waste, illness, medicine, branching evolution.
2. Adventure: normal battles, injuries/recovery, first dungeon, items, background/theme/trophy rewards.
3. First mature pet: settled-ready eligibility and second-egg path.
4. Farm/sanctuary reveal: only with purpose; exact composite condition is tunable.
5. Idle collection: prior pets live and work safely while one remains active.

Before reveal, the farm and other large systems are absent from normal UI—not prominent disabled controls. Onboarding teaches the current loop in context, preserves discovery, and never depends on fixed starter count. Migration must handle changed gate definitions without relocking consumed rewards or duplicating grants.
