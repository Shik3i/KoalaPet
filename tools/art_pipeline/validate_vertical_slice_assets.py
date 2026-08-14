"""Validate the generated vertical-slice PNG set and its animation references."""

from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path

from PIL import Image

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
MAX_ASSET_DIMENSION = 4_096
MAX_ASSET_PIXELS = 16_777_216


def png_info(path: Path) -> tuple[int, int, int]:
    raw = path.read_bytes()
    if len(raw) < 33 or raw[:8] != PNG_SIGNATURE or raw[12:16] != b"IHDR":
        raise ValueError("invalid PNG signature or IHDR")
    width, height, _bit_depth, color_type = struct.unpack(">IIBB", raw[16:26])
    return width, height, color_type


def component_sizes(image: Image.Image) -> list[int]:
    alpha = image.convert("RGBA").getchannel("A")
    active = {(x, y) for y in range(image.height) for x in range(image.width) if alpha.getpixel((x, y)) >= 16}
    sizes: list[int] = []
    while active:
        start = active.pop()
        size = 1
        frontier = [start]
        while frontier:
            x, y = frontier.pop()
            for neighbor in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if neighbor in active:
                    active.remove(neighbor)
                    size += 1
                    frontier.append(neighbor)
        sizes.append(size)
    return sizes


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[2])
    args = parser.parse_args()
    repo = args.repo_root.resolve()
    pack = repo / "game" / "content_packs" / "koalapet.base"
    data_dir = pack / "data"
    referenced: dict[Path, dict] = {}
    required_character = {
        "idle", "idle_look", "idle_playful", "idle_rest", "walk", "turn_left", "turn_right",
        "sleep_enter", "sleep", "sleep_loop", "wake", "eat", "treat", "clean", "training",
        "medicine", "treatment", "attention", "happy", "sick", "injured", "call", "attack",
        "hit", "dodge", "victory", "defeat", "playful_hop", "playful_pounce",
    }
    required_enemy = {"idle", "attack", "hit", "dodge", "defeat"}
    required_egg = {"idle", "hatch", "world"}
    player_minimum_frames = {
        "idle": 4, "idle_look": 6, "idle_playful": 8, "idle_rest": 6, "walk": 8,
        "turn_left": 4, "turn_right": 4, "sleep_enter": 8, "sleep": 4, "sleep_loop": 4,
        "wake": 8, "eat": 8, "treat": 6, "clean": 8, "training": 8, "medicine": 6,
        "treatment": 6, "attention": 6, "happy": 6, "sick": 4, "injured": 4,
        "call": 4, "attack": 6, "hit": 6, "dodge": 6, "victory": 6, "defeat": 6,
        "playful_hop": 6, "playful_pounce": 6,
    }
    enemy_minimum_frames = {"idle": 4, "attack": 6, "hit": 6, "dodge": 5, "defeat": 6}
    looped_player = {"idle", "idle_look", "idle_rest", "walk", "sleep", "sleep_loop", "sick", "injured", "call"}
    required_markers = {
        "attack": {"windup_started", "projectile_release", "impact", "hit_stop", "recovery_started", "animation_complete"},
        "hit": {"impact", "hit_stop", "recovery_started", "animation_complete"},
        "dodge": {"windup_started", "evade_started", "recovery_started", "animation_complete"},
        "sleep_enter": {"settle_started", "eyes_closed", "animation_complete"},
        "wake": {"eyes_opened", "stretch_started", "animation_complete"},
    }
    for path in sorted(data_dir.glob("animation_*.json")):
        document = json.loads(path.read_text(encoding="utf-8"))
        profile_name = path.stem.removeprefix("animation_")
        preview_name = {"moss": "moss_hatchling", "ember": "ember_hatchling", "tide": "tide_hatchling"}.get(profile_name, profile_name)
        names = set(document["world_animations"])
        expected = required_enemy if "animation_enemy_" in path.name else required_egg if "animation_egg_" in path.name else required_character
        missing = expected - names
        if missing:
            raise RuntimeError(f"{path.name} missing animations: {sorted(missing)}")
        referenced[pack / document["preview"]] = {"frames": 1, "kind": "preview"}
        referenced[pack / document["portrait"]] = {"frames": 1, "kind": "portrait"}
        for name, animation in document["world_animations"].items():
            is_enemy = "animation_enemy_" in path.name
            is_egg = "animation_egg_" in path.name
            minimums = enemy_minimum_frames if is_enemy else {} if is_egg else player_minimum_frames
            if name in minimums and int(animation.get("frames", 0)) < minimums[name]:
                raise RuntimeError(f"{path.name} {name} requires at least {minimums[name]} meaningful frames")
            if not is_egg:
                expected_loop = name == "idle" if is_enemy else name in looped_player
                if bool(animation.get("loop", False)) != expected_loop:
                    raise RuntimeError(f"{path.name} {name} loop must be {expected_loop}")
            for key in ["frame_size", "pivot", "ground_anchor", "visual_center", "interaction_bounds", "mirroring_allowed", "event_markers", "source_brief", "provenance", "review_status"]:
                if key not in animation:
                    raise RuntimeError(f"{path.name} animation {name} missing metadata: {key}")
            marker_names = {str(marker.get("event", "")) for marker in animation.get("event_markers", [])}
            if name in required_markers and not required_markers[name].issubset(marker_names):
                raise RuntimeError(f"{path.name} {name} missing event markers: {sorted(required_markers[name] - marker_names)}")
            profile_kind = "enemy" if is_enemy else "egg" if is_egg else "player"
            referenced[pack / animation["asset"]] = {
                "frames": int(animation.get("frames", 1)),
                "kind": "sheet",
                "metadata": animation,
                "name": name,
                "preview_name": preview_name,
                "profile_kind": profile_kind,
            }
    generated = json.loads((repo / "game" / "assets_generated" / "visual-rebuild-manifest.json").read_text(encoding="utf-8"))
    generated_paths = [generated["habitat"]["background"], generated["habitat"]["ground"]]
    generated_paths += list(generated["habitat"]["props"].values()) + list(generated["habitat"]["effects"].values()) + list(generated["icons"].values())
    for relative in generated_paths:
        referenced[repo / relative] = {"frames": 1, "kind": "generated"}
    living = generated.get("living_animation", {})
    for effects in living.get("family_effects", {}).values():
        for name, effect in effects.items():
            referenced[repo / effect["path"]] = {"frames": int(effect["frames"]), "kind": "effect_sheet", "metadata": effect, "name": name}
    errors: list[str] = []
    transparent_count = 0
    for asset in sorted(referenced):
        if not asset.is_file():
            errors.append(f"MISSING {asset.relative_to(repo)}")
            continue
        try:
            width, height, color_type = png_info(asset)
        except (OSError, ValueError) as exc:
            errors.append(f"INVALID {asset.relative_to(repo)}: {exc}")
            continue
        minimum = 24 if referenced[asset]["kind"] == "generated" else 48
        if width < minimum or height < minimum:
            errors.append(f"TOO_SMALL {asset.relative_to(repo)}: {width}x{height}")
        if width > MAX_ASSET_DIMENSION or height > MAX_ASSET_DIMENSION or width * height > MAX_ASSET_PIXELS:
            errors.append(f"TOO_LARGE {asset.relative_to(repo)}: {width}x{height}")
            continue
        if color_type != 6:
            errors.append(f"NO_ALPHA {asset.relative_to(repo)}: color_type={color_type}")
            continue
        info = referenced[asset]
        frames = int(info["frames"])
        if info["kind"] in {"sheet", "effect_sheet"} and frames < 2:
            errors.append(f"PLACEHOLDER_FRAME_COUNT {asset.relative_to(repo)}: frames={frames}")
        if info["kind"] in {"sheet", "effect_sheet"} and width != height * frames:
            errors.append(f"SHEET_GEOMETRY {asset.relative_to(repo)}: {width}x{height}, frames={frames}")
        with Image.open(asset) as image:
            rgba = image.convert("RGBA")
            alpha = rgba.getchannel("A")
            low, high = alpha.getextrema()
            if low < 255:
                transparent_count += 1
            if info["kind"] in {"sheet", "preview", "portrait"} and low == 255:
                errors.append(f"OPAQUE_CHARACTER_CANVAS {asset.relative_to(repo)}")
            if high == 0:
                errors.append(f"EMPTY_ASSET {asset.relative_to(repo)}")
            corners = [rgba.getpixel((0, 0))[3], rgba.getpixel((rgba.width - 1, 0))[3], rgba.getpixel((0, rgba.height - 1))[3], rgba.getpixel((rgba.width - 1, rgba.height - 1))[3]]
            if info["kind"] in {"sheet", "preview", "portrait"} and any(corners):
                errors.append(f"OPAQUE_CORNER {asset.relative_to(repo)}: alpha={corners}")
            if info["kind"] in {"sheet", "effect_sheet"}:
                metadata = info["metadata"]
                if list(metadata.get("frame_size", [])) != [height, height]:
                    errors.append(f"FRAME_SIZE_METADATA {asset.relative_to(repo)}: {metadata.get('frame_size')}")
                ground = metadata.get("ground_anchor", metadata.get("pivot", []))
                pivot = metadata.get("pivot", [])
                if info["kind"] == "sheet" and (len(ground) != 2 or len(pivot) != 2 or ground != pivot):
                    errors.append(f"GROUND_PIVOT_METADATA {asset.relative_to(repo)}: ground={ground}, pivot={pivot}")
                unique_frames: set[bytes] = set()
                for frame_index in range(frames):
                    frame = rgba.crop((frame_index * height, 0, (frame_index + 1) * height, height))
                    unique_frames.add(frame.tobytes())
                    bbox = frame.getchannel("A").point(lambda value: 255 if value >= 16 else 0).getbbox()
                    if bbox is None:
                        errors.append(f"EMPTY_FRAME {asset.relative_to(repo)}: frame={frame_index}")
                    elif info["kind"] == "sheet" and len(ground) == 2 and bbox[3] > int(ground[1]):
                        errors.append(f"GROUND_OVERFLOW {asset.relative_to(repo)}: frame={frame_index}, bottom={bbox[3]}, anchor={ground[1]}")
                    if info["name"] == "walk" and frames >= 6:
                        sizes = component_sizes(frame)
                        if sizes and min(sizes) < max(20, round(max(sizes) * 0.004)):
                            errors.append(f"ISOLATED_PIXELS {asset.relative_to(repo)}: frame={frame_index}, components={sorted(sizes)[:5]}")
                if info["name"] == "walk" and frames >= 6:
                    preview = repo / "docs" / "evidence" / "animation-polish" / "previews" / f"{info['preview_name']}-walk.gif"
                    if not preview.is_file():
                        errors.append(f"MISSING_PREVIEW {preview.relative_to(repo)}")
                if info["kind"] == "sheet" and info.get("profile_kind") in {"player", "enemy"} and info["name"] in (player_minimum_frames | enemy_minimum_frames) and len(unique_frames) < 3:
                    errors.append(f"INSUFFICIENT_FRAME_VARIATION {asset.relative_to(repo)}: unique={len(unique_frames)}")
    evidence_root = repo / "docs" / "evidence" / "living-animation"
    for required in [
        evidence_root / "reels" / "moss-family.gif",
        evidence_root / "reels" / "ember-family.gif",
        evidence_root / "reels" / "tide-family.gif",
        evidence_root / "reels" / "all-player-highlights.gif",
        evidence_root / "contact-sheets" / "moss-players.png",
        evidence_root / "contact-sheets" / "ember-players.png",
        evidence_root / "contact-sheets" / "tide-players.png",
        evidence_root / "contact-sheets" / "enemies.png",
    ]:
        if not required.is_file():
            errors.append(f"MISSING_EVIDENCE {required.relative_to(repo)}")
    if errors:
        print("Vertical-slice asset validation failed:")
        print("\n".join(errors))
        return 1
    print(f"Vertical-slice assets passed: {len(referenced)} PNG(s), animation geometry valid, {transparent_count} contain transparent pixels.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
