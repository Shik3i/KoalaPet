# Prompt 4.6 Animation and UI Polish Evidence

**Host:** Windows 11 `10.0.26200`, primary display 125% DPI, Godot `4.7.1.stable.official.a13da4feb`, OpenGL compatibility renderer, NVIDIA GeForce RTX 4080 SUPER.
**Scope:** native debug runtime and deterministic source/runtime validation; no release-build or final accessibility/art-rights claim.

## Art and animation

- `contact-sheets/walk-cycles.png`: all nine playable forms × eight chronological frames.
- `previews/*-walk.gif`: nine 10-fps looping previews.
- Runtime sheets: 1024×128 RGBA, eight 128×128 frames, ground/pivot `(64,116)`, metadata-controlled mirroring and foot-contact markers.
- Source brief and provenance: `art_source/prompts/animation-polish-walk-cycles.md`, `art_source/provenance/visual-rebuild.json`.

## Native Windows screenshots

Each PNG has an adjacent diagnostic JSON emitted by the player scene.

| Artifact | Direct observation |
|---|---|
| `windows/small-default.png` | 640×360 Small; readable status/icons and three care actions |
| `windows/small-ui-150.png` | UI scale 150%; entire Small composition scales together |
| `windows/expanded-default.png` | 1120×720 three-column management layout |
| `windows/expanded-text-150.png` | 150% text; German tabs/actions remain reachable |
| `windows/settings-panel.png` | scrollable player settings; labels paired with controls |
| `windows/minimal-pet-75.png`, `minimal-pet-150.png` | complete transparent pet at independent Minimal scales |
| `windows/feeding-bowl.png` | pet walking toward bowl anchor |
| `windows/training-station.png` | pet walking toward training anchor |
| `windows/sleeping-den.png` | sleep state held at bed anchor |

`animation-polish-film.avi` contains 184 MJPEG frames at 1600×1000, 8 fps and 23 seconds. `animation-polish-film.json` records Small/Expanded/Minimal window transitions and the intended roaming, feed, training, sleep and live-scale scenarios. Nine GIFs provide the frame-accurate walk-cycle evidence.

## Performance

`performance.json` contains seven fresh native-process measurements, four seconds each, normalized to total 16-logical-processor capacity:

| Scenario | CPU | Avg RAM | Peak RAM |
|---|---:|---:|---:|
| Minimal roaming | 0.654% | 180.76 MB | 183.55 MB |
| Minimal stationary | 0.940% | 180.63 MB | 183.10 MB |
| Small idle | 0.861% | 180.28 MB | 182.42 MB |
| Small ambient walk | 0.744% | 180.11 MB | 182.18 MB |
| Small action | 0.803% | 179.59 MB | 182.82 MB |
| Expanded idle | 1.071% | 188.38 MB | 193.07 MB |
| Minimal moving hit region | 1.169% | 177.95 MB | 181.29 MB |

GPU process counters were unavailable in the deterministic harness; no GPU-utilization number is claimed.

## Reproduction

```powershell
$py = 'C:\Users\s3ish\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $py tools\art_pipeline\process_visual_rebuild_assets.py
& $py tools\art_pipeline\validate_vertical_slice_assets.py --repo-root .
& 'C:\tmp\Godot-4.7.1\Godot_v4.7.1-stable_win64_console.exe' --headless --path game --script res://tests/presentation/run_all.gd
.\tools\visual_review\measure_animation_polish.ps1
```

Native isolated captures use `tools/visual_review/capture_visual_rebuild.ps1`. The demo film uses `--animation-polish-demo`, `record_animation_polish.ps1`, then `write_mjpeg_avi.py`.

## Evidence limits

- Computer-use initialization failed with `EPERM: operation not permitted, lstat 'C:\Users\s3ish\AppData\Local\OpenAI\Codex'`; native Godot/Win32 capture was used instead.
- No formal screen-reader, full keyboard-only, complete contrast, Windows 10, mixed-DPI monitor-transition, taskbar/Alt+Tab, tray, export/signing or release-build acceptance.
- Generated art rights remain `UNDECIDED`; exact image-generation model/version was not exposed.
- Idle and non-locomotion reactions remain provisional two-frame pose animations.
