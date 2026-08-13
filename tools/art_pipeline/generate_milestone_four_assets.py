#!/usr/bin/env python3
"""Generate deterministic original Milestone 4 development assets."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_vertical_slice_assets import (
    canvas,
    polygon,
    rect,
    scale,
    write_png,
)

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game" / "content_packs" / "koalapet.base" / "assets" / "vertical_slice"


def shape(name: str, mood: str, size: int = 96):
    image = canvas(size)
    dark = (31, 29, 42, 255)
    cream = (255, 232, 183, 255)
    palettes = {
        "moss_bloom": ((104, 171, 119, 255), (226, 232, 125, 255)),
        "moss_bracken": ((67, 116, 83, 255), (183, 222, 104, 255)),
        "ember_dawn": ((234, 128, 69, 255), (255, 228, 112, 255)),
        "ember_cinder": ((116, 63, 66, 255), (238, 111, 62, 255)),
        "tide_glass": ((81, 169, 191, 255), (193, 244, 237, 255)),
        "tide_reed": ((55, 121, 132, 255), (122, 211, 167, 255)),
        "creekling": ((73, 154, 188, 255), (184, 237, 239, 255)),
        "thornlet": ((109, 136, 68, 255), (222, 167, 80, 255)),
        "cinder_moth": ((102, 73, 111, 255), (248, 164, 85, 255)),
        "canopy_guardian": ((80, 91, 74, 255), (222, 191, 108, 255)),
    }
    color, accent = palettes[name]
    if name == "moss_bloom":
        polygon(image, [(18, 71), (22, 43), (36, 34), (38, 17), (48, 29), (58, 12), (64, 31), (80, 35), (86, 61), (72, 80), (42, 84)], color)
        polygon(image, [(30, 34), (20, 18), (39, 25), (48, 10), (55, 28), (76, 18), (65, 39)], accent)
    elif name == "moss_bracken":
        polygon(image, [(16, 74), (26, 35), (39, 43), (44, 14), (54, 38), (72, 18), (68, 44), (88, 34), (78, 74), (60, 86), (29, 82)], color)
        polygon(image, [(40, 46), (24, 29), (43, 34), (53, 8), (59, 35), (79, 21), (66, 52)], accent)
    elif name == "ember_dawn":
        polygon(image, [(15, 72), (23, 43), (38, 35), (45, 12), (55, 35), (70, 18), (69, 40), (87, 49), (78, 77), (52, 86), (26, 80)], color)
        polygon(image, [(43, 38), (21, 25), (42, 26), (50, 7), (57, 28), (79, 23), (64, 43)], accent)
    elif name == "ember_cinder":
        polygon(image, [(12, 77), (20, 42), (34, 34), (39, 18), (49, 28), (61, 6), (67, 31), (82, 39), (91, 63), (78, 84), (43, 88)], color)
        polygon(image, [(51, 30), (57, 4), (65, 27), (84, 31), (69, 46)], accent)
    elif name == "tide_glass":
        polygon(image, [(13, 68), (29, 39), (43, 35), (51, 10), (59, 34), (78, 25), (92, 50), (79, 78), (51, 88), (24, 80)], color)
        polygon(image, [(28, 39), (12, 25), (37, 29), (52, 4), (63, 29), (88, 17), (77, 42)], accent)
    elif name == "tide_reed":
        polygon(image, [(12, 69), (27, 47), (39, 45), (35, 16), (48, 35), (57, 8), (61, 37), (77, 31), (91, 57), (76, 81), (45, 86), (22, 79)], color)
        polygon(image, [(35, 45), (25, 9), (43, 31), (55, 4), (60, 34), (78, 16), (68, 49)], accent)
    elif name == "creekling":
        polygon(image, [(14, 66), (24, 45), (43, 36), (48, 18), (60, 37), (78, 39), (88, 61), (72, 78), (37, 80)], color)
        polygon(image, [(21, 45), (5, 28), (30, 34), (52, 17), (48, 43)], accent)
    elif name == "thornlet":
        polygon(image, [(13, 76), (22, 48), (35, 41), (42, 9), (53, 37), (66, 18), (69, 42), (89, 35), (78, 76), (53, 86), (28, 84)], color)
        polygon(image, [(42, 43), (35, 15), (50, 32), (67, 12), (63, 43)], accent)
    elif name == "cinder_moth":
        polygon(image, [(42, 79), (43, 38), (51, 26), (59, 38), (61, 79)], color)
        polygon(image, [(43, 48), (12, 23), (38, 30), (49, 45)], accent)
        polygon(image, [(59, 48), (91, 23), (66, 30), (53, 45)], accent)
    else:
        polygon(image, [(10, 78), (17, 38), (31, 28), (39, 8), (50, 28), (65, 17), (69, 32), (88, 41), (92, 70), (72, 88), (30, 88)], color)
        polygon(image, [(28, 32), (13, 12), (39, 22), (54, 5), (57, 29), (82, 21), (68, 43)], accent)
    rect(image, 31, 51, 39, 59, cream)
    rect(image, 58, 49, 66, 57, cream)
    rect(image, 34, 54, 38, 58, dark)
    rect(image, 60, 52, 64, 56, dark)
    if mood == "attack":
        polygon(image, [(78, 44), (94, 38), (83, 51)], (255, 239, 120, 255))
    elif mood == "hit":
        rect(image, 76, 13, 83, 20, (255, 164, 105, 255))
    elif mood == "victory":
        polygon(image, [(48, 65), (57, 72), (67, 64), (58, 78), (51, 78)], (255, 239, 120, 255))
    elif mood == "injured":
        rect(image, 36, 53, 42, 54, dark)
        rect(image, 59, 51, 67, 52, dark)
        rect(image, 75, 13, 80, 17, (153, 224, 255, 255))
    else:
        polygon(image, [(42, 68), (50, 72), (59, 67), (53, 75), (46, 75)], dark)
    return image


def save_profile(name: str) -> None:
    root = OUT / ("juveniles" if name in {"moss_bloom", "moss_bracken", "ember_dawn", "ember_cinder", "tide_glass", "tide_reed"} else "enemies") / name
    write_png(root / "preview.png", 48, 48, scale(shape(name, "idle"), 48))
    for animation in ["portrait", "idle", "attack", "hit", "victory", "injured"]:
        write_png(root / f"{animation}.png", 96, 96, shape(name, "idle" if animation == "portrait" else animation))


def main() -> None:
    for name in ["moss_bloom", "moss_bracken", "ember_dawn", "ember_cinder", "tide_glass", "tide_reed", "creekling", "thornlet", "cinder_moth", "canopy_guardian"]:
        save_profile(name)
    dungeon = OUT / "dungeon"
    background = canvas(192)
    rect(background, 0, 0, 191, 191, (31, 58, 63, 255))
    for y in range(30, 150, 24):
        rect(background, 0, y, 191, y + 4, (47, 91, 77, 255))
    for x in range(12, 190, 32):
        polygon(background, [(x, 32), (x + 12, 8), (x + 25, 32)], (67, 111, 76, 255))
    write_png(dungeon / "canopy_background.png", 192, 192, background)
    ground = canvas(192)
    rect(ground, 0, 0, 191, 191, (63, 83, 63, 255))
    for x in range(0, 192, 16):
        rect(ground, x, 12 + (x % 3) * 4, x + 7, 16 + (x % 3) * 4, (99, 130, 74, 255))
    write_png(dungeon / "canopy_ground.png", 192, 192, ground)
    for name, color in {"icon_encounter": (226, 137, 85, 255), "icon_event": (228, 210, 113, 255), "icon_rest": (123, 205, 151, 255), "icon_boss": (185, 115, 182, 255)}.items():
        icon = canvas(64)
        rect(icon, 8, 8, 55, 55, color)
        polygon(icon, [(32, 14), (48, 32), (32, 50), (16, 32)], (31, 29, 42, 255))
        write_png(dungeon / f"{name}.png", 64, 64, icon)
    trophy = canvas(64)
    rect(trophy, 20, 12, 44, 42, (222, 191, 108, 255))
    rect(trophy, 16, 42, 48, 49, (80, 91, 74, 255))
    rect(trophy, 27, 49, 37, 56, (222, 191, 108, 255))
    write_png(OUT / "rewards" / "canopy_trophy.png", 64, 64, trophy)


if __name__ == "__main__":
    main()
