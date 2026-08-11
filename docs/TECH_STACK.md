# Technical Stack

## Verified development environment

| Tool | Verified version/path | Role |
|---|---|---|
| Godot | `4.7.1.stable.official.a13da4feb` at `/Applications/Godot.app/Contents/MacOS/Godot` | Pinned development version, headless shell validation, and Prompt 1 harness preparation |
| Python | `3.9.6` at `/usr/bin/python3` | Content/schema and deterministic asset tooling |
| FFmpeg | `/opt/homebrew/bin/ffmpeg` | Optional future animation previews |

ImageMagick and LibreSprite were not found in the initial command-path inspection and are optional. Pillow is a future deterministic image-processing dependency, not required for Prompt 0. Blender, Aseprite, Krita, and manual cleanup are not required standard-workflow tools.

## Baseline

- Godot 4.7.1 + GDScript; Windows 10/11 first.
- Git/GitHub for source and review.
- Python dependencies are pinned in tool-specific requirements files.
- Local-only core; no SDK, database, cloud, account, analytics, or network service.

Godot is pinned for development reproducibility, not evidence that Windows overlay APIs work. Prompt 1 must test actual Windows behavior. Future version upgrades require import/test evidence and an ADR review if they affect architecture or compatibility.

## Prompt 1 environment

- Preparation host: macOS `26.5.2` build `25F84`, arm64, Apple M4. It is not a Windows test environment.
- Project renderer: `gl_compatibility`; headless diagnostics reported DisplayServer `headless` and driver `opengl3`, with no graphics adapter name.
- Windows entry point: PowerShell `tools/windows_overlay_spike/run_spike.ps1`, with an exact Godot version gate and privacy-reviewed diagnostics.
- `pwsh` availability and Windows script execution are host-dependent; a macOS/headless run cannot validate native windows.
