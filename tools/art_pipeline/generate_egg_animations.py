#!/usr/bin/env python3
"""Build real egg wobble and hatch cycles from the accepted two-pose egg art.

The bundled eggs shipped as two-frame sheets. `world` and `hatch` ran at 10 fps,
so the egg the player stares at for the whole incubation was a 0.2 second
two-frame flicker, and hatching was over before it read as an event. This is the
first animation every new player sees.

No new source art is invented here. The existing accepted poses are re-timed and
re-posed with a per-row horizontal shear pivoted on the egg's ground anchor,
which is the classic pixel-art rocking motion: every row shifts by a whole
number of pixels, so the art stays crisp and the base stays planted. A small
luminance pulse carries the "something is alive in there" read.

Run:
    python tools/art_pipeline/generate_egg_animations.py
    python tools/art_pipeline/generate_egg_animations.py --check
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / "game" / "content_packs" / "koalapet.base"
EGGS = PACK / "assets" / "vertical_slice" / "eggs"
DATA = PACK / "data"
# The pristine two-pose art. Reading the runtime sheets instead would make the
# generator consume its own output and drift on every run.
SOURCE = ROOT / "art_source" / "sources" / "egg-poses"

FAMILIES = ("moss", "ember", "tide")
FRAME = 128
GROUND_Y = 116

# (source pose index, shear in pixels at the top row, top-only squash, luminance)
#
# A looping cycle stays on ONE source pose. Alternating between the two authored
# poses inside the loop measured as a ~1.0 whole-silhouette change twice per
# second, which reads as a flicker between two different eggs rather than as one
# egg rocking. The motion is carried entirely by the lean, the squash and a
# gentle luminance breath, so every transition stays around 0.3.
IDLE_CYCLE = [
    (0, 0, 0, 1.00),
    (0, -2, 0, 1.02),
    (0, -3, 1, 1.00),
    (0, 0, 0, 0.98),
    (0, 3, 0, 1.02),
    (0, 2, 1, 1.00),
]

WORLD_CYCLE = [
    (0, 0, 0, 1.00),
    (0, -3, 0, 1.03),
    (0, -4, 1, 1.00),
    (0, -1, 0, 0.97),
    (0, 4, 0, 1.03),
    (0, 3, 1, 1.00),
]

# Hatching escalates: two nervous jolts, the crack pose shaking, then the burst.
HATCH_CYCLE = [
    ("idle", 0, 0, 0, 1.00),
    ("idle", 0, 2, 0, 1.02),
    ("idle", 0, -4, 1, 1.00),
    ("idle", 1, 5, 0, 1.05),
    ("hatch", 0, -4, 0, 1.06),
    ("hatch", 0, 3, 1, 1.10),
    ("hatch", 1, 0, 0, 1.12),
    ("hatch", 1, 0, 0, 1.00),
]

HATCH_MARKERS = [
    {"frame": 3, "event": "shell_strain"},
    {"frame": 4, "event": "shell_cracked"},
    {"frame": 6, "event": "impact"},
    {"frame": 7, "event": "animation_complete"},
]

IDLE_FPS = 6
WORLD_FPS = 5
HATCH_FPS = 8


def read_poses(family: str, name: str) -> list[Image.Image]:
    path = SOURCE / family / f"{name}.png"
    with Image.open(path) as source:
        sheet = source.convert("RGBA")
    count = sheet.width // sheet.height
    return [sheet.crop((index * FRAME, 0, (index + 1) * FRAME, FRAME)) for index in range(count)]


def pose(source: Image.Image, shear: int, squash: int, luminance: float) -> Image.Image:
    """Rock the pose around its ground anchor using whole-pixel row offsets.

    Both the lean and the squash are driven by the same lever, which is zero at
    the ground anchor. The silhouette therefore never crosses the anchor line,
    so the egg cannot sink into the ground while it rocks.
    """
    result = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    pixels = source.load()
    target = result.load()
    for y in range(FRAME):
        # Rows at the base do not move; the offset grows towards the top.
        lever = max(0.0, (GROUND_Y - y) / float(GROUND_Y))
        offset = round(shear * lever * lever)
        destination_y = y + round(squash * lever)
        if destination_y < 0 or destination_y >= FRAME:
            continue
        for x in range(FRAME):
            source_pixel = pixels[x, y]
            if source_pixel[3] == 0:
                continue
            destination_x = x + offset
            if destination_x < 0 or destination_x >= FRAME:
                continue
            if luminance == 1.0:
                target[destination_x, destination_y] = source_pixel
            else:
                target[destination_x, destination_y] = (
                    min(255, int(source_pixel[0] * luminance)),
                    min(255, int(source_pixel[1] * luminance)),
                    min(255, int(source_pixel[2] * luminance)),
                    source_pixel[3],
                )
    return result


def build_sheet(frames: list[Image.Image]) -> Image.Image:
    sheet = Image.new("RGBA", (FRAME * len(frames), FRAME), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (index * FRAME, 0))
    return sheet


def build_family(family: str) -> dict[str, Image.Image]:
    idle_poses = read_poses(family, "idle")
    hatch_poses = read_poses(family, "hatch")
    world_poses = read_poses(family, "world")
    return {
        "idle": build_sheet([pose(idle_poses[index % len(idle_poses)], shear, squash, light) for index, shear, squash, light in IDLE_CYCLE]),
        "world": build_sheet([pose(world_poses[index % len(world_poses)], shear, squash, light) for index, shear, squash, light in WORLD_CYCLE]),
        "hatch": build_sheet([
            pose((idle_poses if group == "idle" else hatch_poses)[index % len(idle_poses if group == "idle" else hatch_poses)], shear, squash, light)
            for group, index, shear, squash, light in HATCH_CYCLE
        ]),
    }


def update_profile(family: str) -> None:
    path = DATA / f"animation_egg_{family}.json"
    document = json.loads(path.read_text(encoding="utf-8"))
    animations = document["world_animations"]
    for name, frames, fps, markers in (
        ("idle", len(IDLE_CYCLE), IDLE_FPS, []),
        ("world", len(WORLD_CYCLE), WORLD_FPS, []),
        ("hatch", len(HATCH_CYCLE), HATCH_FPS, HATCH_MARKERS),
    ):
        if name not in animations:
            continue
        entry = animations[name]
        entry["frames"] = frames
        entry["fps"] = fps
        entry["event_markers"] = [dict(marker) for marker in markers]
        entry["source_brief"] = (
            "Rocking incubation cycle re-posed from the accepted egg art with an "
            "anchor-pivoted whole-pixel shear"
        )
    path.write_bytes((json.dumps(document, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify committed sheets match the generator")
    args = parser.parse_args()

    problems: list[str] = []
    for family in FAMILIES:
        sheets = build_family(family)
        for name, sheet in sheets.items():
            target = EGGS / family / f"{name}.png"
            if args.check:
                with Image.open(target) as current:
                    if current.convert("RGBA").tobytes() != sheet.tobytes():
                        problems.append(f"STALE: eggs/{family}/{name}.png")
                continue
            sheet.save(target, optimize=True)
        if not args.check:
            update_profile(family)

    if args.check:
        for line in problems:
            print(line, file=sys.stderr)
        if problems:
            return 1
        print(f"egg animations verified: {len(FAMILIES) * 3}")
        return 0
    print(f"egg animations written: {len(FAMILIES) * 3}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
