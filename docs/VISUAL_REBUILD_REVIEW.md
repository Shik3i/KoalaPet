# Prompt 4.5 Visual Rebuild Review

## Result

The previous player-facing debug shell and geometric placeholder presentation are rejected and no longer used by the normal game scene. The rebuilt current Vertical Slice is visually coherent across all three modes and retains every Milestone 3/4 gameplay system through one authoritative application state.

## Accepted for the current vertical slice

- Minimal: transparent animated pet/egg, temporary status bubble, walking, pet-only hit region and click-to-Small.
- Small: compact habitat-first everyday view with readable status strip and direct care/adventure/more actions.
- Expanded: optional management view with deliberate hierarchy for status, habitat, history, battles, dungeon, rewards, inventory, codex and evolution.
- Shared dark pixel UI, warm parchment copy, moss/gold focus accents, 40×36 minimum icon controls, keyboard focus, tooltips, wrapping and reduced motion.
- Original provisional visuals for all three eggs, three hatchlings, six juveniles, three normal enemies and the boss; no visible geometric creature placeholder.
- Deterministic 512×192 habitat layering and a reproducible source-to-runtime pipeline.

## Native product evidence

[`evidence/visual-rebuild/README.md`](evidence/visual-rebuild/README.md) indexes the native screenshots, diagnostic JSON and 14-second MJPEG film. The recorded run directly confirms transparent Minimal composition, Minimal → Small → care → Expanded → Minimal, canonical mode transitions and outside-pet hit-test bypass while KoalaPet remains running.

## Review fixes found during acceptance

- repeated `complete_hatch` now succeeds idempotently instead of surfacing `Unknown pet command`
- the Windows capture resolves a replacement HWND after transparent-window reconfiguration
- review-only waste generation no longer invokes invalid dungeon/battle commands
- Inventory/Kodex cards no longer split short German item names into unreadable fragments
- `ui.inventory` now exists in DE and EN

## Remaining limits

- art and license are provisional/undecided; generated-source model version is not exposed
- screen-reader, full contrast and multi-host accessibility acceptance remain open
- native taskbar/Alt+Tab policy, tray lifecycle, all DPI/monitor transitions and release behavior remain separate platform work
- ADR 0010 remains proposed
- no Milestone 5 feature was implemented

## Gate before Milestone 5

Require product-owner visual approval, an explicit rights/license disposition for the provisional art batch, and a documented Windows 10/11 shell/DPI/accessibility pass. Until all three are accepted, do not start Milestone 5.
