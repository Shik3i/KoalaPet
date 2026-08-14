#!/usr/bin/env python3
"""Build the Prompt 4.7 living-animation tranche from preserved source poses."""

from __future__ import annotations

import hashlib
import json
from collections import deque
from pathlib import Path

import process_visual_rebuild_assets as baseline
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / "game" / "content_packs" / "koalapet.base"
PACK_ASSETS = PACK / "assets" / "vertical_slice"
DATA = PACK / "data"
SOURCE = ROOT / "art_source" / "sources" / "visual-rebuild"
VFX_SOURCE = ROOT / "art_source" / "sources" / "living-animation" / "family-effects.png"
GENERATED = ROOT / "game" / "assets_generated"
EVIDENCE = ROOT / "docs" / "evidence" / "living-animation"
PROVENANCE = ROOT / "art_source" / "provenance" / "living-animation.json"

FRAME_SIZE = 128
GROUND_ANCHOR = (64, 116)
PROVENANCE_REF = "art_source/provenance/living-animation.json"

PLAYERS = baseline.CHARACTERS
PLAYER_MANIFESTS = baseline.CHARACTER_MANIFESTS
ENEMIES = baseline.ENEMIES
ENEMY_MANIFESTS = baseline.ENEMY_MANIFESTS

FAMILIES = {
    "moss": ["moss_hatchling", "moss_bloom", "moss_bracken"],
    "ember": ["ember_hatchling", "ember_dawn", "ember_cinder"],
    "tide": ["tide_hatchling", "tide_glass", "tide_reed"],
}

LOOPS = {"idle", "idle_look", "idle_rest", "sleep", "sleep_loop", "sick", "injured", "call"}
FPS = {
    "idle": 4,
    "idle_look": 4,
    "idle_playful": 7,
    "idle_rest": 4,
    "walk": 10,
    "turn_left": 8,
    "turn_right": 8,
    "sleep_enter": 7,
    "sleep": 3,
    "sleep_loop": 3,
    "wake": 7,
    "eat": 8,
    "treat": 7,
    "clean": 8,
    "training": 8,
    "medicine": 7,
    "treatment": 7,
    "attention": 7,
    "happy": 7,
    "sick": 3,
    "injured": 3,
    "call": 4,
    "attack": 10,
    "hit": 10,
    "dodge": 10,
    "victory": 8,
    "defeat": 7,
    "playful_hop": 9,
    "playful_pounce": 10,
}

PLAYER_SPECS: dict[str, list[tuple[int, str]]] = {
    "idle": [(0, "still"), (0, "breathe_up"), (12, "look"), (0, "breathe_down")],
    "idle_look": [(0, "still"), (12, "look_left"), (12, "look"), (0, "still"), (12, "look_right"), (0, "still")],
    "idle_playful": [(0, "still"), (3, "anticipate"), (14, "lift"), (10, "lift_high"), (14, "settle"), (3, "look"), (12, "breathe_up"), (0, "still")],
    "idle_rest": [(0, "still"), (11, "look"), (4, "settle"), (4, "breathe_down"), (4, "breathe_up"), (0, "still")],
    "turn_left": [(0, "still"), (13, "turn_narrow"), (13, "turn_flip"), (0, "flip")],
    "turn_right": [(0, "flip"), (13, "turn_flip"), (13, "turn_narrow"), (0, "still")],
    "sleep_enter": [(0, "still"), (12, "look"), (1, "anticipate"), (1, "lower"), (4, "lower"), (4, "breathe_down"), (4, "breathe_up"), (4, "still")],
    "sleep": [(4, "still"), (4, "breathe_down"), (4, "still"), (4, "breathe_up")],
    "sleep_loop": [(4, "still"), (4, "breathe_down"), (4, "still"), (4, "breathe_up")],
    "wake": [(4, "still"), (4, "breathe_up"), (1, "lift"), (11, "look"), (12, "stretch"), (3, "settle"), (0, "breathe_up"), (0, "still")],
    "eat": [(0, "still"), (1, "anticipate"), (2, "lower"), (2, "bite"), (2, "chew"), (3, "settle"), (12, "breathe_up"), (0, "still")],
    "treat": [(0, "still"), (11, "look"), (2, "bite"), (3, "lift"), (14, "lift_high"), (3, "settle"), (0, "still")],
    "clean": [(0, "still"), (1, "anticipate"), (3, "shake_left"), (3, "shake_right"), (3, "lift"), (14, "settle"), (10, "look"), (0, "still")],
    "training": [(0, "still"), (7, "anticipate"), (7, "strike_left"), (8, "commit"), (7, "strike_right"), (10, "lift"), (3, "settle"), (0, "still")],
    "medicine": [(5, "still"), (11, "look"), (6, "anticipate"), (6, "settle"), (3, "lift"), (12, "breathe_up"), (0, "still")],
    "treatment": [(6, "still"), (6, "anticipate"), (6, "shake_left"), (3, "lift"), (14, "settle"), (12, "breathe_up"), (0, "still")],
    "attention": [(11, "still"), (11, "look"), (3, "lift"), (14, "lift_high"), (10, "settle"), (3, "breathe_up"), (0, "still")],
    "happy": [(0, "still"), (3, "lift"), (14, "lift_high"), (10, "settle"), (14, "lift"), (3, "settle"), (0, "still")],
    "sick": [(5, "still"), (5, "breathe_down"), (5, "still"), (5, "breathe_up")],
    "injured": [(6, "still"), (6, "breathe_down"), (6, "still"), (6, "breathe_up")],
    "call": [(11, "still"), (11, "look_left"), (12, "look_right"), (11, "still")],
    "attack": [(0, "still"), (1, "anticipate"), (8, "windup"), (8, "commit"), (8, "strike_right"), (9, "follow"), (13, "recovery"), (0, "still")],
    "hit": [(0, "still"), (9, "impact"), (9, "compress"), (6, "recoil"), (6, "settle"), (12, "recovery"), (0, "still")],
    "dodge": [(0, "still"), (1, "anticipate"), (13, "dodge_left"), (8, "dodge_right"), (13, "dodge_left"), (12, "recovery"), (0, "still")],
    "victory": [(0, "still"), (3, "anticipate"), (14, "lift"), (10, "lift_high"), (10, "settle"), (14, "lift"), (3, "recovery"), (0, "still")],
    "defeat": [(0, "still"), (9, "impact"), (6, "recoil"), (6, "compress"), (4, "lower"), (6, "settle"), (6, "still"), (6, "breathe_down")],
    "playful_hop": [(0, "still"), (1, "anticipate"), (3, "lift"), (14, "lift_high"), (10, "lift"), (14, "settle"), (3, "recovery"), (0, "still")],
    "playful_pounce": [(0, "still"), (1, "anticipate"), (8, "windup"), (8, "dodge_right"), (14, "lift_high"), (3, "settle"), (12, "recovery"), (0, "still")],
}

ENEMY_SPECS: dict[str, list[tuple[int, str]]] = {
    "idle": [(0, "still"), (1, "breathe_up"), (0, "still"), (1, "breathe_down")],
    "attack": [(0, "still"), (1, "anticipate"), (2, "windup"), (2, "commit"), (2, "strike_right"), (3, "follow"), (1, "recovery"), (0, "still")],
    "hit": [(0, "still"), (3, "impact"), (3, "compress"), (4, "recoil"), (3, "recovery"), (0, "still")],
    "dodge": [(0, "still"), (1, "anticipate"), (2, "dodge_left"), (1, "dodge_right"), (1, "recovery"), (0, "still")],
    "defeat": [(0, "still"), (3, "impact"), (4, "recoil"), (4, "compress"), (4, "settle"), (4, "still"), (4, "breathe_down"), (4, "still")],
}

VFX_NAMES = {
    "moss": ["leaf_slash", "root_burst", "pollen_sparkle", "impact"],
    "ember": ["spark_trail", "flame_burst", "ember_particles", "impact"],
    "tide": ["splash", "bubble_projectile", "wave_arc", "impact"],
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def relative(path: Path) -> str:
    return path.resolve().relative_to(ROOT.resolve()).as_posix()


def clean_frame(frame: Image.Image) -> Image.Image:
    return baseline.remove_isolated_components(baseline.clean_transparent_rgb(frame), 12)


def remove_source_cell_bleed(frame: Image.Image) -> Image.Image:
    """Remove narrow neighbor-cell fragments without stripping nearby effects."""
    output = frame.copy().convert("RGBA")
    alpha = output.getchannel("A")
    active = {(x, y) for y in range(output.height) for x in range(output.width) if alpha.getpixel((x, y)) >= 16}
    components: list[set[tuple[int, int]]] = []
    while active:
        start = active.pop()
        component = {start}
        frontier = [start]
        while frontier:
            x, y = frontier.pop()
            for neighbor in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if neighbor in active:
                    active.remove(neighbor)
                    component.add(neighbor)
                    frontier.append(neighbor)
        components.append(component)
    if not components:
        return output
    largest = max(components, key=len)
    largest_bounds = (
        min(x for x, _y in largest),
        max(x for x, _y in largest) + 1,
    )
    pixels = output.load()
    for component in components:
        if component is largest or len(component) > len(largest) * 0.1:
            continue
        left = min(x for x, _y in component)
        right = max(x for x, _y in component) + 1
        remote_left = left <= 20 and right <= largest_bounds[0] + 1
        remote_right = right >= 108 and left >= largest_bounds[1] - 1
        if not (remote_left or remote_right):
            continue
        for x, y in component:
            pixels[x, y] = (0, 0, 0, 0)
    return baseline.clean_transparent_rgb(output)


def transform_pose(frame: Image.Image, motion: str) -> Image.Image:
    if motion == "still":
        return frame.copy()
    if motion == "flip":
        return frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    if motion == "turn_flip":
        return anchored_scale(frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT), 0.72, 1.0)
    if motion == "turn_narrow":
        return anchored_scale(frame, 0.72, 1.0)
    values = {
        "breathe_up": (0, -1, 0, 0, 1.0, 1.0),
        "breathe_down": (0, 1, 0, 0, 1.0, 0.98),
        "look": (1, 0, 0, 0, 1.0, 1.0),
        "look_left": (-2, 0, 0, 0, 1.0, 1.0),
        "look_right": (2, 0, 0, 0, 1.0, 1.0),
        "anticipate": (-2, 2, 1, 0, 1.04, 0.96),
        "lower": (0, 2, 0, 0, 1.04, 0.94),
        "lift": (0, -3, 0, 0, 0.98, 1.02),
        "lift_high": (1, -6, -1, -1, 0.96, 1.04),
        "settle": (0, 1, 0, 0, 1.02, 0.98),
        "stretch": (2, -2, -1, 0, 1.06, 0.98),
        "bite": (2, 2, -1, 0, 1.02, 0.96),
        "chew": (-1, 1, 1, 0, 1.0, 0.98),
        "shake_left": (-3, 0, 2, 0, 1.0, 1.0),
        "shake_right": (3, 0, -2, 0, 1.0, 1.0),
        "strike_left": (-3, -1, 1, 0, 1.04, 0.98),
        "strike_right": (4, -1, -1, 0, 1.06, 0.98),
        "windup": (-4, 1, 1, 0, 1.02, 0.96),
        "commit": (4, -2, -1, 0, 1.06, 1.0),
        "follow": (3, 1, -1, 0, 1.04, 0.98),
        "impact": (-4, 0, 2, 0, 0.98, 0.96),
        "compress": (-2, 3, 2, 0, 1.06, 0.90),
        "recoil": (-3, 1, 1, 0, 0.96, 0.96),
        "recovery": (1, 0, -1, 0, 1.0, 1.0),
        "dodge_left": (-6, -2, 2, 0, 0.96, 0.98),
        "dodge_right": (6, -3, -2, 0, 0.96, 1.0),
    }
    upper_x, upper_y, lower_x, lower_y, scale_x, scale_y = values[motion]
    scaled = anchored_scale(frame, scale_x, scale_y)
    return articulate(scaled, upper_x, upper_y, lower_x, lower_y)


def anchored_scale(frame: Image.Image, scale_x: float, scale_y: float) -> Image.Image:
    bbox = baseline.alpha_bbox(frame)
    sprite = frame.crop(bbox)
    width = max(1, round(sprite.width * scale_x))
    height = max(1, round(sprite.height * scale_y))
    sprite = sprite.resize((width, height), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(sprite, (GROUND_ANCHOR[0] - width // 2, GROUND_ANCHOR[1] - height))
    return clean_frame(canvas)


def articulate(frame: Image.Image, upper_x: int, upper_y: int, lower_x: int, lower_y: int) -> Image.Image:
    split = 76
    overlap = 8
    canvas = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    upper = frame.crop((0, 0, FRAME_SIZE, split + overlap))
    lower = frame.crop((0, split - overlap, FRAME_SIZE, FRAME_SIZE))
    canvas.alpha_composite(lower, (lower_x, split - overlap + lower_y))
    canvas.alpha_composite(upper, (upper_x, upper_y))
    return clean_frame(canvas)


def player_poses(name: str) -> list[Image.Image]:
    board = Image.open(SOURCE / f"{name}.png").convert("RGBA")
    cells = baseline.grid_cells(board, 4, 4)
    # Generated pose boards bleed neighboring silhouettes across some 4x4 cell
    # edges. Twelve source pixels remove those fragments while retaining the
    # accepted silhouette padding in every reviewed pose.
    cells = [cell.crop((12, 12, cell.width - 12, cell.height - 12)) for cell in cells]
    return [remove_source_cell_bleed(baseline.normalize_cell(cell, FRAME_SIZE, 104)) for cell in cells]


def enemy_poses(name: str) -> list[Image.Image]:
    board = baseline.remove_magenta(Image.open(SOURCE / f"{name}.png").convert("RGBA"))
    return [baseline.normalize_cell(cell, FRAME_SIZE, 104) for cell in baseline.grid_cells(board, 3, 2)]


def build_sequence(poses: list[Image.Image], spec: list[tuple[int, str]]) -> list[Image.Image]:
    return [transform_pose(poses[index], motion) for index, motion in spec]


def marker_set(name: str, frames: int) -> list[dict]:
    last = frames - 1
    markers: dict[str, list[tuple[int, str]]] = {
        "walk": [(0, "foot_contact"), (4, "opposite_foot_contact")],
        "attack": [(0, "windup_started"), (3, "projectile_release"), (4, "impact"), (5, "hit_stop"), (6, "recovery_started"), (last, "animation_complete")],
        "hit": [(1, "impact"), (2, "hit_stop"), (4, "recovery_started"), (last, "animation_complete")],
        "dodge": [(0, "windup_started"), (2, "evade_started"), (4, "recovery_started"), (last, "animation_complete")],
        "sleep_enter": [(2, "settle_started"), (5, "eyes_closed"), (last, "animation_complete")],
        "wake": [(1, "eyes_opened"), (4, "stretch_started"), (last, "animation_complete")],
        "eat": [(2, "action_contact"), (4, "swallow"), (6, "recovery_started"), (last, "animation_complete")],
        "treat": [(2, "action_contact"), (4, "reaction"), (last, "animation_complete")],
        "clean": [(1, "action_contact"), (3, "shake_dry"), (5, "reaction"), (last, "animation_complete")],
        "training": [(1, "windup_started"), (3, "action_contact"), (5, "recovery_started"), (last, "animation_complete")],
        "medicine": [(2, "action_contact"), (4, "recovery_effect"), (last, "animation_complete")],
        "treatment": [(1, "action_contact"), (4, "recovery_effect"), (last, "animation_complete")],
        "attention": [(1, "attention_noticed"), (3, "reaction"), (last, "animation_complete")],
        "victory": [(2, "reaction"), (last, "animation_complete")],
        "defeat": [(1, "impact"), (4, "collapse_complete"), (last, "animation_complete")],
        "playful_hop": [(1, "windup_started"), (3, "airborne"), (5, "landed"), (last, "animation_complete")],
        "playful_pounce": [(1, "windup_started"), (3, "airborne"), (5, "landed"), (last, "animation_complete")],
        "turn_left": [(last, "animation_complete")],
        "turn_right": [(last, "animation_complete")],
        "idle_playful": [(last, "animation_complete")],
        "idle_rest": [(last, "animation_complete")],
        "happy": [(last, "animation_complete")],
    }
    return [{"frame": min(frame, last), "event": event} for frame, event in markers.get(name, [])]


def animation_entry(path: Path, name: str, loop: bool) -> dict:
    with Image.open(path) as image:
        frames = image.width // image.height
    return {
        "asset": path.resolve().relative_to(PACK.resolve()).as_posix(),
        "frames": frames,
        "fps": FPS[name],
        "loop": loop,
        "frame_size": [FRAME_SIZE, FRAME_SIZE],
        "pivot": list(GROUND_ANCHOR),
        "ground_anchor": list(GROUND_ANCHOR),
        "visual_center": [64, 68],
        "interaction_bounds": [14, 12, 100, 104],
        "effect_bounds": [0, 0, 128, 128],
        "mirroring_allowed": name not in {"turn_left", "turn_right"},
        "event_markers": marker_set(name, frames),
        "source_brief": "Sequential form-specific living animation with articulated anticipation, contact and recovery",
        "provenance": PROVENANCE_REF,
        "review_status": "PROVISIONAL_REVIEWED",
    }


def save_gif(frames: list[Image.Image], path: Path, fps: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    frames[0].save(temporary, format="GIF", save_all=True, append_images=frames[1:], duration=round(1000 / fps), loop=0, disposal=2, optimize=False)
    try:
        temporary.replace(path)
    except PermissionError:
        # The desktop review renderer can hold an existing GIF open on Windows.
        # Preserve that valid evidence file; the dedicated acceptance package is
        # generated separately from the same current runtime sheets.
        temporary.unlink(missing_ok=True)
        if not path.is_file():
            raise
        print(f"Review GIF locked; retained existing file: {relative(path)}")


def process_players(outputs: list[Path]) -> dict[str, dict[str, list[Image.Image]]]:
    all_frames: dict[str, dict[str, list[Image.Image]]] = {}
    for name, root in PLAYERS.items():
        poses = player_poses(name)
        sequences: dict[str, list[Image.Image]] = {}
        for animation, spec in PLAYER_SPECS.items():
            frames = build_sequence(poses, spec)
            path = root / f"{animation}.png"
            baseline.save_sheet(frames, path)
            sequences[animation] = frames
            outputs.append(path)
        walk_path = root / "walk.png"
        if not walk_path.is_file():
            raise FileNotFoundError(f"Missing accepted walk cycle: {walk_path}")
        all_frames[name] = sequences
        manifest = DATA / PLAYER_MANIFESTS[name]
        document = json.loads(manifest.read_text(encoding="utf-8"))
        walk_entry = document["world_animations"]["walk"]
        document["world_animations"] = {
            animation: animation_entry(root / f"{animation}.png", animation, animation in LOOPS)
            for animation in PLAYER_SPECS
        }
        document["world_animations"]["walk"] = walk_entry
        manifest.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        outputs.append(manifest)
    return all_frames


def process_enemies(outputs: list[Path]) -> dict[str, dict[str, list[Image.Image]]]:
    all_frames: dict[str, dict[str, list[Image.Image]]] = {}
    for name, root in ENEMIES.items():
        poses = enemy_poses(name)
        sequences: dict[str, list[Image.Image]] = {}
        for animation, spec in ENEMY_SPECS.items():
            frames = build_sequence(poses, spec)
            path = root / f"{animation}.png"
            baseline.save_sheet(frames, path)
            sequences[animation] = frames
            outputs.append(path)
        all_frames[name] = sequences
        manifest = DATA / ENEMY_MANIFESTS[name]
        document = json.loads(manifest.read_text(encoding="utf-8"))
        document["world_animations"] = {
            animation: animation_entry(root / f"{animation}.png", animation, animation == "idle")
            for animation in ENEMY_SPECS
        }
        manifest.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        outputs.append(manifest)
    return all_frames


def remove_connected_checkerboard(image: Image.Image) -> Image.Image:
    output = image.convert("RGBA")
    pixels = output.load()
    width, height = output.size

    def background(x: int, y: int) -> bool:
        red, green, blue, _alpha = pixels[x, y]
        return max(red, green, blue) - min(red, green, blue) <= 20 and min(red, green, blue) >= 220

    pending: deque[tuple[int, int]] = deque()
    seen: set[tuple[int, int]] = set()
    for x in range(width):
        pending.extend(((x, 0), (x, height - 1)))
    for y in range(height):
        pending.extend(((0, y), (width - 1, y)))
    while pending:
        x, y = pending.popleft()
        if (x, y) in seen or not background(x, y):
            continue
        seen.add((x, y))
        pixels[x, y] = (0, 0, 0, 0)
        for next_x, next_y in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= next_x < width and 0 <= next_y < height:
                pending.append((next_x, next_y))
    return baseline.clean_transparent_rgb(output)


def effect_frames(effect: Image.Image, kind: str) -> list[Image.Image]:
    frames: list[Image.Image] = []
    for index, scale in enumerate((0.35, 0.58, 0.82, 1.0, 0.88, 0.62)):
        frame = anchored_scale(effect, scale, scale)
        if kind in {"leaf_slash", "spark_trail", "bubble_projectile", "wave_arc"}:
            frame = articulate(frame, index - 2, 0, 0, 0)
        alpha = frame.getchannel("A")
        if index >= 4:
            alpha = alpha.point(lambda value, factor=(0.68 if index == 4 else 0.35): round(value * factor))
            frame.putalpha(alpha)
        frames.append(baseline.clean_transparent_rgb(frame))
    return frames


def process_vfx(outputs: list[Path]) -> dict:
    if not VFX_SOURCE.is_file():
        raise FileNotFoundError(f"Missing generated VFX source: {VFX_SOURCE}")
    board = remove_connected_checkerboard(Image.open(VFX_SOURCE))
    cells = baseline.grid_cells(board, 4, 3)
    manifest: dict[str, dict[str, dict]] = {}
    for row, (family, names) in enumerate(VFX_NAMES.items()):
        family_entries: dict[str, dict] = {}
        for column, name in enumerate(names):
            cell = baseline.normalize_cell(cells[row * 4 + column], FRAME_SIZE, 112, 48)
            frames = effect_frames(cell, name)
            path = GENERATED / "vfx" / family / f"{name}.png"
            baseline.save_sheet(frames, path)
            outputs.append(path)
            family_entries[name] = {
                "path": relative(path),
                "frames": len(frames),
                "fps": 12,
                "loop": False,
                "frame_size": [128, 128],
                "pivot": [64, 64],
                "event_markers": [{"frame": 3, "event": "impact"}, {"frame": 5, "event": "animation_complete"}],
            }
        manifest[family] = family_entries
    return manifest


def draw_contact_sheet(group: dict[str, dict[str, list[Image.Image]]], animations: list[str], path: Path) -> None:
    labels = list(group)
    width = 176 + 8 * FRAME_SIZE
    rows = len(labels) * len(animations)
    sheet = Image.new("RGBA", (width, rows * FRAME_SIZE), (16, 24, 32, 255))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    row = 0
    for label in labels:
        for animation in animations:
            frames = group[label][animation]
            display = (frames + [frames[-1]] * 8)[:8]
            draw.text((8, row * FRAME_SIZE + 48), f"{label} / {animation}", fill=(243, 226, 184, 255), font=font)
            for index, frame in enumerate(display):
                sheet.alpha_composite(frame, (176 + index * FRAME_SIZE, row * FRAME_SIZE))
            row += 1
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path, optimize=True)


def sequence_cycle(sequences: dict[str, list[Image.Image]]) -> list[Image.Image]:
    order = ["idle", "idle_look", "idle_playful", "sleep_enter", "sleep_loop", "wake", "attack", "hit", "dodge", "victory", "defeat"]
    frames: list[Image.Image] = []
    for name in order:
        frames.extend(sequences[name])
    return frames


def montage_frames(groups: list[list[Image.Image]], columns: int, cell_size: int = 128) -> list[Image.Image]:
    rows = (len(groups) + columns - 1) // columns
    length = max(len(group) for group in groups)
    result: list[Image.Image] = []
    for index in range(length):
        frame = Image.new("RGBA", (columns * cell_size, rows * cell_size), (16, 24, 32, 255))
        for item, group in enumerate(groups):
            frame.alpha_composite(group[index % len(group)], ((item % columns) * cell_size, (item // columns) * cell_size))
        result.append(frame)
    return result


def create_evidence(players: dict[str, dict[str, list[Image.Image]]], enemies: dict[str, dict[str, list[Image.Image]]], outputs: list[Path]) -> None:
    review_animations = ["idle", "idle_look", "idle_playful", "sleep_enter", "sleep_loop", "wake", "eat", "clean", "training", "medicine", "attack", "hit", "dodge", "victory", "defeat"]
    for family, names in FAMILIES.items():
        subset = {name: players[name] for name in names}
        sheet = EVIDENCE / "contact-sheets" / f"{family}-players.png"
        draw_contact_sheet(subset, review_animations, sheet)
        outputs.append(sheet)
        reel = montage_frames([sequence_cycle(players[name]) for name in names], 3)
        gif = EVIDENCE / "reels" / f"{family}-family.gif"
        save_gif(reel, gif, 10)
        outputs.append(gif)
    enemy_sheet = EVIDENCE / "contact-sheets" / "enemies.png"
    draw_contact_sheet(enemies, ["idle", "attack", "hit", "dodge", "defeat"], enemy_sheet)
    outputs.append(enemy_sheet)
    highlight = montage_frames([sequence_cycle(players[name]) for name in PLAYERS], 3)
    highlight_path = EVIDENCE / "reels" / "all-player-highlights.gif"
    save_gif(highlight, highlight_path, 10)
    outputs.append(highlight_path)


def update_visual_manifest(vfx: dict, outputs: list[Path]) -> None:
    path = GENERATED / "visual-rebuild-manifest.json"
    document = json.loads(path.read_text(encoding="utf-8"))
    document["living_animation"] = {
        "schema_version": 1,
        "family_effects": vfx,
        "family_profiles": {
            "koalapet.base:moss_family": {
                "effect_set": "moss", "attack_effect": "leaf_slash", "impact_effect": "impact",
                "ambient_interactions": [
                    {"anchor": "plant", "animation": "idle_look", "duration": 1.4},
                    {"anchor": "training", "animation": "idle_playful", "duration": 1.2},
                ],
            },
            "koalapet.base:ember_family": {
                "effect_set": "ember", "attack_effect": "flame_burst", "impact_effect": "impact",
                "ambient_interactions": [
                    {"anchor": "training", "animation": "idle_look", "duration": 1.3},
                    {"anchor": "bed", "animation": "idle_rest", "duration": 1.5},
                ],
            },
            "koalapet.base:tide_family": {
                "effect_set": "tide", "attack_effect": "bubble_projectile", "impact_effect": "impact",
                "ambient_interactions": [
                    {"anchor": "bath", "animation": "idle_playful", "duration": 1.3},
                    {"anchor": "feeding_bowl", "animation": "idle_look", "duration": 1.2},
                ],
            },
        },
        "encounter_profiles": {
            "koalapet.base:creekling_encounter": {"effect_set": "tide", "attack_effect": "splash", "impact_effect": "impact"},
            "koalapet.base:thornlet_encounter": {"effect_set": "moss", "attack_effect": "root_burst", "impact_effect": "impact"},
            "koalapet.base:cinder_moth_encounter": {"effect_set": "ember", "attack_effect": "spark_trail", "impact_effect": "impact"},
            "koalapet.base:canopy_guardian": {"effect_set": "moss", "attack_effect": "root_burst", "impact_effect": "impact"},
        },
        "ambient_frequency": ["low", "normal", "high"],
        "source": relative(VFX_SOURCE),
    }
    path.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    outputs.append(path)


def write_provenance(outputs: list[Path]) -> None:
    sources = [SOURCE / f"{name}.png" for name in PLAYERS]
    sources += [SOURCE / f"{name}.png" for name in ENEMIES]
    sources.append(VFX_SOURCE)
    payload = {
        "schema_version": 1,
        "source_snapshot_date_utc": "2026-08-14",
        "style_bible": "docs/ART_STYLE_BIBLE.md",
        "prompt_record": "art_source/prompts/living-animation-expansion.md",
        "processing_command": "python tools/art_pipeline/process_living_animation_assets.py",
        "processing_script_sha256": sha256(Path(__file__)),
        "sources": [{"path": relative(path), "sha256": sha256(path)} for path in sources],
        "vfx_generation_tool": "Codex built-in image generation",
        "vfx_generation_model": "built-in model version not exposed",
        "vfx_alpha_cleanup": "deterministic border-connected neutral checker removal; transparent runtime outputs validated separately",
        "outputs": [{"path": relative(path), "sha256": sha256(path)} for path in sorted(set(outputs))],
        "license_status": "UNDECIDED",
        "approval_status": "PROVISIONAL_PRODUCT_REVIEW",
    }
    PROVENANCE.parent.mkdir(parents=True, exist_ok=True)
    PROVENANCE.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> int:
    outputs: list[Path] = []
    players = process_players(outputs)
    enemies = process_enemies(outputs)
    vfx = process_vfx(outputs)
    update_visual_manifest(vfx, outputs)
    create_evidence(players, enemies, outputs)
    write_provenance(outputs)
    print(f"Living animation assets processed: {len(outputs)} runtime/evidence files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
