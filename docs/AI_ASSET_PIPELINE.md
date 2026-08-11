# AI Asset Pipeline

1. Store art briefs and prompts under `art_source/prompts/`.
2. Generate source images with an available image model.
3. Preserve original outputs outside the Godot import root.
4. Run deterministic alpha cleanup, crop, canvas normalization, nearest-neighbor scale, optional palette processing, frame alignment, sheet packing, and metadata generation.
5. Validate dimensions, alpha bounds, frame count, animation metadata, naming, and file references.
6. Produce contact sheets and animation previews.
7. Inspect in automated screenshots/video and AI review at actual presentation scale.
8. Regenerate or script-correct failures; never require manual cleanup by the product owner.

Each generated asset gets a provenance record containing asset ID, generation tool/model/version when known, UTC date, prompt or prompt-file reference, source files/checksums, deterministic transformation command/version, author/owner metadata, intended license, approval state, and target game paths. Secrets and private credentials never enter prompts or records.

Source/mockups stay outside `game/`. Approved game-ready output enters `game/assets_generated/` through reproducible tooling. Reference mockups are not production assets without explicit rights approval.
