# Animation polish walk-cycle source brief

Date: 2026-08-13

Tool: Codex built-in image generation. Exact model/version was not exposed by the tool.

Request: three original KoalaPet family atlases, one family per transparent PNG. Each atlas contains exactly three rows and eight chronological side-view locomotion poses. Rows represent the hatchling and its two juvenile branches. Frames must preserve identity, proportions, lighting, left/right foot-contact alternation, in-place motion, clean alpha, and no cast shadow or background. No third-party franchise names, assets, identifiers, links, or imitation targets.

Generated source outputs:

- `art_source/sources/animation-polish/walk-moss-family.png`
- `art_source/sources/animation-polish/walk-ember-family.png`
- `art_source/sources/animation-polish/walk-tide-family.png`

Deterministic processing: `tools/art_pipeline/process_visual_rebuild_assets.py` crops the 8x3 atlases, removes isolated alpha components, normalizes all frames to a shared 128x128 canvas, uses a fixed `(64,116)` ground/pivot anchor, packs eight-frame sheets, creates GIF previews/contact sheets, and records hashes in `art_source/provenance/visual-rebuild.json`.

Review/license status: provisional product review; final rights approval remains `UNDECIDED`. No generated source is treated as approved runtime art until processed and validated.
