# Prompt 4.5 visual-rebuild generation briefs

All generated outputs are original provisional production candidates. The three `references/ui-modes/` images are descriptive direction only and must not be provided to the generator, traced, cropped, or shipped. Shared implementation rules come from `docs/ART_STYLE_BIBLE.md`.

## Shared generation contract

- Use case: `stylized-concept`.
- Medium: polished modern pixel art deliberately authored on a visible pixel grid; compact desktop V-pet game asset; not flat vector art and not retro 8-bit.
- Palette: ink navy, deep slate, warm parchment, family accent ramp, soft upper-left light, lower-right shadow.
- Background for cutouts: perfectly flat solid `#FF00FF`; no shadow, gradient, texture, floor, reflection, text, watermark, border, labels, dividers, or key color inside the subject.
- Character cell source: exact evenly spaced `4×4` grid, each cell isolated and centered, generous padding, no overlap. Output processing maps cells to `128×128 px` canonical frames and derives previews/portraits/sheets deterministically.
- Originality: no known monster-franchise anatomy, names, marks, accessories, interface, or imitation. No koala mascot copy from the supplied concepts.

## Hatchling sheet cell order

`idle`, `walk`, `eat`, `happy`, `sleep`, `sick`, `injured`, `training`, `attack`, `hit`, `victory`, `call`, `idle_alt`, `walk_alt`, `happy_alt`, `care_alt`.

- Mosskin: small low woodland companion; broad leaf mantle, seed-pod ears, rootlike feet, cream muzzle; curious and gentle; no fire/wings.
- Emberling: upright compact hearth companion; curled coal tail with warm ember tip, swept ceramic ear plates, cream chest; energetic but not canine/feline imitation.
- Tidewing: buoyant shore companion; manta-like side fins, water-drop crest, short webbed feet, pale glass belly; distinct from Moss/Ember silhouette.

## Juvenile sheet cell order

Same 16 cells as hatchlings. Each branch visibly descends from its hatchling.

- Mossbloom: good-care Moss; open flower mantle, balanced antler-leaves, light nimble posture.
- Brackenhorn: rough-care Moss; heavier fern armor, asymmetric root horn, grounded wild posture, still expressive and appealing.
- Dawn Spark: good-care Ember; radiant swept flame plumage, clean ceramic plates, alert dancer posture.
- Cinder Core: rough-care Ember; dense soot-stone shell, irregular ember seams, powerful low stance, intentionally designed rather than broken.
- Glasscurrent: good-care Tide; translucent-looking layered fins represented with opaque pixel ramps, smooth crest, poised gliding posture.
- Reedwatch: rough-care Tide; reed-fringed heavy fins, uneven marsh growth, watchful low stance, still capable and charming.

## Egg sheets

Exact `2×2` grid: `idle_a`, `idle_b`, `hatch_crack`, `hatch_open`; centered, isolated, no overlap.

- Mossseed Egg: layered seed silhouette with leaf seam and tiny root-foot base.
- Emberwake Egg: kiln-clay shell with raised ember plates and controlled glowing cracks.
- Tideglass Egg: asymmetric droplet shell with shell ridges and opaque glass-like highlights.

## Enemy sheets

Exact `2×3` grid: `idle_a`, `idle_b`, `attack`, `hit`, `defeat`, `codex`; centered, isolated, no overlap.

- Creekling: swift stream-runner with pebble shell and ribbon-water tail; not a companion recolor.
- Thornlet: compact undergrowth sentinel with bramble wheel legs and seed shield.
- Cinder Moth: broad geometric moth silhouette, coal body, amber dust wings; readable airborne pose.
- Canopy Guardian: first boss; ancient bark-and-stone quadruped with layered canopy crown and gold seed core; clearly larger visual mass.

## Habitat sources

1. Empty room: `512×192` side-on shallow three-quarter woodland atelier, moss-stone back wall, timber floor edge, empty central movement lane, upper-left warm light, no creature, no UI, no furniture, no text.
2. Rear structures atlas on flat key: exact `4×2` grid with sleeping den, bath basin, feed table/bowl, training log, plant cluster, trophy shelf, lantern, storage chest. Each object isolated with matching floor line.
3. Foreground/lighting atlas on flat key: exact `4×2` grid with grass edge, flower cluster, hanging leaves, warm light pool, cool night wash, dust motes, small heart effect, urgent call bubble. Each isolated and independently composable.

## UI icon atlas

Exact `6×4` grid on flat key. Cells in order: satiety, mood, energy, hygiene, sleep, health, feed, treat, clean, train, medicine, injury treatment, battle, dungeon, rewards, expand, back/minimal, settings, inventory, codex, evolution, aggressive, balanced, defensive. Tactile 24-pixel-style pictograms with two-pixel dark outline, no text, no logos, no duplicate silhouettes.

## Processing and review

Built-in image generation first. Original outputs stay in ignored `art_source/generated/visual-rebuild/`. `tools/art_pipeline/process_visual_rebuild_assets.py` removes the uniform key, crops fixed cells, normalizes bounds/canvases, performs nearest-neighbor pixel-grid reduction and palette normalization, packs deterministic sheets, emits contact sheets, and writes a provenance manifest with hashes. Runtime output replaces only referenced files under `game/content_packs/koalapet.base/assets/vertical_slice/` and adds `game/assets_generated/ui/` plus `game/assets_generated/habitat/`.

Review rejects: missing/merged grid cells, inconsistent identity, key-color contamination, unintended text, nontransparent corners, clipped silhouettes, black fringe, generic blobs, palette-only family variants, reference imitation, or unreadable `64×64` previews.
