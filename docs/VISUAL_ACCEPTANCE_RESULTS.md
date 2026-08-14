# Visual Acceptance Results

**Review date:** 2026-08-14

**Scope:** existing Milestone-4 presentation only; Milestone 5 remains unstarted.

## Result

The deterministic audit covers `290` runtime sequences across three eggs, nine playable forms, three normal enemies and one boss. Classification is `281 ACCEPTED_PROVISIONAL` and `9 NOT_PLAYER_FACING`; there are no remaining `NEEDS_REGENERATION` or `TECHNICALLY_BROKEN` rows. The nine excluded rows are legacy `sleep` aliases; the player-facing transition is `sleep_enter` followed by `sleep_loop`.

The art is visually coherent enough for product-owner review, not final production acceptance. Anatomy, material accents and family silhouettes are stable in the reviewed sheets. Movement remains intentionally compact. Runtime paths, markers, bounds and no-fallback behavior are machine-checked.

## Corrections

- Regenerated `63` player-facing sequences: `call`, `clean`, `idle_rest`, `medicine`, `sleep_enter`, `treatment` and `wake` for all nine playable forms.
- Removed helper-hand contamination, neighboring-cell fragments and seam bleed from deterministic source-pose extraction.
- Preserved ground/pivot alignment while replacing the contaminated care and sleep poses.
- Corrected `world` marker indexes for the three two-frame egg profiles.
- Included loop override in the playback descriptor cache key, preventing an unchanged view refresh from incorrectly restarting or retaining a prior loop mode.
- Added marker range and ordering validation plus exhaustive runtime completion/refresh/Reduced-Motion tests.

## Review method

Every form has a contact sheet with representative frames for all 29 IDs. Separate sheets cover enemies/boss, VFX and rejected-versus-regenerated examples. Four concise cross-system reels cover enemy/boss combat, sleep/care, Minimal motion and Reduced Motion. Direct Windows review verified the debug-only Showroom, starter selection, focus visibility, Alt+Tab stability and minimize/restore.

Machine-readable detail: [`evidence/visual-acceptance/animation-classifications.json`](evidence/visual-acceptance/animation-classifications.json). Product-owner index: [`evidence/visual-acceptance/README.md`](evidence/visual-acceptance/README.md).

## Acceptance boundary

Milestone 5 is not recommended yet. Required decisions remain final product-owner visual approval and an asset-rights/license decision. Screen-reader exposure, the full native 100–200% Windows DPI matrix, tray lifecycle and controlled mixed-DPI movement remain incomplete.

## Asset/runtime measurement

Prompt-4.7 baseline and Prompt-4.8 after-state both contain `388` runtime PNGs and an estimated `129,624,064` decoded RGBA bytes if everything were loaded simultaneously. Disk size changed from `26,030,472` to `26,150,137` bytes (`+119,665`) because the corrected frames contain more alpha/color detail. Twelve exact duplicate groups are intentional compatibility aliases; eight unreferenced enemy reserve images have explicit retention reasons. No evidence/reference image is referenced by runtime content. Atlas/path migration is deferred until release-art approval to preserve stable content and mod contracts.
