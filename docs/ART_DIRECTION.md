# Art Direction

Target: cozy, polished, detailed pixel art with modern readable compact UI—not a generic low-detail RPG asset pack. Concept images establish mood, relative desktop footprint, creature charm, habitat density, dark compact panels, and the relationship among modes; they are not pixel-perfect UI specifications.

- Expanded is optional management, not a permanent desktop takeover.
- Small is the intended default compact habitat.
- Minimal is true zero-background, pet-only presentation.
- Usability, accessibility, consistent scale, technical feasibility, and original production assets override artifacts or text in mockups.

Asset families: full/layered habitat backgrounds, ground strips/edges, modular furniture/props, functional stations, lighting/particles, transparent pet sprites, preview icons, portraits, UI icons, dungeon backgrounds, enemy sprites, and effects. No traditional generic tileset is required.

The three supplied mode references are indexed with dimensions and checksums in `references/ui-modes/README.md`. They remain directional concepts outside `res://`, not runtime or production assets.

Prompt 4.5 rejects the previous visible programmer-art/debug shell. The accepted implementation rules are defined in [`ART_STYLE_BIBLE.md`](ART_STYLE_BIBLE.md): warm readable pixel clusters, clean silhouette hierarchy, consistent 128-pixel creature canvases, restrained dark UI chrome, parchment text, green/gold selection accents, habitat depth without action-obscuring clutter, and no geometric creature placeholders.

The current 19-source visual batch supplies all three eggs, three hatchlings, six juvenile forms, three normal enemies, the boss, the fixed `Quiet Canopy` habitat, effects, props, and UI icons. It is visually reviewed and accepted only as `PROVISIONAL_PRODUCT_REVIEW`. Rights/license remain `UNDECIDED`; it is not final licensed production art. Habitat editing remains Milestone 5 and was not implemented.

Prompt 4.6 adds three family walk atlases without changing the accepted visual language. All nine playable forms now have genuine eight-frame locomotion at 10 fps, stable feet/ground anchors and generated GIF/contact-sheet review. Existing idle and action sheets remain provisional two-frame pose animations and are the main remaining animation-art limitation.
