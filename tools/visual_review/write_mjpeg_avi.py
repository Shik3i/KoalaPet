#!/usr/bin/env python3
"""Pack equally sized JPEG frames into a deterministic indexed MJPEG AVI."""

from __future__ import annotations

import argparse
import struct
import tempfile
from pathlib import Path

from PIL import Image

MAX_FRAMES = 18_000
MAX_FRAME_DIMENSION = 8_192
MAX_TOTAL_BYTES = 512 * 1024 * 1024
REPO_ROOT = Path(__file__).resolve().parents[2]
EVIDENCE_ROOT = (REPO_ROOT / "docs" / "evidence").resolve()
TEMP_ROOT = Path(tempfile.gettempdir()).resolve()


def require_descendant(path: Path, root: Path, label: str) -> Path:
    resolved = path.resolve()
    if resolved == root or not resolved.is_relative_to(root):
        raise ValueError(f"{label} must be below {root}: {resolved}")
    return resolved


def chunk(tag: bytes, payload: bytes) -> bytes:
    pad = b"\0" if len(payload) % 2 else b""
    return tag + struct.pack("<I", len(payload)) + payload + pad


def list_chunk(kind: bytes, payload: bytes) -> bytes:
    return chunk(b"LIST", kind + payload)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("frames", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--fps", type=int, default=6)
    args = parser.parse_args()
    if not 1 <= args.fps <= 60:
        raise ValueError("fps must be between 1 and 60")
    frames_root = require_descendant(args.frames, TEMP_ROOT, "frames")
    output_path = require_descendant(args.output, EVIDENCE_ROOT, "output")
    paths = sorted(frames_root.glob("*.jpg"))
    if not paths:
        raise RuntimeError("No JPEG frames found")
    if len(paths) > MAX_FRAMES:
        raise RuntimeError(f"Frame count exceeds {MAX_FRAMES}")
    with Image.open(paths[0]) as first:
        if first.format != "JPEG":
            raise RuntimeError(f"Not a JPEG frame: {paths[0]}")
        width, height = first.size
    if width < 1 or height < 1 or width > MAX_FRAME_DIMENSION or height > MAX_FRAME_DIMENSION:
        raise RuntimeError(f"Frame dimensions out of range: {width}x{height}")
    payloads: list[bytes] = []
    total_bytes = 0
    for path in paths:
        if not path.resolve().is_relative_to(frames_root):
            raise ValueError(f"frame escapes frames directory: {path}")
        with Image.open(path) as image:
            if image.format != "JPEG":
                raise RuntimeError(f"Not a JPEG frame: {path}")
            if image.size != (width, height):
                raise RuntimeError("Frame dimensions differ")
            image.verify()
        payload = path.read_bytes()
        total_bytes += len(payload)
        if total_bytes > MAX_TOTAL_BYTES:
            raise RuntimeError(f"Frame payload exceeds {MAX_TOTAL_BYTES} bytes")
        payloads.append(payload)
    frame_count = len(payloads)
    maximum = max(map(len, payloads))
    microseconds = round(1_000_000 / args.fps)

    avih = struct.pack(
        "<14I", microseconds, maximum * args.fps, 0, 0x10, frame_count, 0, 1,
        maximum, width, height, 0, 0, 0, 0,
    )
    strh = struct.pack(
        "<4s4sIHH8Ihhhh", b"vids", b"MJPG", 0, 0, 0, 0, 1, args.fps, 0,
        frame_count, maximum, 0xFFFFFFFF, 0, 0, 0, width, height,
    )
    strf = struct.pack(
        "<IiiHH4sIiiII", 40, width, height, 1, 24, b"MJPG", width * height * 3,
        0, 0, 0, 0,
    )
    hdrl = list_chunk(b"hdrl", chunk(b"avih", avih) + list_chunk(b"strl", chunk(b"strh", strh) + chunk(b"strf", strf)))

    movi_payload = bytearray()
    index = bytearray()
    offset = 4
    for payload in payloads:
        frame_chunk = chunk(b"00dc", payload)
        movi_payload.extend(frame_chunk)
        index.extend(struct.pack("<4sIII", b"00dc", 0x10, offset, len(payload)))
        offset += len(frame_chunk)
    body = b"AVI " + hdrl + list_chunk(b"movi", bytes(movi_payload)) + chunk(b"idx1", bytes(index))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(b"RIFF" + struct.pack("<I", len(body)) + body)
    print(f"MJPEG AVI: {output_path} ({frame_count} frames, {width}x{height}, {args.fps} fps)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
