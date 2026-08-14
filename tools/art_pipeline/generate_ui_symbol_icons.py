#!/usr/bin/env python3
"""Deterministically generate the missing coherent 24x24 KoalaPet UI symbol icons.

The AI-generated Prompt 4.5 board covers care, adventure and status subjects but
never produced window controls or several state symbols. Those names previously
reused an unrelated icon (``close`` rendered the injury plaster, ``minimize``
rendered the Minimal-mode glyph, ``discipline`` rendered the training log), which
is the main reason player-facing icons were unreadable.

Every icon here is drawn from the same primitives, the same shared palette ramp,
the same top-left light direction and one automatic 1px outline pass, so the new
symbols stay coherent with each other and sit beside the existing subject icons
without introducing a second visual style.

Run:
    python tools/art_pipeline/generate_ui_symbol_icons.py
    python tools/art_pipeline/generate_ui_symbol_icons.py --check
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ICON_ROOT = ROOT / "game" / "assets_generated" / "ui" / "icons"
MANIFEST = ROOT / "game" / "assets_generated" / "ui" / "symbol-icons.json"
EVIDENCE = ROOT / "docs" / "evidence" / "ui-rescue" / "contact-sheets"

SIZE = 24
OUTLINE = (13, 20, 26, 255)
TRANSPARENT = (0, 0, 0, 0)

# One shared ramp keeps hue families consistent across the whole set.
RAMPS: dict[str, tuple[tuple[int, int, int], ...]] = {
    "parchment": ((255, 246, 219), (243, 226, 184), (198, 179, 137), (139, 124, 92)),
    "gold": ((255, 224, 150), (230, 189, 103), (183, 141, 66), (122, 91, 40)),
    "moss": ((166, 214, 128), (114, 168, 93), (78, 122, 63), (47, 78, 40)),
    "alert": ((247, 160, 141), (227, 107, 88), (176, 74, 60), (112, 44, 35)),
    "sky": ((178, 220, 236), (122, 178, 204), (79, 128, 154), (44, 80, 100)),
    "silver": ((205, 217, 219), (158, 176, 179), (110, 128, 131), (66, 80, 83)),
}

LIGHT = 0
MID = 1
SHADE = 2
DEEP = 3


class Canvas:
    """A tiny deterministic pixel canvas with shape primitives and auto-outline."""

    def __init__(self) -> None:
        self.cells: dict[tuple[int, int], tuple[str, int]] = {}

    def put(self, x: int, y: int, ramp: str, tone: int) -> None:
        if 0 <= x < SIZE and 0 <= y < SIZE:
            self.cells[(x, y)] = (ramp, tone)

    def rect(self, x0: int, y0: int, x1: int, y1: int, ramp: str, tone: int = MID) -> None:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, ramp, tone)

    def disc(self, cx: float, cy: float, radius: float, ramp: str, tone: int = MID) -> None:
        span = int(radius) + 1
        for y in range(int(cy) - span, int(cy) + span + 1):
            for x in range(int(cx) - span, int(cx) + span + 1):
                if (x - cx) ** 2 + (y - cy) ** 2 <= radius * radius:
                    self.put(x, y, ramp, tone)

    def ring(self, cx: float, cy: float, outer: float, inner: float, ramp: str, tone: int = MID) -> None:
        span = int(outer) + 1
        for y in range(int(cy) - span, int(cy) + span + 1):
            for x in range(int(cx) - span, int(cx) + span + 1):
                distance = (x - cx) ** 2 + (y - cy) ** 2
                if inner * inner <= distance <= outer * outer:
                    self.put(x, y, ramp, tone)

    def bar(self, x0: int, y0: int, x1: int, y1: int, width: int, ramp: str, tone: int = MID) -> None:
        steps = max(abs(x1 - x0), abs(y1 - y0))
        for step in range(steps + 1):
            factor = step / steps if steps else 0.0
            cx = round(x0 + (x1 - x0) * factor)
            cy = round(y0 + (y1 - y0) * factor)
            reach = width // 2
            for dy in range(-reach, reach + 1):
                for dx in range(-reach, reach + 1):
                    if abs(dx) + abs(dy) <= reach:
                        self.put(cx + dx, cy + dy, ramp, tone)

    def arrow(self, x0: int, y0: int, x1: int, y1: int, ramp: str, tone: int = MID) -> None:
        """A shaft from the tail to the tip plus a solid diagonal arrow head."""
        self.bar(x0, y0, x1, y1, 3, ramp, tone)
        step_x = 1 if x1 >= x0 else -1
        step_y = 1 if y1 >= y0 else -1
        for depth in range(6):
            self.bar(x1 - step_x * depth, y1, x1, y1 - step_y * depth, 1, ramp, tone)

    def shade(self) -> None:
        """Apply one consistent top-left light direction to every filled pixel."""
        source = dict(self.cells)
        for (x, y), (ramp, tone) in source.items():
            if tone != MID:
                continue
            lit = (x - 1, y - 1) not in source and (x, y - 1) not in source
            dim = (x + 1, y + 1) not in source and (x, y + 1) not in source
            if lit:
                self.cells[(x, y)] = (ramp, LIGHT)
            elif dim:
                self.cells[(x, y)] = (ramp, SHADE)

    def render(self) -> Image.Image:
        image = Image.new("RGBA", (SIZE, SIZE), TRANSPARENT)
        pixels = image.load()
        for (x, y), (ramp, tone) in self.cells.items():
            pixels[x, y] = RAMPS[ramp][tone] + (255,)
        for y in range(SIZE):
            for x in range(SIZE):
                if (x, y) in self.cells:
                    continue
                neighbours = ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
                if any(neighbour in self.cells for neighbour in neighbours):
                    pixels[x, y] = OUTLINE
        return image


def icon_close() -> Canvas:
    canvas = Canvas()
    canvas.bar(6, 6, 17, 17, 5, "parchment")
    canvas.bar(17, 6, 6, 17, 5, "parchment")
    canvas.shade()
    return canvas


def icon_minimize() -> Canvas:
    canvas = Canvas()
    canvas.rect(5, 13, 18, 16, "parchment")
    canvas.shade()
    return canvas


def icon_collapse() -> Canvas:
    canvas = Canvas()
    # Both heads point at the centre, so the glyph reads as "make this smaller".
    canvas.arrow(3, 3, 10, 10, "gold")
    canvas.arrow(20, 20, 13, 13, "gold")
    canvas.shade()
    return canvas


def icon_wake() -> Canvas:
    canvas = Canvas()
    for angle_x, angle_y in ((0, -8), (0, 8), (-8, 0), (8, 0), (-6, -6), (6, -6), (-6, 6), (6, 6)):
        canvas.bar(12 + angle_x // 2, 11 + angle_y // 2, 12 + angle_x, 11 + angle_y, 3, "gold")
    canvas.disc(12, 11, 5.4, "gold")
    canvas.disc(11, 10, 3.2, "parchment")
    canvas.rect(3, 19, 20, 21, "moss")
    canvas.shade()
    return canvas


def icon_sickness() -> Canvas:
    canvas = Canvas()
    canvas.bar(14, 3, 8, 15, 5, "silver")
    canvas.disc(7, 18, 4.2, "alert")
    canvas.bar(13, 5, 8, 14, 1, "alert")
    canvas.shade()
    return canvas


def icon_treatment() -> Canvas:
    canvas = Canvas()
    # A first-aid case reads unambiguously as "treat the injury" and stays
    # distinct from the plaster cross already used for the injury state itself.
    canvas.rect(9, 3, 14, 4, "silver", SHADE)
    canvas.rect(8, 5, 15, 6, "silver", SHADE)
    canvas.rect(2, 7, 21, 20, "parchment")
    canvas.rect(2, 11, 21, 12, "silver", SHADE)
    canvas.rect(10, 9, 13, 18, "alert", SHADE)
    canvas.rect(7, 12, 16, 15, "alert", SHADE)
    canvas.shade()
    return canvas


def icon_call() -> Canvas:
    canvas = Canvas()
    canvas.rect(3, 4, 20, 15, "gold")
    canvas.rect(4, 3, 19, 3, "gold")
    canvas.rect(4, 16, 19, 16, "gold")
    canvas.bar(8, 16, 6, 21, 3, "gold")
    canvas.rect(11, 6, 13, 11, "alert", DEEP)
    canvas.rect(11, 13, 13, 14, "alert", DEEP)
    canvas.shade()
    return canvas


def icon_discipline() -> Canvas:
    canvas = Canvas()
    for y in range(3, 21):
        inset = 0 if y < 13 else int((y - 12) * 1.3)
        canvas.rect(4 + inset, y, 19 - inset, y, "sky")
    canvas.bar(8, 12, 11, 15, 3, "parchment")
    canvas.bar(11, 15, 16, 8, 3, "parchment")
    canvas.shade()
    return canvas


def icon_level() -> Canvas:
    canvas = Canvas()
    for step, y in enumerate(range(4, 12)):
        canvas.rect(11 - step, y, 12 + step, y, "gold")
    canvas.rect(8, 12, 15, 14, "gold")
    canvas.rect(5, 17, 18, 20, "moss")
    canvas.shade()
    return canvas


ICONS = {
    "close": icon_close,
    "minimize": icon_minimize,
    "collapse": icon_collapse,
    "wake": icon_wake,
    "sickness": icon_sickness,
    "treatment": icon_treatment,
    "call": icon_call,
    "discipline": icon_discipline,
    "level": icon_level,
}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build_double_size(check_only: bool) -> list[str]:
    """Emit a crisp 2x copy of every icon for the large primary-action buttons.

    Godot scales a Button icon with the viewport filter, which softens pixel art.
    Exporting an exact nearest-neighbour 48x48 twin keeps large icons sharp
    without introducing a second art style or a runtime filter exception.
    """
    target_root = ICON_ROOT / "x2"
    target_root.mkdir(parents=True, exist_ok=True)
    problems: list[str] = []
    for source in sorted(ICON_ROOT.glob("*.png")):
        with Image.open(source) as image:
            scaled = image.convert("RGBA").resize((SIZE * 2, SIZE * 2), Image.NEAREST)
        target = target_root / source.name
        if check_only:
            if not target.exists():
                problems.append(f"MISSING_2X: {source.stem}")
                continue
            with Image.open(target) as current:
                if current.convert("RGBA").tobytes() != scaled.tobytes():
                    problems.append(f"STALE_2X: {source.stem}")
            continue
        scaled.save(target, optimize=True)
    if not check_only:
        for stale in target_root.glob("*.png"):
            if not (ICON_ROOT / stale.name).exists():
                stale.unlink()
    return problems


def build(check_only: bool) -> int:
    ICON_ROOT.mkdir(parents=True, exist_ok=True)
    records: dict[str, str] = {}
    failures: list[str] = []
    for name, factory in sorted(ICONS.items()):
        image = factory().render()
        if image.size != (SIZE, SIZE):
            raise RuntimeError(f"ICON_GEOMETRY_INVALID: {name}")
        if not image.getbbox():
            raise RuntimeError(f"ICON_EMPTY: {name}")
        alpha = image.getchannel("A")
        if alpha.getextrema()[0] != 0:
            raise RuntimeError(f"ICON_NOT_TRANSPARENT: {name}")
        target = ICON_ROOT / f"{name}.png"
        if check_only:
            if not target.exists():
                failures.append(f"MISSING: {name}")
                continue
            with Image.open(target) as current:
                if current.convert("RGBA").tobytes() != image.tobytes():
                    failures.append(f"STALE: {name}")
            records[name] = digest(target)
            continue
        image.save(target, optimize=True)
        records[name] = digest(target)

    failures.extend(build_double_size(check_only))

    if check_only:
        for line in failures:
            print(line, file=sys.stderr)
        if failures:
            return 1
        print(f"ui symbol icons verified: {len(records)}")
        return 0

    # Written as bytes so the repository keeps LF endings on every host.
    manifest = json.dumps(
        {
            "schema_version": 1,
            "generator": "tools/art_pipeline/generate_ui_symbol_icons.py",
            "icon_size": [SIZE, SIZE],
            "outline_rgba": list(OUTLINE),
            "light_direction": "top_left",
            "icons": records,
        },
        indent="\t",
    )
    MANIFEST.write_bytes((manifest + "\n").encode("utf-8"))
    _write_contact_sheet()
    print(f"ui symbol icons written: {len(records)}")
    return 0


def _write_contact_sheet() -> None:
    names = sorted(ICON_ROOT.glob("*.png"))
    columns = 6
    cell = 72
    label = 16
    rows = (len(names) + columns - 1) // columns
    sheet = Image.new("RGBA", (columns * cell, rows * (cell + label)), (16, 24, 32, 255))
    for index, path in enumerate(names):
        with Image.open(path) as source:
            scaled = source.convert("RGBA").resize((48, 48), Image.NEAREST)
        x = (index % columns) * cell + (cell - 48) // 2
        y = (index // columns) * (cell + label) + 8
        sheet.alpha_composite(scaled, (x, y))
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    sheet.save(EVIDENCE / "ui-icon-set.png", optimize=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify committed icons match the generator")
    args = parser.parse_args()
    return build(args.check)


if __name__ == "__main__":
    raise SystemExit(main())
