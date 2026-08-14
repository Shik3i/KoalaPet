# KoalaPet Art Style Bible

**Status:** accepted implementation rules for the presentation rebuild; generated art remains provisional until provenance and rights approval.

## Product read

Cozy, compact, readable modern pixel art with a quiet fantasy-natural tone. The visual result must feel hand-composed at desktop-companion scale: tactile dark UI, layered habitats, expressive original creatures, restrained particles, and no franchise imitation. Concept references define density and hierarchy only; they are never traced, cropped, shipped, or supplied as production-image inputs.

## Pixel and scale system

- Logical UI grid: `4 px`. Spacing, borders, focus rings, icon padding, and control heights use multiples of four.
- Character animation cell: `128×128 px`; silhouette occupies at most `104×104 px` with at least `8 px` transparent safety on every side.
- Preview: `64×64 px`. Portrait: `96×96 px`. Status/action icons: `24×24 px`; high-attention bubbles: `32×32 px`.
- Habitat master frame: `512×192 px`; Expanded may repeat or scale it by integer factors only. Small uses a `512×192 px` crop without fractional asset scaling.
- Runtime textures use nearest-neighbor filtering and integer placement. Fractional scale, sub-pixel sprite positions, mixed character-cell sizes, and automatic bilinear filtering are forbidden.
- Source generation may be larger, but accepted processing must recover an intentional pixel grid, reduce the palette, and produce the canonical dimensions above. Arbitrary illustration downscaling is not accepted.

## Shape language

- Creatures: strong asymmetrical silhouette, compact body mass, readable feet/appendages, two or three signature natural-fantasy details. No basic oval-with-face, polygon face, generic slime, or palette-only family variant.
- Eggs: one family construction with three distinct silhouettes and material details: layered seed shell, ember-cracked kiln shell, and glassy tide shell. Never plain colored ovals.
- Good-care juveniles: open posture, intentional grooming, lighter rhythm, controlled accents. Rough-care juveniles: heavier or wilder posture and more irregular natural growth, but still appealing and capable.
- Enemies: different locomotion and mass from companions. No recolored companion bodies.

## Palette and material

- Shared neutrals: ink navy `#101820`, deep slate `#182631`, panel blue-black `#20323B`, warm parchment `#F3E2B8`, muted silver `#9EB0B3`.
- Moss family: fern, lichen, pale blossom; Ember: terracotta, amber, cream flare; Tide: teal, glass blue, sea-foam. Enemy accents use the same world palette without copying family ramps.
- One local ramp per material, normally four to seven colors. Avoid isolated full-saturation pixels except alerts, magical effects, and focus marks.
- Wood is warm and grainy; stone is cool and blocky; metal is low-gloss with short highlights; foliage uses clustered leaf masses; fabric uses broad folds. Flat vector fills are forbidden.

## Light, shadow, and perspective

- Highlight direction: upper left. Cast and contact shadow direction: lower right.
- Creature contact shadows are separate soft pixel clusters, not baked opaque rectangles.
- Habitat perspective: compact side-on diorama with a shallow three-quarter ground plane. Functional anchors share one floor line.
- Day state: soft gold key light and cool recesses. Night state: desaturated blue ambient plus warm lamp islands. Lighting is a separate layer.

## UI construction

- Border: two-step pixel frame, `2 px` ink outer line and `2 px` slate inner bevel; select corners may use one clipped `4 px` stair.
- Panels: opaque only in Small/Expanded. Corners are stepped, never continuously rounded. Nested panels use lower contrast and a single inner keyline.
- Title bars: `28 px` minimum, icon/name left, window actions right, entire unused bar draggable.
- Primary buttons: warm active edge and filled center. Secondary buttons: dark fill and cool keyline. Icon buttons combine pictogram, shape change, and label/tooltip.
- States: normal, hover, pressed, disabled, keyboard focus. Hover brightens the inner bevel; pressed moves content `1 px` down/right; disabled removes saturation and adds a slash/notch; focus adds a persistent `2 px` light-gold outer bracket. State cannot be communicated by color alone.
- Tabs: selected tab joins the panel edge; unselected tabs retain a visible bottom keyline. Toggle state adds both a moving marker and `ON/OFF` text or localized equivalent.
- Status bars: `8 px` track plus `2 px` border, optional five-segment ticks. Low/urgent states add an icon and pulse or static high-contrast outline under reduced motion.
- Tooltip: compact dark panel, `8 px` padding, maximum `240 px`, word wrapping, no raw content IDs.
- Cards, modals, slots, node buttons, evolution silhouettes, event rows, and notifications reuse the same frame, focus, spacing, and state rules.

## Animation

- Idle: `2–4 fps`; walk: `8–12 fps` with eight sequential frames for every currently playable form; care reactions: `5–8 fps`; attacks/hits: `8–12 fps`; transformation/effects: `8–12 fps`; ambient habitat: `2–6 fps`. Bundled player actions use `4–8` chronological frames.
- Locomotion owns no world translation. Habitat/Minimal controllers move the sprite using delta time, pause before reversing, then mirror only when metadata permits. Every sheet defines pivot, ground anchor, visual center, interaction/effect bounds and event markers.
- Presentation priority is `evolution > battle > care > condition > sleep > locomotion > attention > ambient`. Stable one-shot event IDs prevent repeated refreshes from replaying reactions; bounded queues may evict only lower-priority pending events.
- Every current player-facing form follows the 29-ID contract in [`ANIMATION_COVERAGE.md`](ANIMATION_COVERAGE.md). Eggs expose `idle`, `hatch`, and `world`. Current enemies expose `idle`, `attack`, `hit`, `dodge`, and `defeat`.
- Loops must settle cleanly. Movement stays inside the canonical cell. Effects are separate layers and may not permanently alter the character texture.
- Reduced Motion disables ambient travel/bobbing, accelerates chronological frame cadence without skipping markers, reduces effects and uses static urgent feedback. Gameplay timing never depends on presentation animation.

## Transparency

- Character, prop, effect, and foreground assets are RGBA with transparent corners and no key-color fringe.
- Minimal Mode renders no panel, ColorRect, habitat, persistent label, or opaque clear color. Only pet, contact shadow where visually appropriate, and transient bubbles may draw.
- Minimal interaction polygon follows the current visual bounds with no more than `8 px` padding. Pixels outside it pass mouse input to the desktop.
- Soft edges must be authored against alpha, checked on light and dark checkerboards, and show no black halo.

## Localization and accessibility

- English and German share flexible containers. No component width is fitted only to English copy.
- Minimum normal UI text: `16 px` at 100% scale; title text starts at `18 px`. Important state always combines icon, text/shape, and contrast.
- UI scale (`Auto`, `100–200%`), text scale (`100–175%`) and pet scale (`75–200%`) are independent presentation preferences. Layout reflows before truncating localized copy.
- Keyboard focus is visible in every component. Touch is not a target, but interactive controls keep at least `36×36 px` hit bounds.
- Required review scales: Windows `100%`, `125%`, `150%`, and `200%`. No clipped German labels, hidden focus ring, or inaccessible action at those scales.

## Acceptance checks

- Contact sheets inspected at `100%` and `200%` nearest-neighbor.
- Alpha corners transparent; subject bounds fit manifest cells; frame count and sheet dimensions exact.
- Creature silhouettes remain distinguishable in monochrome at `64×64 px`.
- Habitat layers load in documented order and each functional station remains independently replaceable.
- No reference image, geometric placeholder creature, opaque Minimal background, or development-only text is reachable through the normal player path.
- Every current sequence must appear in the runtime-backed debug Showroom and machine-readable classification. `TECHNICALLY_BROKEN` and `NEEDS_REGENERATION` block the visual gate.
- Care and sleep sources must be rejected when a helper object, neighboring source cell or clipped alpha component enters a runtime frame.
