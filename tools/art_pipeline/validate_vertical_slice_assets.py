"""Validate the generated vertical-slice PNG set and its animation references."""

from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def png_info(path: Path) -> tuple[int, int, int]:
    raw = path.read_bytes()
    if len(raw) < 33 or raw[:8] != PNG_SIGNATURE or raw[12:16] != b"IHDR":
        raise ValueError("invalid PNG signature or IHDR")
    width, height, bit_depth, color_type = struct.unpack(">IIBB", raw[16:26])
    return width, height, color_type


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[2])
    args = parser.parse_args()
    repo = args.repo_root.resolve()
    pack = repo / "game" / "content_packs" / "koalapet.base"
    data_dir = pack / "data"
    referenced: set[Path] = set()
    for path in sorted(data_dir.glob("animation_*.json")):
        document = json.loads(path.read_text(encoding="utf-8"))
        referenced.add(pack / document["preview"])
        referenced.add(pack / document["portrait"])
        for animation in document["world_animations"].values():
            referenced.add(pack / animation["asset"])
    errors: list[str] = []
    for asset in sorted(referenced):
        if not asset.is_file():
            errors.append(f"MISSING {asset.relative_to(repo)}")
            continue
        try:
            width, height, color_type = png_info(asset)
        except (OSError, ValueError) as exc:
            errors.append(f"INVALID {asset.relative_to(repo)}: {exc}")
            continue
        if width < 48 or height < 48:
            errors.append(f"TOO_SMALL {asset.relative_to(repo)}: {width}x{height}")
        if color_type != 6:
            errors.append(f"NO_ALPHA {asset.relative_to(repo)}: color_type={color_type}")
    if errors:
        print("Vertical-slice asset validation failed:")
        print("\n".join(errors))
        return 1
    print(f"Vertical-slice assets passed: {len(referenced)} referenced PNG(s), RGBA, minimum 48x48.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
