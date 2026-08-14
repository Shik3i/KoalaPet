#!/usr/bin/env python3
"""Extract one bounded native review frame from an evidence video."""

from __future__ import annotations

import argparse
from pathlib import Path

import imageio.v2 as imageio
from PIL import Image

REPO_ROOT = Path(__file__).resolve().parents[2]
EVIDENCE_ROOT = (REPO_ROOT / "docs" / "evidence").resolve()
MAX_VIDEO_BYTES = 256 * 1024 * 1024


def require_evidence_path(path: Path, label: str) -> Path:
    resolved = path.resolve()
    if resolved == EVIDENCE_ROOT or not resolved.is_relative_to(EVIDENCE_ROOT):
        raise ValueError(f"{label} must be below {EVIDENCE_ROOT}: {resolved}")
    return resolved


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("video", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--seconds", type=float, required=True)
    args = parser.parse_args()
    video = require_evidence_path(args.video, "video")
    output = require_evidence_path(args.output, "output")
    if output.suffix.lower() != ".png":
        raise ValueError(f"output must be PNG: {output}")
    if not video.is_file() or video.stat().st_size > MAX_VIDEO_BYTES:
        raise ValueError(f"video missing or exceeds {MAX_VIDEO_BYTES} bytes: {video}")

    reader = imageio.get_reader(video)
    try:
        metadata = reader.get_meta_data()
        fps = max(1.0, float(metadata.get("fps", 1.0)))
        duration = max(0.1, float(metadata.get("duration", 0.0)))
        if not 0.0 <= args.seconds < duration:
            raise ValueError(f"seconds must be within [0, {duration}): {args.seconds}")
        frame_index = max(0, round(args.seconds * fps))
        frame = Image.fromarray(reader.get_data(frame_index)).convert("RGB")
    finally:
        reader.close()

    output.parent.mkdir(parents=True, exist_ok=True)
    frame.save(output, optimize=True)
    print(f"Native frame: {video.name} at {args.seconds:.3f}s -> {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
