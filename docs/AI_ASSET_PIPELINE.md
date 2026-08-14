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

## Milestone 4 provisional batch

`tools/art_pipeline/generate_milestone_four_assets.py` deterministically creates the six juvenile silhouettes/animations, three normal enemies, one boss, dungeon background/ground/node icons, battle/evolution/status/reward visuals, and trophy/icon assets under the bundled pack boundary. `tools/art_pipeline/validate_vertical_slice_assets.py` checks all 109 referenced PNGs for readable RGBA data and a minimum 48×48 size. These are development-only provisional assets; no production art-rights or final visual approval is claimed.

## Prompt 4.5 visual-rebuild batch

- Source: `art_source/sources/visual-rebuild/` (`19` preserved PNG source boards).
- Brief: [`../art_source/prompts/visual-rebuild-assets.md`](../art_source/prompts/visual-rebuild-assets.md).
- Processor: `python tools/art_pipeline/process_visual_rebuild_assets.py`.
- Outputs: content-pack character/egg/enemy sheets plus `game/assets_generated/habitat/quiet_canopy/`, `game/assets_generated/ui/icons/`, manifest and contact sheets.
- Deterministic transforms: alpha/key cleanup, fixed cell extraction, crop/contain, nearest-neighbor resize, frame packing, preview/portrait derivation, manifest/provenance hashing and contact-sheet composition.
- Provenance: [`../art_source/provenance/visual-rebuild.json`](../art_source/provenance/visual-rebuild.json).
- Generation capability: Codex built-in image generation was available and used. The concrete model version was not exposed, so the record states that limitation rather than guessing.
- Approval boundary: `PROVISIONAL_PRODUCT_REVIEW`; `license_status=UNDECIDED`. Do not mark the batch final or licensed without a product-owner/legal decision.
- Rejected intermediate generations remain under ignored `art_source/generated/` and are not runtime or committed evidence.

## Prompt 4.6 animation-polish batch

- Three preserved transparent family atlases under `art_source/sources/animation-polish/` add eight chronological walk poses for all three hatchlings and six Juvenile forms.
- Brief: [`../art_source/prompts/animation-polish-walk-cycles.md`](../art_source/prompts/animation-polish-walk-cycles.md). Codex built-in image generation was used; its exact model/version was not exposed.
- The shared processor crops the 8×3 atlases, removes isolated alpha components, normalizes frames to `128×128`, fixes pivot/ground at `(64,116)`, packs eight-frame sheets and emits nine GIFs plus a contact sheet.
- The validator now rejects bundled playable walk profiles below six frames, missing geometry metadata, opaque corners, off-canvas bounds, unstable ground anchors, isolated alpha debris and missing previews.
- Content API `0.1` remains compatible: extra animation metadata is optional for external packs and mandatory only for the bundled official content gate.
- Rights remain `UNDECIDED`; product status remains `PROVISIONAL_PRODUCT_REVIEW`.

## Prompt 4.7 living-animation batch

- Brief: [`../art_source/prompts/living-animation-expansion.md`](../art_source/prompts/living-animation-expansion.md).
- Preserved sources: accepted Prompt-4.5 creature/enemy boards, Prompt-4.6 walk atlases and `art_source/sources/living-animation/family-effects.png`.
- VFX generation: Codex built-in image generation; concrete model/version not exposed. The source board contained a neutral checker field, removed only by deterministic border-connected neutral cleanup.
- Processor: `python tools/art_pipeline/process_living_animation_assets.py`. It preserves identity/ground geometry, derives chronological overlap motion, packs `4–8` frames, writes optional marker metadata, VFX profiles, family/encounter profiles, contact sheets and GIF reels.
- Output contract: 29 animations for each of nine playable forms, five battle/reaction animations for each current enemy, and twelve separate Moss/Ember/Tide effects.
- Validator: complete profile coverage, minimum frame counts, sheet geometry, alpha, frame uniqueness, marker bounds, VFX/evidence existence and transparent corners.
- Provenance: [`../art_source/provenance/living-animation.json`](../art_source/provenance/living-animation.json).
- Approval boundary remains `PROVISIONAL_PRODUCT_REVIEW`; `license_status=UNDECIDED`.
