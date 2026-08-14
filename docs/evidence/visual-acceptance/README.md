# Visual Acceptance Review Package

Review date: 2026-08-14. All assets are provisional. Start with the short reels, then use the contact sheets for exceptions. Exact purpose, settings, reproduction command and SHA-256 for every artifact are in [`evidence-manifest.json`](evidence-manifest.json); [`hashes.sha256`](hashes.sha256) is the compact integrity list.

## Short reels

- Starter-family motion: [`moss-family.gif`](../living-animation/reels/moss-family.gif), [`ember-family.gif`](../living-animation/reels/ember-family.gif), [`tide-family.gif`](../living-animation/reels/tide-family.gif)
- [`enemy-boss-combat.gif`](reels/enemy-boss-combat.gif)
- [`sleep-care.gif`](reels/sleep-care.gif)
- [`minimal-desktop.gif`](reels/minimal-desktop.gif)
- [`reduced-motion-comparison.gif`](reels/reduced-motion-comparison.gif)
- [`ui-scaling-comparison.png`](contact-sheets/ui-scaling-comparison.png)

## Contact sheets

- Moss: [`moss_hatchling.png`](contact-sheets/moss_hatchling.png), [`moss_bloom_juvenile.png`](contact-sheets/moss_bloom_juvenile.png), [`moss_bracken_juvenile.png`](contact-sheets/moss_bracken_juvenile.png)
- Ember: [`ember_hatchling.png`](contact-sheets/ember_hatchling.png), [`ember_dawn_juvenile.png`](contact-sheets/ember_dawn_juvenile.png), [`ember_cinder_juvenile.png`](contact-sheets/ember_cinder_juvenile.png)
- Tide: [`tide_hatchling.png`](contact-sheets/tide_hatchling.png), [`tide_glass_juvenile.png`](contact-sheets/tide_glass_juvenile.png), [`tide_reed_juvenile.png`](contact-sheets/tide_reed_juvenile.png)
- Cross-system: [`enemies-and-boss.png`](contact-sheets/enemies-and-boss.png), [`combat-effects.png`](contact-sheets/combat-effects.png), [`regenerated-examples.png`](contact-sheets/regenerated-examples.png)

## Native Windows captures

- [`showroom-runtime-secondary.png`](windows/showroom-runtime-secondary.png): complete Showroom layout and runtime egg playback.
- [`game-starter-focus-secondary.png`](windows/game-starter-focus-secondary.png): starter-selection readability and visible Tab focus.
- [`environment.windows.json`](windows/environment.windows.json): monitor/DPI/taskbar inventory.
- [`native-review.json`](windows/native-review.json): exact direct, partial, unavailable and blocked shell/accessibility rows.

## Machine-readable review

- [`animation-classifications.json`](animation-classifications.json): all `290` runtime sequences.
- [`asset-rights-register.json`](asset-rights-register.json): all `388` distributed visual PNGs plus three non-distributed references.
- [`asset-optimization.json`](asset-optimization.json): Prompt-4.7 baseline versus Prompt-4.8 after-state, disk/decode estimates, exact duplicates and all unreferenced PNG reasons.

## Known limits

- Final art approval and rights/license decisions are open.
- Godot controls exposed no usable Windows accessibility tree.
- Native display-scale coverage is incomplete above the directly available host configurations; synthetic project-scale checks are labeled separately.
- Tray callbacks/cleanup, Show Desktop recovery and controlled mixed-DPI movement remain unavailable.
- No release, packaging or Milestone-5 work is represented.

Reproduce the deterministic package with:

```powershell
C:\Users\s3ish\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe tools/visual_review/audit_animation_sequences.py --check
```
