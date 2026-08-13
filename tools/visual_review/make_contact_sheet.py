#!/usr/bin/env python3
"""Create a deterministic labeled contact sheet for visual review evidence."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw

MAX_INPUTS = 100
MAX_COLUMNS = 20
MAX_IMAGE_DIMENSION = 8_192
MAX_SHEET_PIXELS = 50_000_000
REPO_ROOT = Path(__file__).resolve().parents[2]
EVIDENCE_ROOT = (REPO_ROOT / "docs" / "evidence").resolve()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("inputs", nargs="+", type=Path)
    parser.add_argument("--columns", type=int, default=3)
    args = parser.parse_args()
    if not 1 <= args.columns <= MAX_COLUMNS:
        raise ValueError(f"columns must be between 1 and {MAX_COLUMNS}")
    if len(args.inputs) > MAX_INPUTS:
        raise ValueError(f"input count exceeds {MAX_INPUTS}")
    output_path = args.output.resolve()
    if output_path == EVIDENCE_ROOT or not output_path.is_relative_to(EVIDENCE_ROOT):
        raise ValueError(f"output must be below {EVIDENCE_ROOT}: {output_path}")
    images: list[tuple[str, Image.Image]] = []
    for path in args.inputs:
        try:
            with Image.open(path) as source:
                if source.width < 1 or source.height < 1 or source.width > MAX_IMAGE_DIMENSION or source.height > MAX_IMAGE_DIMENSION:
                    raise ValueError(f"Image dimensions out of range: {path} ({source.width}x{source.height})")
                images.append((path.stem, source.convert("RGBA")))
        except Exception:
            for _, image in images:
                image.close()
            raise
    sheet: Image.Image | None = None
    try:
        thumb_w = max(image.width for _, image in images)
        thumb_h = max(image.height for _, image in images)
        label_h = 24
        rows = (len(images) + args.columns - 1) // args.columns
        sheet_size = (args.columns * thumb_w, rows * (thumb_h + label_h))
        if sheet_size[0] * sheet_size[1] > MAX_SHEET_PIXELS:
            raise ValueError(f"contact sheet exceeds {MAX_SHEET_PIXELS} pixels")
        sheet = Image.new("RGB", sheet_size, "#0b141a")
        draw = ImageDraw.Draw(sheet)
        for index, (label, image) in enumerate(images):
            column = index % args.columns
            row = index // args.columns
            x = column * thumb_w + (thumb_w - image.width) // 2
            y = row * (thumb_h + label_h) + label_h
            draw.text((column * thumb_w + 6, row * (thumb_h + label_h) + 6), label, fill="#f3e2b8")
            sheet.paste(image, (x, y), image)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        sheet.save(output_path, optimize=True)
    finally:
        for _, image in images:
            image.close()
        if sheet is not None:
            sheet.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
