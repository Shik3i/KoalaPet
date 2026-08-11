# Technical Stack

## Verified development environment

| Tool | Verified version/path | Prompt 0 role |
|---|---|---|
| Godot | `4.7.1.stable.official.a13da4feb` at `/Applications/Godot.app/Contents/MacOS/Godot` | Pinned development version and headless shell validation |
| Python | `3.9.6` at `/usr/bin/python3` | Content/schema and deterministic asset tooling |
| FFmpeg | `/opt/homebrew/bin/ffmpeg` | Optional future animation previews |

ImageMagick and LibreSprite were not found in the initial command-path inspection and are optional. Pillow is a future deterministic image-processing dependency, not required for Prompt 0. Blender, Aseprite, Krita, and manual cleanup are not required standard-workflow tools.

## Baseline

- Godot 4.7.1 + GDScript; Windows 10/11 first.
- Git/GitHub for source and review.
- Python dependencies are pinned in tool-specific requirements files.
- Local-only core; no SDK, database, cloud, account, analytics, or network service.

Godot is pinned for development reproducibility, not evidence that Windows overlay APIs work. Prompt 1 must test actual Windows behavior. Future version upgrades require import/test evidence and an ADR review if they affect architecture or compatibility.
