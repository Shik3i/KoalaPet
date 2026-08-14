#!/usr/bin/env python3
"""Audit runtime animation sheets for frame count and real visible motion.

A sheet can satisfy the geometry validator and still look wrong in game: two
frames read as a stutter rather than a cycle, and a sheet whose frames barely
differ reads as a still image no matter how many frames it declares.

For every referenced animation this reports:

* declared frame count, fps and resulting cycle length
* mean per-frame pixel change, as a share of the drawn (non-transparent) area
* the largest single frame-to-frame jump, which catches a pop between two
  otherwise identical halves
* the number of *distinct* frames, which catches padded sheets

Run:
    python tools/art_pipeline/audit_animation_quality.py
    python tools/art_pipeline/audit_animation_quality.py --check
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / "game" / "content_packs" / "koalapet.base"
DATA = PACK / "data"
REPORT = ROOT / "docs" / "evidence" / "ui-rescue" / "animation-quality.json"

# Minimum frames for an animation the player watches for more than a moment.
# One-shots may be shorter than loops because they are seen once and in motion.
MIN_FRAMES_LOOP = 4
MIN_FRAMES_ONESHOT = 4

# Below this mean change a multi-frame animation reads as a still image.
MIN_MEAN_CHANGE = 0.012

# One transition inside a loop may not exceed the quietest one by more than this,
# or the cycle reads as a flicker between two different poses rather than as one
# subject moving. Calibrated on a real defect: the shipped two-pose egg loop
# measured 3.37 here, while every hand-weighted four-frame idle sits at 1.0-2.5.
MAX_POP_RATIO = 3.0

# A cycle shorter than this feels like a flicker; longer than this feels stalled.
MIN_CYCLE_SECONDS = 0.35
MAX_CYCLE_SECONDS = 3.2

# Sheets that are intentionally single-frame reference art, not animations.
STATIC_SUFFIXES = ("preview.png", "portrait.png")


def load_profiles() -> list[dict]:
    profiles = []
    for path in sorted(DATA.glob("animation_*.json")):
        document = json.loads(path.read_text(encoding="utf-8"))
        profiles.append({"id": document.get("id", path.stem), "document": document, "path": path})
    return profiles


def frame_images(sheet: Image.Image, frames: int) -> list[Image.Image]:
    width = sheet.width // frames
    return [sheet.crop((index * width, 0, (index + 1) * width, sheet.height)) for index in range(frames)]


def classify_duplicates(digests: list[str], loop: bool) -> tuple[list[str], list[str]]:
    """Split repeated frames into intentional structure and real waste.

    Two repeats are deliberate craft, not defects:

    * frame 0 is the rest pose by construction in this asset set, so any later
      frame that returns to it is the animation settling — a breathing loop is
      literally rest, in, rest, out;
    * a ping-pong holds its mirrored midpoint, which is how a wind-up and its
      recovery share poses.

    Anything else is a frame the player paid for and did not see.
    """
    total = len(digests)
    intentional: list[str] = []
    wasteful: list[str] = []
    first_index: dict[str, int] = {}
    for index, digest in enumerate(digests):
        if digest not in first_index:
            first_index[digest] = index
            continue
        origin = first_index[digest]
        label = f"{origin}=={index}"
        returns_to_rest = origin == 0
        ping_pong = origin + index == total or origin + index == total - 1
        # A one-shot may settle by repeating a pose in its final beats.
        settles = not loop and index >= total - 3
        if returns_to_rest or ping_pong or settles:
            intentional.append(label)
        else:
            wasteful.append(label)
    return intentional, wasteful


def measure(path: Path, declared_frames: int, loop: bool) -> dict:
    with Image.open(path) as source:
        sheet = source.convert("RGBA")
    frames = frame_images(sheet, declared_frames)
    # Raw bytes rather than getdata(): identical semantics, no deprecation and
    # roughly an order of magnitude faster across 290 sheets.
    alpha = sheet.tobytes()[3::4]
    drawn = max(1, sum(1 for value in alpha if value > 8) // max(1, declared_frames))

    digests = [hashlib.sha1(frame.tobytes()).hexdigest() for frame in frames]
    intentional, wasteful = classify_duplicates(digests, loop)
    changes: list[float] = []
    for index in range(len(frames)):
        # A one-shot never plays its last-to-first transition, so measuring it
        # would report a pop the player can never see.
        if not loop and index == len(frames) - 1:
            continue
        current = frames[index]
        following = frames[(index + 1) % len(frames)]
        difference = ImageChops.difference(current.convert("RGB"), following.convert("RGB")).tobytes()
        changed = sum(
            1
            for offset in range(0, len(difference), 3)
            if difference[offset] + difference[offset + 1] + difference[offset + 2] > 24
        )
        changes.append(changed / drawn)
    return {
        "distinct_frames": len(set(digests)),
        "intentional_repeats": intentional,
        "wasteful_repeats": wasteful,
        "mean_change": round(sum(changes) / len(changes), 5) if changes else 0.0,
        "max_change": round(max(changes), 5) if changes else 0.0,
        "min_change": round(min(changes), 5) if changes else 0.0,
    }


def audit() -> dict:
    rows: list[dict] = []
    for profile in load_profiles():
        document = profile["document"]
        animations = document.get("world_animations", {})
        for name, entry in sorted(animations.items()):
            asset = PACK / str(entry.get("asset", "")).replace("res://", "")
            if not asset.exists():
                rows.append({"profile": profile["id"], "animation": name, "issues": ["ASSET_MISSING"]})
                continue
            frames = int(entry.get("frames", 1))
            fps = float(entry.get("fps", 1.0))
            loop = bool(entry.get("loop", False))
            metrics = measure(asset, frames, loop)
            cycle = frames / fps if fps > 0 else 0.0

            issues: list[str] = []
            minimum = MIN_FRAMES_LOOP if loop else MIN_FRAMES_ONESHOT
            if frames < minimum:
                issues.append(f"TOO_FEW_FRAMES({frames}<{minimum})")
            if metrics["wasteful_repeats"]:
                issues.append("WASTED_FRAMES(" + ",".join(metrics["wasteful_repeats"]) + ")")
            if frames > 1 and metrics["mean_change"] < MIN_MEAN_CHANGE:
                issues.append(f"NEARLY_STATIC({metrics['mean_change']})")
            # A single transition far larger than the rest of the cycle is a pop.
            if loop and metrics["min_change"] > 0.0 and metrics["max_change"] > metrics["min_change"] * MAX_POP_RATIO:
                issues.append(f"POP_IN_LOOP({metrics['max_change']}/{metrics['min_change']})")
            if cycle and cycle < MIN_CYCLE_SECONDS:
                issues.append(f"CYCLE_TOO_FAST({round(cycle, 2)}s)")
            if cycle and cycle > MAX_CYCLE_SECONDS:
                issues.append(f"CYCLE_TOO_SLOW({round(cycle, 2)}s)")

            rows.append({
                "profile": profile["id"],
                "animation": name,
                "asset": str(asset.relative_to(PACK)).replace("\\", "/"),
                "frames": frames,
                "fps": fps,
                "loop": loop,
                "cycle_seconds": round(cycle, 3),
                "issues": issues,
                **metrics,
            })
    return {
        "schema_version": 1,
        "generator": "tools/art_pipeline/audit_animation_quality.py",
        "thresholds": {
            "min_frames_loop": MIN_FRAMES_LOOP,
            "min_frames_oneshot": MIN_FRAMES_ONESHOT,
            "min_mean_change": MIN_MEAN_CHANGE,
            "max_pop_ratio": MAX_POP_RATIO,
            "cycle_seconds": [MIN_CYCLE_SECONDS, MAX_CYCLE_SECONDS],
        },
        "total_animations": len(rows),
        "animations_with_issues": sum(1 for row in rows if row.get("issues")),
        "animations": rows,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="fail when any animation still has an issue")
    parser.add_argument("--verbose", action="store_true", help="print every offending animation")
    args = parser.parse_args()

    report = audit()
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_bytes((json.dumps(report, indent=2) + "\n").encode("utf-8"))

    offenders = [row for row in report["animations"] if row.get("issues")]
    print(f"animations audited: {report['total_animations']}, with issues: {len(offenders)}")
    if args.verbose or args.check:
        for row in offenders:
            print(f"  {row['profile']:<44} {row['animation']:<16} {','.join(row['issues'])}", file=sys.stderr)
    if args.check and offenders:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
