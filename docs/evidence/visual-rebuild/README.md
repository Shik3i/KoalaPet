# Prompt 4.5 Visual Rebuild Evidence

**Host:** Windows 11 Pro `10.0.26200`, primary 125% scaling, Godot `4.7.1.stable.official.a13da4feb`, NVIDIA GeForce RTX 4080 SUPER.
**Privacy:** captures contain only KoalaPet or the synthetic `KoalaPet Click-Through Probe` underlay. `minimal-transparent-desktop.png` contains the local desktop crop already approved for this task and no account, browser or private document content.

## Coverage

| Requirement | Artifact |
|---|---|
| starter selection | `windows/starter-selection.png` |
| each egg | `windows/egg-{moss,ember,tide}.png` |
| each hatchling | `windows/hatchling-{moss,ember,tide}-small.png` |
| good / poor juvenile | `windows/juvenile-good.png`, `windows/juvenile-poor.png` |
| true transparent Minimal | `windows/minimal-transparent-desktop.png` + JSON |
| Small / Expanded | `windows/small-care.png`, `windows/expanded-management.png` |
| feeding / waste / cleaning | `windows/feeding.png`, `windows/waste-before-clean.png`, `windows/cleaned.png` |
| sleep / sickness / injury | `windows/sleep.png`, `windows/sickness.png`, `windows/injury.png` |
| evolution | `windows/evolution.png` |
| normal battle / reward | `windows/battle-normal.png`, `windows/battle-result-reward.png` |
| dungeon node / boss / reward | `windows/dungeon-node.png`, `windows/dungeon-boss.png`, `windows/dungeon-reward.png` |
| full interaction sequence | `video/koalapet-interactive-windows-review.avi` |
| film visual index | `video/contact-sequence-final.png` |
| film native event log | `video/interaction-final.json` |
| source/runtime art review | `contact-sheets/*.png` |

The JSON beside each screenshot is emitted by the running player scene. It records logical mode, state revision, root background count and native adapter/window diagnostics.

## Direct transparency result

`minimal-transparent-desktop.json` records:

- mode `minimal`, logical window `240×160`
- `window_transparent=true`, `viewport_transparent_bg=true`, `window_borderless=true`
- `window_always_on_top=true`, `window_unfocusable=true`
- `focus_policy=no_focus`, `input_policy=hit_region`
- zero persistent root `ColorRect` backgrounds
- a bounded mouse-passthrough polygon around the 128×128 pet

The corresponding desktop capture shows the pet composited directly over Windows without an opaque window rectangle.

## Direct interaction-film result

`interaction-final.json` gates the successful 14-second capture:

1. pet clicked; Small observed as `448×243` through the recorder at 125% Windows scaling
2. Feed clicked
3. F3; Expanded observed as `832×512`
4. F1; Minimal observed as `192×128`
5. click outside the pet: the native hit target is the underlay process, not KoalaPet
6. `outside_pet_native_hit_bypassed_running_koalapet=true`

Godot diagnostics retain canonical logical sizes `560×304` and `1040×640`; the recorder's HWND query is DPI-virtualized, hence the inverse 0.8 measurements. The explicit size gates prevent an unobserved mode change from being accepted.

## Reproduction

Process the deterministic runtime art:

```powershell
$py = 'C:\Users\s3ish\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $py tools\art_pipeline\process_visual_rebuild_assets.py
& $py tools\art_pipeline\validate_vertical_slice_assets.py --repo-root .
```

Capture an isolated native state:

```powershell
.\tools\visual_review\capture_visual_rebuild.ps1 -Name 'small-care' -SaveName 'review-small' -Mode 'small' -Actions 'choose:moss,hatch'
```

The film requires a running Minimal-mode KoalaPet with a hatched pet, then:

```powershell
.\tools\visual_review\record_interactive_video.ps1 -FramesPath "$env:TEMP\koalapet-film-frames" -LogPath "docs\evidence\visual-rebuild\animation-film.json" -Fps 6 -DurationSeconds 14
& $py tools\visual_review\write_mjpeg_avi.py "$env:TEMP\koalapet-film-frames" "docs\evidence\visual-rebuild\animation-film.avi" --fps 6
```

Full automated gate:

```powershell
& $py tools\run_foundation_checks.py --godot 'C:\tmp\Godot-4.7.1\Godot_v4.7.1-stable_win64_console.exe'
```

## Hashes

`hashes.sha256` contains SHA-256 for every committed file below this evidence directory except the hash file itself. Regenerate from repository root:

```powershell
$root = (Resolve-Path docs\evidence\visual-rebuild).Path
Get-ChildItem $root -Recurse -File | Where-Object Name -ne 'hashes.sha256' | Sort-Object FullName | ForEach-Object {
    $relative = $_.FullName.Substring($root.Length + 1).Replace('\', '/')
    '{0}  {1}' -f (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(), $relative
} | Set-Content docs\evidence\visual-rebuild\hashes.sha256 -Encoding utf8
```

## Evidence boundary

Direct evidence applies to this host and this Godot debug runtime. It does not establish release-build behavior, Windows 10 parity, every DPI/monitor transition, taskbar/Alt+Tab policy, tray lifecycle, screen-reader output, final contrast acceptance or art licensing. ADR 0010 remains proposed.
