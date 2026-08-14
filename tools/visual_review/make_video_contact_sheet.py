#!/usr/bin/env python3
"""Create a bounded contact sheet from a native review video."""

from __future__ import annotations

import argparse
import math
import tempfile
from pathlib import Path

import imageio.v2 as imageio
from PIL import Image, ImageDraw, ImageFont

REPO_ROOT = Path(__file__).resolve().parents[2]
EVIDENCE_ROOT = (REPO_ROOT / "docs" / "evidence").resolve()
MAX_VIDEO_BYTES = 256 * 1024 * 1024
MAX_SAMPLES = 24


def require_evidence_path(path: Path, label: str) -> Path:
    resolved = path.resolve()
    if resolved == EVIDENCE_ROOT or not resolved.is_relative_to(EVIDENCE_ROOT):
        raise ValueError(f"{label} must be below {EVIDENCE_ROOT}: {resolved}")
    return resolved


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("video", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--samples", type=int, default=12)
    parser.add_argument("--columns", type=int, default=4)
    parser.add_argument("--start", type=float, default=0.0)
    parser.add_argument("--end", type=float, default=0.0)
    args = parser.parse_args()
    video = require_evidence_path(args.video, "video")
    output = require_evidence_path(args.output, "output")
    if not video.is_file() or video.stat().st_size > MAX_VIDEO_BYTES:
        raise ValueError(f"video missing or exceeds {MAX_VIDEO_BYTES} bytes: {video}")
    if not 2 <= args.samples <= MAX_SAMPLES or not 1 <= args.columns <= 8:
        raise ValueError("samples or columns outside review bounds")

    reader = imageio.get_reader(video)
    try:
        metadata = reader.get_meta_data()
        fps = max(1.0, float(metadata.get("fps", 1.0)))
        duration = max(0.1, float(metadata.get("duration", 0.0)))
        start = args.start
        end = args.end if args.end > 0.0 else duration
        if not 0.0 <= start < end <= duration:
            raise ValueError(f"sample range must be within [0, {duration}]: {start}..{end}")
        sample_times = [
            start + (end - start) * index / max(1, args.samples - 1)
            for index in range(args.samples)
        ]
        frames: list[tuple[float, Image.Image]] = []
        for seconds in sample_times:
            array = reader.get_data(max(0, round(seconds * fps) - (1 if seconds >= duration else 0)))
            frames.append((seconds, Image.fromarray(array).convert("RGB")))
    finally:
        reader.close()

    thumb_width = 448
    thumb_height = round(frames[0][1].height * thumb_width / frames[0][1].width)
    label_height = 24
    rows = math.ceil(len(frames) / args.columns)
    sheet = Image.new("RGB", (args.columns * thumb_width, rows * (thumb_height + label_height)), "#101820")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for index, (seconds, frame) in enumerate(frames):
        x = (index % args.columns) * thumb_width
        y = (index // args.columns) * (thumb_height + label_height)
        frame.thumbnail((thumb_width, thumb_height), Image.Resampling.LANCZOS)
        sheet.paste(frame, (x, y + label_height))
        draw.text((x + 8, y + 7), f"{seconds:05.1f}s", fill="#f3e2b8", font=font)
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output, optimize=True)
    print(
        f"Video contact sheet: {video.name}, {start:.2f}..{end:.2f}s, "
        f"{len(frames)} samples -> {output}"
    )
    return 0


if __name__ == "__main__":
    with tempfile.TemporaryDirectory(prefix="koalapet-video-review-"):
        raise SystemExit(main())
