#!/usr/bin/env python3
"""Generate deterministic provisional Milestone 3 pixel assets without external services."""

from __future__ import annotations

import binascii
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game" / "content_packs" / "koalapet.base" / "assets" / "vertical_slice"


def chunk(kind: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", binascii.crc32(kind + payload) & 0xFFFFFFFF)


def write_png(path: Path, width: int, height: int, pixels: list[list[tuple[int, int, int, int]]]) -> None:
    raw = b"".join(b"\x00" + bytes(value for pixel in row for value in pixel) for row in pixels)
    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def canvas(size: int = 96) -> list[list[tuple[int, int, int, int]]]:
    return [[(0, 0, 0, 0) for _ in range(size)] for _ in range(size)]


def px(image, x: int, y: int, color) -> None:
    if 0 <= y < len(image) and 0 <= x < len(image[y]):
        image[y][x] = color


def rect(image, x0: int, y0: int, x1: int, y1: int, color) -> None:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(image, x, y, color)


def polygon(image, points, color) -> None:
    min_y = max(0, min(y for _, y in points))
    max_y = min(len(image) - 1, max(y for _, y in points))
    for y in range(min_y, max_y + 1):
        intersections = []
        for (x0, y0), (x1, y1) in zip(points, points[1:] + points[:1]):
            if y0 == y1:
                continue
            if min(y0, y1) <= y < max(y0, y1):
                intersections.append(x0 + (y - y0) * (x1 - x0) / (y1 - y0))
        intersections.sort()
        for left, right in zip(intersections[::2], intersections[1::2]):
            for x in range(max(0, int(left)), min(len(image[y]) - 1, int(right)) + 1):
                px(image, x, y, color)


def scale(image, target: int) -> list[list[tuple[int, int, int, int]]]:
    source = len(image)
    return [[image[y * source // target][x * source // target] for x in range(target)] for y in range(target)]


def egg(color, accent, size: int = 96):
    image = canvas(size)
    c = size // 2
    polygon(image, [(c, 10), (c + 20, 18), (c + 27, 40), (c + 21, 68), (c, 84), (c - 23, 68), (c - 27, 41), (c - 18, 18)], color)
    polygon(image, [(c - 17, 26), (c - 6, 20), (c + 5, 27), (c - 3, 37)], accent)
    polygon(image, [(c + 9, 47), (c + 22, 40), (c + 18, 57), (c + 4, 64)], accent)
    rect(image, c - 3, 73, c + 3, 78, (255, 239, 181, 255))
    return image


def creature(kind: str, color, accent, mood: str = "idle", size: int = 96):
    image = canvas(size)
    dark = (31, 29, 42, 255)
    cream = (255, 232, 183, 255)
    if kind == "moss":
        polygon(image, [(22, 66), (22, 45), (31, 34), (38, 18), (48, 30), (62, 22), (72, 36), (82, 41), (76, 67), (60, 77), (37, 77)], color)
        polygon(image, [(65, 39), (91, 31), (80, 51), (66, 55)], accent)
        rect(image, 31, 51, 37, 59, cream)
        rect(image, 57, 51, 63, 59, cream)
        rect(image, 34, 54, 38, 58, dark)
        rect(image, 58, 54, 62, 58, dark)
        polygon(image, [(39, 65), (48, 70), (58, 65), (53, 73), (45, 73)], dark)
    elif kind == "ember":
        polygon(image, [(23, 70), (26, 45), (36, 37), (41, 18), (51, 31), (64, 13), (66, 35), (80, 43), (76, 70), (57, 82), (37, 79)], color)
        polygon(image, [(65, 31), (92, 38), (76, 50), (65, 47)], accent)
        rect(image, 34, 51, 40, 59, cream)
        rect(image, 58, 51, 64, 59, cream)
        rect(image, 36, 54, 40, 58, dark)
        rect(image, 59, 54, 63, 58, dark)
        polygon(image, [(42, 68), (49, 72), (58, 67), (53, 75), (46, 75)], dark)
    else:
        polygon(image, [(18, 63), (27, 45), (38, 39), (45, 20), (54, 32), (65, 27), (80, 39), (85, 62), (73, 78), (48, 82), (27, 76)], color)
        polygon(image, [(22, 48), (6, 37), (21, 34), (34, 43)], accent)
        polygon(image, [(66, 35), (88, 24), (78, 48)], accent)
        rect(image, 34, 53, 41, 60, cream)
        rect(image, 58, 51, 65, 58, cream)
        rect(image, 36, 55, 40, 59, dark)
        rect(image, 59, 53, 63, 57, dark)
        polygon(image, [(43, 68), (50, 71), (59, 67), (54, 76), (47, 76)], dark)
    if mood == "sleep":
        rect(image, 31, 54, 40, 55, dark)
        rect(image, 58, 53, 66, 54, dark)
        polygon(image, [(48, 69), (54, 69), (51, 72)], dark)
    elif mood == "sick":
        rect(image, 32, 53, 41, 54, dark)
        rect(image, 59, 52, 67, 53, dark)
        polygon(image, [(45, 69), (53, 69), (49, 73)], dark)
        rect(image, 74, 12, 80, 18, (153, 224, 255, 255))
    elif mood == "happy":
        polygon(image, [(42, 66), (50, 72), (59, 65), (53, 76), (46, 76)], (255, 239, 120, 255))
    if mood == "walk":
        rect(image, 27, 77, 39, 83, dark)
        rect(image, 61, 77, 73, 83, dark)
    elif mood == "eat":
        rect(image, 43, 78, 58, 83, accent)
        rect(image, 47, 75, 54, 78, cream)
    elif mood == "training":
        polygon(image, [(49, 9), (54, 20), (66, 20), (57, 27), (60, 39), (49, 32), (38, 39), (41, 27), (32, 20), (44, 20)], (255, 224, 105, 255))
    elif mood == "call":
        rect(image, 76, 10, 86, 21, (255, 243, 183, 255))
        rect(image, 80, 23, 82, 25, (255, 243, 183, 255))
    return image


def save_family(name: str, maker, color, accent) -> None:
    root = OUT / name
    write_png(root / "preview.png", 48, 48, scale(maker("idle", color, accent, 48), 48))
    write_png(root / "portrait.png", 96, 96, maker("idle", color, accent, "idle"))
    for animation in ["idle", "walk", "sleep", "eat", "happy", "sick", "training", "call"]:
        write_png(root / f"{animation}.png", 96, 96, maker(animation, color, accent, animation))


def main() -> None:
    palettes = {
        "moss": ((90, 155, 112, 255), (177, 225, 139, 255)),
        "ember": ((209, 102, 76, 255), (255, 185, 84, 255)),
        "tide": ((74, 143, 185, 255), (151, 222, 221, 255)),
    }
    for name, (color, accent) in palettes.items():
        root = OUT / "eggs" / name
        write_png(root / "preview.png", 48, 48, scale(egg(color, accent, 96), 48))
        write_png(root / "world.png", 96, 96, egg(color, accent, 96))
        write_png(root / "idle.png", 96, 96, egg(color, accent, 96))
        write_png(root / "hatch.png", 96, 96, creature(name, color, accent, "happy", 96))
        save_family(name, creature, color, accent)


if __name__ == "__main__":
    main()
