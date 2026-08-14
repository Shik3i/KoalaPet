# Living Animation Evidence

## Review result

Prompt 4.7 was reviewed in three explicit passes:

1. Coverage audit found valid eight-frame walk cycles but two-pose care, condition, sleep and battle placeholders. The final bundled player contract is 29 animations for each of nine forms; four enemies each have five combat/reaction animations.
2. Contact-sheet review found a horizontal articulation seam. The deterministic processor increased source overlap to `8 px`, regenerated every affected sheet and passed identity, grounding, alpha and chronology inspection.
3. Native integration review used Godot Movie Writer. Seven videos and dense/sparse contact sheets verified idle/care/sleep, normal and reduced combat, VFX, opponents, ambient reactions and Minimal behavior. Win32 `PrintWindow` produced blank Vulkan captures and physical-screen capture could include occluding windows; neither path is accepted as Prompt-4.7 visual evidence.

## Environment

- Windows `10.0.26200`
- Godot `4.7.1.stable.official.a13da4feb`
- `gl_compatibility`, OpenGL `3.3.0`
- NVIDIA GeForce RTX 4080 SUPER, driver reported as `610.62`
- Three monitors, primary Windows scale `125%`

This host evidence does not establish Windows 10 parity, every mixed-DPI transition, macOS/Linux behavior, taskbar/Alt+Tab policy, screen-reader output or a release export.

## Generated review

- [`contact-sheets/moss-players.png`](contact-sheets/moss-players.png), [`contact-sheets/ember-players.png`](contact-sheets/ember-players.png), [`contact-sheets/tide-players.png`](contact-sheets/tide-players.png): all playable forms.
- [`contact-sheets/enemies.png`](contact-sheets/enemies.png): all current enemies and boss.
- [`reels/all-player-highlights.gif`](reels/all-player-highlights.gif): cross-family highlights.
- Family reels: [`moss-family.gif`](reels/moss-family.gif), [`ember-family.gif`](reels/ember-family.gif), [`tide-family.gif`](reels/tide-family.gif).

## Native visual evidence

Movie Writer recordings:

- `windows/care-sleep.avi` — 34 seconds.
- `windows/combat.avi` — 28 seconds, normal effects and two encounter profiles.
- `windows/minimal.avi` — 14 seconds.
- `windows/reduced-motion.avi` — 14 seconds.
- `windows/ambient.avi` — 14 seconds.
- `windows/sleep-habitat.avi` and `windows/sleep-minimal.avi` — 12 seconds each, driven by the authoritative sleep command.

Accepted extracted frames:

- [`idle.png`](windows/idle.png), [`playful-idle.png`](windows/playful-idle.png), [`ambient-effects.png`](windows/ambient-effects.png).
- [`normal-motion-attack.png`](windows/normal-motion-attack.png), [`hit.png`](windows/hit.png), [`dodge.png`](windows/dodge.png), [`vfx-impact.png`](windows/vfx-impact.png), [`reduced-motion-attack.png`](windows/reduced-motion-attack.png).
- [`sleep-habitat.png`](windows/sleep-habitat.png), [`sleep-minimal.png`](windows/sleep-minimal.png).

The corresponding `*-contact-sheet.png` files sample complete recordings. `combat-detail-contact-sheet.png` and `reduced-motion-detail-contact-sheet.png` densely sample the first exchange.

## Performance

`performance.json` contains eight four-second native scenarios. CPU is normalized against total capacity of 16 logical processors; memory is process working set. Every scenario wrote diagnostics.

| Metric | Observed |
|---|---:|
| FPS | 59–60 |
| CPU, maximum total capacity | 1.843% |
| Working-set peak | 203.44 MiB |
| Texture memory peak | 10.59 MiB |
| Active animation processors | bounded by active presentation |
| GPU counter | unavailable in deterministic harness |

## Reproduction

```powershell
python tools/art_pipeline/process_living_animation_assets.py
python tools/art_pipeline/validate_vertical_slice_assets.py --repo-root .
.\tools\visual_review\record_living_animation.ps1 -Scenario combat -OutputPath docs\evidence\living-animation\windows\combat.avi
python tools/visual_review/make_video_contact_sheet.py docs/evidence/living-animation/windows/combat.avi docs/evidence/living-animation/windows/combat-contact-sheet.png --samples 12
.\tools\visual_review\measure_animation_polish.ps1 -OutputPath docs\evidence\living-animation\performance.json -SampleSeconds 4
```

Video decoding uses the pinned review-only requirements in `tools/visual_review/requirements.txt`; they are installed outside the game runtime. `checksums.sha256` records the final evidence hashes.

## Asset and acceptance boundary

The VFX source was created with Codex built-in image generation from the preserved brief. The concrete model version was not exposed. Runtime sources and outputs are recorded in `art_source/provenance/living-animation.json`. Status remains `PROVISIONAL_PRODUCT_REVIEW`; `license_status=UNDECIDED`.
