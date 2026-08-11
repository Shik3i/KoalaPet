# Feature Gates and Onboarding

Feature gates are versioned content definitions evaluated from stable progression facts. UI queries gate state; it does not invent unlock rules. Gates can be hidden, hinted, available, or completed, with product-specific rules controlling presentation.

Milestone 2 implements read-only `ProgressionFacts`, recursive `all`/`any`/`not` conditions, boolean/equality/inequality and numeric min/max comparisons, collection membership, explicit failed-condition paths, and deterministic repeated evaluation. Gate IDs, feature IDs, and reward IDs are namespaced.

`UnlockLedger` grants each reward ID at most once and records its originating gate. Re-evaluating a passing gate is safe and returns `ALREADY_GRANTED` rather than duplicating effects. Definition changes cannot remove a consumed ledger grant. No onboarding UI or farm reveal is implemented.

Intended phases:

1. Egg and single-pet V-pet: care, training, sleep, waste, illness, medicine, battles, first evolutions.
2. Adventure: first dungeon, items, training depth, background/theme rewards, limited shop/customization.
3. First mature pet: settled-ready eligibility and second-egg path.
4. Farm/sanctuary reveal: only with purpose; exact composite condition is tunable.
5. Idle collection: prior pets live and work safely while one remains active.

Before reveal, the farm and other large systems are absent from normal UI—not prominent disabled controls. Onboarding teaches the current loop in context, preserves discovery, and never depends on fixed starter count. Migration must handle changed gate definitions without relocking consumed rewards or duplicating grants.
