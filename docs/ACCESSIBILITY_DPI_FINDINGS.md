# Accessibility and DPI Findings

## Direct Windows evidence

The interactive Windows 11 host exposes three displays: two at `100%` and a `125%` primary display. Native captures on a secondary display show readable starter cards, visible keyboard focus and a complete Showroom layout. Alt+Tab and native minimize/restore completed without a hang or state loss. The session exited cleanly.

The direct matrix does not cover runtime movement across monitors or native `150%`, `175%` and `200%` display settings. Automated layout tests cover project UI scale `100–200%`, text scale `100–175%`, English/German and compact/comfortable density, but that evidence is not a substitute for native Windows display scaling.

Evidence: [`evidence/visual-acceptance/windows/environment.windows.json`](evidence/visual-acceptance/windows/environment.windows.json), [`evidence/visual-acceptance/windows/native-review.json`](evidence/visual-acceptance/windows/native-review.json).

## Keyboard

- Directly observed: Tab navigation reaches starter actions; focus is a persistent gold outline and is not conveyed by color alone.
- Automated: starter selection, care, settings, mode changes, battle stance/start, dungeon actions, inventory/codex tabs, modal close/back and focus restoration remain within validated action/layout contracts.
- No keyboard trap was observed in the direct Showroom/starter pass.

## Text, contrast and motion

- Important pet and battle states retain explicit text/icon status; color is not the only signal.
- High contrast, tooltips, UI scale, text scale and density remain versioned presentation preferences.
- Reduced Motion suppresses ambient travel and displacement, retains chronological marker delivery and keeps outcomes readable through static feedback.
- No formal accessibility compliance claim is made.

## Screen-reader finding

The Windows accessibility-tree inspection discovered native Godot window chrome but no usable child tree for Godot `Control` nodes. Internal buttons and selectors therefore exposed neither names nor focus order to the inspection tool. Tooltips and visible labels improve sighted use but do not fix this engine-level screen-reader gap.

This is a release blocker for screen-reader acceptance. Re-evaluate with a Godot version/native bridge that exposes UI Automation semantics; do not accept ADR 0010 from this evidence.
