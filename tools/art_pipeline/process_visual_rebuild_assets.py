#!/usr/bin/env python3
"""Process Prompt 4.5 source boards into deterministic runtime pixel assets."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SOURCE = ROOT / "art_source" / "sources" / "visual-rebuild"
PACK_ASSETS = ROOT / "game" / "content_packs" / "koalapet.base" / "assets" / "vertical_slice"
GENERATED = ROOT / "game" / "assets_generated"
EVIDENCE = ROOT / "docs" / "evidence" / "visual-rebuild" / "contact-sheets"
ANIMATION_SOURCE = ROOT / "art_source" / "sources" / "animation-polish"
ANIMATION_EVIDENCE = ROOT / "docs" / "evidence" / "animation-polish"
PROVENANCE = ROOT / "art_source" / "provenance" / "visual-rebuild.json"

FRAME_SIZE = 128
PREVIEW_SIZE = 64
PORTRAIT_SIZE = 96
ICON_SIZE = 24

CHARACTER_CELL_ORDER = [
    "idle",
    "walk",
    "eat",
    "happy",
    "sleep",
    "sick",
    "injured",
    "training",
    "attack",
    "hit",
    "victory",
    "call",
    "idle_alt",
    "walk_alt",
    "happy_alt",
    "care_alt",
]

CHARACTER_ANIMATIONS = {
    "idle": [0, 12],
    "walk": [1, 13],
    "eat": [2],
    "happy": [3, 14],
    "sleep": [4],
    "sick": [5],
    "injured": [6],
    "training": [7],
    "attack": [8],
    "hit": [9],
    "victory": [10],
    "call": [11, 15],
}

CHARACTERS = {
    "moss_hatchling": PACK_ASSETS / "moss",
    "ember_hatchling": PACK_ASSETS / "ember",
    "tide_hatchling": PACK_ASSETS / "tide",
    "moss_bloom": PACK_ASSETS / "juveniles" / "moss_bloom",
    "moss_bracken": PACK_ASSETS / "juveniles" / "moss_bracken",
    "ember_dawn": PACK_ASSETS / "juveniles" / "ember_dawn",
    "ember_cinder": PACK_ASSETS / "juveniles" / "ember_cinder",
    "tide_glass": PACK_ASSETS / "juveniles" / "tide_glass",
    "tide_reed": PACK_ASSETS / "juveniles" / "tide_reed",
}

CHARACTER_MANIFESTS = {
    "moss_hatchling": "animation_moss.json",
    "ember_hatchling": "animation_ember.json",
    "tide_hatchling": "animation_tide.json",
    "moss_bloom": "animation_moss_bloom.json",
    "moss_bracken": "animation_moss_bracken.json",
    "ember_dawn": "animation_ember_dawn.json",
    "ember_cinder": "animation_ember_cinder.json",
    "tide_glass": "animation_tide_glass.json",
    "tide_reed": "animation_tide_reed.json",
}

EGGS = {
    "moss": 0,
    "ember": 1,
    "tide": 2,
}

ENEMIES = {
    "creekling": PACK_ASSETS / "enemies" / "creekling",
    "thornlet": PACK_ASSETS / "enemies" / "thornlet",
    "cinder_moth": PACK_ASSETS / "enemies" / "cinder_moth",
    "canopy_guardian": PACK_ASSETS / "enemies" / "canopy_guardian",
}

ENEMY_MANIFESTS = {
    "creekling": "animation_enemy_creekling.json",
    "thornlet": "animation_enemy_thornlet.json",
    "cinder_moth": "animation_enemy_cinder_moth.json",
    "canopy_guardian": "animation_enemy_canopy_guardian.json",
}

ANIMATION_FPS = {
    "idle": 3,
    "walk": 10,
    "eat": 6,
    "happy": 6,
    "sleep": 2,
    "sick": 2,
    "injured": 2,
    "training": 8,
    "attack": 10,
    "hit": 10,
    "victory": 6,
    "call": 4,
    "defeat": 8,
    "hatch": 10,
}

WALK_SOURCE_ROWS = {
    "walk-moss-family.png": ["moss_hatchling", "moss_bloom", "moss_bracken"],
    "walk-ember-family.png": ["ember_hatchling", "ember_dawn", "ember_cinder"],
    "walk-tide-family.png": ["tide_hatchling", "tide_glass", "tide_reed"],
}

GROUND_ANCHOR = (64, 116)
PIVOT = (64, 116)
VISUAL_CENTER = (64, 68)
INTERACTION_BOUNDS = (14, 12, 100, 108)

PROP_NAMES = ["sleeping_den", "bath_basin", "feed_table", "training_log", "plants", "trophy_shelf", "lantern", "storage_chest"]
EFFECT_NAMES = ["foreground_grass", "wildflowers", "hanging_leaves", "warm_light", "night_wash", "dust_motes", "heart", "urgent_call"]
ICON_NAMES = [
    "satiety",
    "mood",
    "energy",
    "hygiene",
    "sleep",
    "health",
    "feed",
    "treat",
    "clean",
    "train",
    "medicine",
    "injury",
    "battle",
    "dungeon",
    "rewards",
    "expand",
    "minimal",
    "settings",
    "inventory",
    "codex",
    "evolution",
    "aggressive",
    "balanced",
    "defensive",
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def relative(path: Path) -> str:
    return path.resolve().relative_to(ROOT.resolve()).as_posix()


def load_source(source_dir: Path, cleaned_dir: Path | None, name: str, keyed: bool = False) -> tuple[Image.Image, Path, str]:
    source = source_dir / f"{name}.png"
    if not source.is_file():
        raise FileNotFoundError(f"Missing source board: {source}")
    if keyed and cleaned_dir is not None and (cleaned_dir / f"{name}.png").is_file():
        cleaned = cleaned_dir / f"{name}.png"
        cleanup = f"installed remove_chroma_key.py output sha256={sha256(cleaned)}"
        return Image.open(cleaned).convert("RGBA"), source, cleanup
    image = Image.open(source).convert("RGBA")
    return (remove_magenta(image) if keyed else image), source, "embedded deterministic key removal" if keyed else "source alpha"


def remove_magenta(image: Image.Image) -> Image.Image:
    output = image.copy()
    pixels = output.load()
    for y in range(output.height):
        for x in range(output.width):
            red, green, blue, alpha = pixels[x, y]
            distance = ((red - 255) ** 2 + green**2 + (blue - 255) ** 2) ** 0.5
            if distance <= 18:
                pixels[x, y] = (0, 0, 0, 0)
            elif distance < 120 and red > green * 1.8 and blue > green * 1.8:
                kept_alpha = int(alpha * (distance - 18) / 102)
                pixels[x, y] = (min(red, green * 2), green, min(blue, green * 2), kept_alpha)
    return output


def grid_cells(image: Image.Image, columns: int, rows: int) -> list[Image.Image]:
    cells: list[Image.Image] = []
    for row in range(rows):
        top = round(row * image.height / rows)
        bottom = round((row + 1) * image.height / rows)
        for column in range(columns):
            left = round(column * image.width / columns)
            right = round((column + 1) * image.width / columns)
            cells.append(image.crop((left, top, right, bottom)))
    return cells


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A")
    bbox = alpha.point(lambda value: 255 if value >= 16 else 0).getbbox()
    if bbox is None:
        raise ValueError("Source cell contains no opaque pixels")
    return bbox


def pixel_reduce(image: Image.Image, size: tuple[int, int], colors: int = 64) -> Image.Image:
    resized = image.resize(size, Image.Resampling.BOX)
    alpha = resized.getchannel("A")
    rgb = resized.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    rgb.putalpha(alpha.point(lambda value: 0 if value < 8 else value))
    return rgb


def clean_transparent_rgb(image: Image.Image) -> Image.Image:
    output = image.copy().convert("RGBA")
    pixels = output.load()
    for y in range(output.height):
        for x in range(output.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha < 8:
                pixels[x, y] = (0, 0, 0, 0)
            elif alpha < 255:
                pixels[x, y] = (red, green, blue, alpha)
    return output


def remove_isolated_components(image: Image.Image, minimum_pixels: int = 20) -> Image.Image:
    output = image.copy().convert("RGBA")
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
    largest = max(len(component) for component in components)
    threshold = max(minimum_pixels, round(largest * 0.004))
    pixels = output.load()
    for component in components:
        if len(component) >= threshold:
            continue
        for x, y in component:
            pixels[x, y] = (0, 0, 0, 0)
    return output


def normalize_cell(cell: Image.Image, canvas_size: int, max_extent: int, colors: int = 64) -> Image.Image:
    cropped = cell.crop(alpha_bbox(cell))
    scale = min(max_extent / cropped.width, max_extent / cropped.height)
    width = max(1, round(cropped.width * scale))
    height = max(1, round(cropped.height * scale))
    sprite = pixel_reduce(cropped, (width, height), colors)
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    x = (canvas_size - width) // 2
    ground = min(canvas_size - 4, round(canvas_size * GROUND_ANCHOR[1] / FRAME_SIZE))
    y = ground - height
    canvas.alpha_composite(sprite, (x, y))
    return clean_transparent_rgb(canvas)


def normalize_walk_row(cells: list[Image.Image]) -> list[Image.Image]:
    cropped = [cell.crop(alpha_bbox(cell)) for cell in cells]
    maximum_width = max(frame.width for frame in cropped)
    maximum_height = max(frame.height for frame in cropped)
    scale = min(104 / maximum_width, 104 / maximum_height)
    result: list[Image.Image] = []
    for frame in cropped:
        width = max(1, round(frame.width * scale))
        height = max(1, round(frame.height * scale))
        sprite = pixel_reduce(frame, (width, height), 64)
        canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
        x = GROUND_ANCHOR[0] - width // 2
        y = GROUND_ANCHOR[1] - height
        canvas.alpha_composite(sprite, (x, y))
        result.append(remove_isolated_components(clean_transparent_rgb(canvas)))
    return result


def process_walk_cycles(outputs: list[Path], source_records: list[dict]) -> None:
    preview_pairs: list[tuple[str, Path]] = []
    for source_name, character_names in WALK_SOURCE_ROWS.items():
        source = ANIMATION_SOURCE / source_name
        if not source.is_file():
            raise FileNotFoundError(f"Missing sequential walk source: {source}")
        board = clean_transparent_rgb(Image.open(source).convert("RGBA"))
        rows = grid_cells(board, 8, 3)
        for row_index, character_name in enumerate(character_names):
            frames = normalize_walk_row(rows[row_index * 8:(row_index + 1) * 8])
            destination = CHARACTERS[character_name] / "walk.png"
            save_sheet(frames, destination)
            outputs.append(destination)
            preview = ANIMATION_EVIDENCE / "previews" / f"{character_name}-walk.gif"
            preview.parent.mkdir(parents=True, exist_ok=True)
            frames[0].save(preview, save_all=True, append_images=frames[1:], duration=100, loop=0, disposal=2, optimize=False)
            outputs.append(preview)
            preview_pairs.append((character_name, destination))
        source_records.append(source_record(
            source.stem,
            source,
            "source alpha plus deterministic baseline normalization",
            [CHARACTERS[name] for name in character_names],
            "art_source/prompts/animation-polish-walk-cycles.md",
        ))
    contact = ANIMATION_EVIDENCE / "contact-sheets" / "walk-cycles.png"
    draw_animation_contact_sheet(preview_pairs, contact)
    outputs.append(contact)


def draw_animation_contact_sheet(paths: list[tuple[str, Path]], destination: Path) -> None:
    cell_width = FRAME_SIZE * 8
    label_width = 176
    row_height = FRAME_SIZE
    sheet = Image.new("RGBA", (label_width + cell_width, row_height * len(paths)), (16, 24, 32, 255))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for row, (label, path) in enumerate(paths):
        draw.text((12, row * row_height + 54), label, fill=(243, 226, 184, 255), font=font)
        sheet.alpha_composite(Image.open(path).convert("RGBA"), (label_width, row * row_height))
    destination.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(destination, optimize=True)


def shifted_frame(frame: Image.Image, animation: str) -> Image.Image:
    offsets = {
        "sleep": (1, 0),
        "sick": (0, 0),
        "injured": (1, 0),
        "eat": (0, 0),
        "training": (1, -1),
        "attack": (2, 0),
        "hit": (-2, 0),
        "victory": (0, -2),
    }
    dx, dy = offsets.get(animation, (0, -1))
    result = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    result.alpha_composite(frame, (dx, dy))
    return result


def save_sheet(frames: list[Image.Image], path: Path) -> None:
    sheet = Image.new("RGBA", (FRAME_SIZE * len(frames), FRAME_SIZE), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (index * FRAME_SIZE, 0))
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path, optimize=True)


def save_preview(frame: Image.Image, path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    normalized = normalize_cell(frame, size, size - 8, 48)
    normalized.save(path, optimize=True)


def process_characters(source_dir: Path, cleaned_dir: Path | None, outputs: list[Path], source_records: list[dict]) -> None:
    for source_name, output_dir in CHARACTERS.items():
        board, source, cleanup = load_source(source_dir, cleaned_dir, source_name)
        cells = [normalize_cell(cell, FRAME_SIZE, 112) for cell in grid_cells(board, 4, 4)]
        for animation, indices in CHARACTER_ANIMATIONS.items():
            frames = [cells[index] for index in indices]
            if len(frames) == 1:
                frames.append(shifted_frame(frames[0], animation))
            path = output_dir / f"{animation}.png"
            save_sheet(frames, path)
            outputs.append(path)
        save_preview(cells[0], output_dir / "preview.png", PREVIEW_SIZE)
        save_preview(cells[0], output_dir / "portrait.png", PORTRAIT_SIZE)
        outputs.extend([output_dir / "preview.png", output_dir / "portrait.png"])
        source_records.append(source_record(source_name, source, cleanup, [output_dir]))


def process_eggs(source_dir: Path, cleaned_dir: Path | None, outputs: list[Path], source_records: list[dict]) -> None:
    board, source, cleanup = load_source(source_dir, cleaned_dir, "starter_eggs")
    cells = grid_cells(board, 4, 3)
    for name, row in EGGS.items():
        root = PACK_ASSETS / "eggs" / name
        normalized = [normalize_cell(cells[row * 4 + index], FRAME_SIZE, 108) for index in range(4)]
        save_sheet(normalized[:2], root / "idle.png")
        save_sheet(normalized[2:], root / "hatch.png")
        save_sheet(normalized[:2], root / "world.png")
        save_preview(normalized[0], root / "preview.png", PREVIEW_SIZE)
        outputs.extend([root / "idle.png", root / "hatch.png", root / "world.png", root / "preview.png"])
    source_records.append(source_record("starter_eggs", source, cleanup, [PACK_ASSETS / "eggs"]))


def process_enemies(source_dir: Path, cleaned_dir: Path | None, outputs: list[Path], source_records: list[dict]) -> None:
    for name, output_dir in ENEMIES.items():
        board, source, cleanup = load_source(source_dir, cleaned_dir, name, keyed=True)
        cells = [normalize_cell(cell, FRAME_SIZE, 112) for cell in grid_cells(board, 3, 2)]
        animation_cells = {"idle": [0, 1], "attack": [2], "hit": [3], "defeat": [4], "victory": [5], "injured": [3]}
        for animation, indices in animation_cells.items():
            frames = [cells[index] for index in indices]
            if len(frames) == 1:
                frames.append(shifted_frame(frames[0], animation))
            path = output_dir / f"{animation}.png"
            save_sheet(frames, path)
            outputs.append(path)
        save_preview(cells[5], output_dir / "preview.png", PREVIEW_SIZE)
        save_preview(cells[5], output_dir / "portrait.png", PORTRAIT_SIZE)
        outputs.extend([output_dir / "preview.png", output_dir / "portrait.png"])
        source_records.append(source_record(name, source, cleanup, [output_dir]))


def process_habitat(source_dir: Path, cleaned_dir: Path | None, outputs: list[Path], source_records: list[dict]) -> None:
    habitat = GENERATED / "habitat" / "quiet_canopy"
    background, background_source, cleanup = load_source(source_dir, cleaned_dir, "habitat_background")
    background = pixel_reduce(background, (512, 192), 96)
    habitat.mkdir(parents=True, exist_ok=True)
    background.save(habitat / "background_day.png", optimize=True)
    outputs.append(habitat / "background_day.png")
    source_records.append(source_record("habitat_background", background_source, cleanup, [habitat / "background_day.png"]))

    ground, ground_source, cleanup = load_source(source_dir, cleaned_dir, "habitat_ground")
    ground = normalize_wide(ground, (512, 96), (500, 92), 72)
    ground.save(habitat / "ground.png", optimize=True)
    outputs.append(habitat / "ground.png")
    source_records.append(source_record("habitat_ground", ground_source, cleanup, [habitat / "ground.png"]))

    props, props_source, cleanup = load_source(source_dir, cleaned_dir, "habitat_props", keyed=True)
    for name, cell in zip(PROP_NAMES, grid_cells(props, 4, 2), strict=True):
        path = habitat / "props" / f"{name}.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        normalize_cell(cell, 128, 120, 72).save(path, optimize=True)
        outputs.append(path)
    source_records.append(source_record("habitat_props", props_source, cleanup, [habitat / "props"]))

    effects, effects_source, cleanup = load_source(source_dir, cleaned_dir, "habitat_effects", keyed=True)
    for name, cell in zip(EFFECT_NAMES, grid_cells(effects, 4, 2), strict=True):
        path = habitat / "effects" / f"{name}.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        normalize_cell(cell, 128, 120, 64).save(path, optimize=True)
        outputs.append(path)
    source_records.append(source_record("habitat_effects", effects_source, cleanup, [habitat / "effects"]))


def normalize_wide(image: Image.Image, canvas_size: tuple[int, int], max_size: tuple[int, int], colors: int) -> Image.Image:
    cropped = image.crop(alpha_bbox(image))
    scale = min(max_size[0] / cropped.width, max_size[1] / cropped.height)
    width = max(1, round(cropped.width * scale))
    height = max(1, round(cropped.height * scale))
    asset = pixel_reduce(cropped, (width, height), colors)
    canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    canvas.alpha_composite(asset, ((canvas_size[0] - width) // 2, canvas_size[1] - height))
    return canvas


def process_icons(source_dir: Path, cleaned_dir: Path | None, outputs: list[Path], source_records: list[dict]) -> None:
    board, source, cleanup = load_source(source_dir, cleaned_dir, "ui_icons", keyed=True)
    cells = grid_cells(board, 6, 4)
    icon_root = GENERATED / "ui" / "icons"
    for name, cell in zip(ICON_NAMES, cells, strict=True):
        path = icon_root / f"{name}.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        normalize_cell(cell, ICON_SIZE, 22, 24).save(path, optimize=True)
        outputs.append(path)
    source_records.append(source_record("ui_icons", source, cleanup, [icon_root]))


def animation_entry(path: Path, name: str, loop: bool | None = None) -> dict:
    relative_asset = path.resolve().relative_to((ROOT / "game" / "content_packs" / "koalapet.base").resolve()).as_posix()
    with Image.open(path) as image:
        frames = image.width // image.height
    value = {
        "asset": relative_asset,
        "frames": frames,
        "fps": ANIMATION_FPS.get(name, 4),
        "loop": bool(loop),
        "frame_size": [FRAME_SIZE, FRAME_SIZE],
        "pivot": list(PIVOT),
        "ground_anchor": list(GROUND_ANCHOR),
        "visual_center": list(VISUAL_CENTER),
        "interaction_bounds": list(INTERACTION_BOUNDS),
        "effect_bounds": [0, 0, FRAME_SIZE, FRAME_SIZE],
        "mirroring_allowed": True,
        "event_markers": ([{"frame": 0, "event": "foot_contact"}, {"frame": 4, "event": "opposite_foot_contact"}] if name == "walk" else ([{"frame": 1, "event": name}] if not loop else [])),
        "source_brief": "Sequential in-place locomotion" if name == "walk" else f"Provisional {name} presentation pose",
        "provenance": "art_source/provenance/visual-rebuild.json",
        "review_status": "PROVISIONAL_REVIEWED",
    }
    return value


def update_animation_manifests(outputs: list[Path]) -> None:
    data_root = ROOT / "game" / "content_packs" / "koalapet.base" / "data"
    looped = {"idle", "walk", "sleep", "sick", "injured", "call"}
    for source_name, manifest_name in CHARACTER_MANIFESTS.items():
        path = data_root / manifest_name
        document = json.loads(path.read_text(encoding="utf-8"))
        asset_root = CHARACTERS[source_name]
        document["world_animations"] = {
            name: animation_entry(asset_root / f"{name}.png", name, name in looped)
            for name in CHARACTER_ANIMATIONS
        }
        path.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        outputs.append(path)
    for egg in EGGS:
        path = data_root / f"animation_egg_{egg}.json"
        document = json.loads(path.read_text(encoding="utf-8"))
        asset_root = PACK_ASSETS / "eggs" / egg
        document["world_animations"] = {
            "idle": animation_entry(asset_root / "idle.png", "idle", True),
            "hatch": animation_entry(asset_root / "hatch.png", "hatch", False),
            "world": animation_entry(asset_root / "world.png", "walk", True),
        }
        path.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        outputs.append(path)
    for enemy, manifest_name in ENEMY_MANIFESTS.items():
        path = data_root / manifest_name
        document = json.loads(path.read_text(encoding="utf-8"))
        asset_root = ENEMIES[enemy]
        document["world_animations"] = {
            name: animation_entry(asset_root / f"{name}.png", name, name in {"idle", "injured", "victory"})
            for name in ["idle", "attack", "hit", "defeat", "victory", "injured"]
        }
        path.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        outputs.append(path)


def write_visual_manifest(outputs: list[Path]) -> None:
    habitat_root = GENERATED / "habitat" / "quiet_canopy"
    icon_root = GENERATED / "ui" / "icons"
    payload = {
        "schema_version": 1,
        "character_frame_size": [FRAME_SIZE, FRAME_SIZE],
        "preview_size": [PREVIEW_SIZE, PREVIEW_SIZE],
        "portrait_size": [PORTRAIT_SIZE, PORTRAIT_SIZE],
        "icon_size": [ICON_SIZE, ICON_SIZE],
        "habitat": {
            "size": [512, 192],
            "layer_order": ["background", "ground", "rear_structures", "large_furniture", "small_props", "functional_stations", "pet", "foreground", "lighting", "ambient_effects"],
            "background": relative(habitat_root / "background_day.png"),
            "ground": relative(habitat_root / "ground.png"),
            "props": {name: relative(habitat_root / "props" / f"{name}.png") for name in PROP_NAMES},
            "effects": {name: relative(habitat_root / "effects" / f"{name}.png") for name in EFFECT_NAMES},
        },
        "icons": {name: relative(icon_root / f"{name}.png") for name in ICON_NAMES},
    }
    path = GENERATED / "visual-rebuild-manifest.json"
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    outputs.append(path)


def source_record(
    name: str,
    source: Path,
    cleanup: str,
    targets: list[Path],
    prompt_file: str = "art_source/prompts/visual-rebuild-assets.md",
) -> dict:
    return {
        "asset_group": name,
        "source_file": relative(source),
        "source_sha256": sha256(source),
        "generation_tool": "Codex built-in image generation",
        "generation_model": "built-in model version not exposed",
        "prompt_file": prompt_file,
        "cleanup": cleanup,
        "target_roots": [relative(path) for path in targets],
        "review_status": "PROVISIONAL_REVIEWED",
        "license_status": "UNDECIDED",
    }


def draw_contact_sheet(paths: list[tuple[str, Path]], destination: Path, columns: int, cell_size: int = 184) -> None:
    rows = (len(paths) + columns - 1) // columns
    sheet = Image.new("RGBA", (columns * cell_size, rows * cell_size), (16, 24, 32, 255))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for index, (label, path) in enumerate(paths):
        x = (index % columns) * cell_size
        y = (index // columns) * cell_size
        image = Image.open(path).convert("RGBA")
        image.thumbnail((128, 128), Image.Resampling.NEAREST)
        sheet.alpha_composite(image, (x + (cell_size - image.width) // 2, y + 12))
        draw.text((x + 8, y + 148), label, fill=(243, 226, 184, 255), font=font)
    destination.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(destination, optimize=True)


def create_contact_sheets(outputs: list[Path]) -> None:
    character_paths = [(name, root / "preview.png") for name, root in CHARACTERS.items()]
    draw_contact_sheet(character_paths, EVIDENCE / "characters.png", 3)
    enemy_paths = [(name, root / "preview.png") for name, root in ENEMIES.items()]
    draw_contact_sheet(enemy_paths, EVIDENCE / "enemies.png", 4)
    icon_paths = [(name, GENERATED / "ui" / "icons" / f"{name}.png") for name in ICON_NAMES]
    draw_contact_sheet(icon_paths, EVIDENCE / "ui-icons.png", 6, 112)

    habitat = GENERATED / "habitat" / "quiet_canopy"
    scene = Image.open(habitat / "background_day.png").convert("RGBA")
    ground = Image.open(habitat / "ground.png").convert("RGBA")
    scene.alpha_composite(ground, (0, 96))
    anchors = {
        "sleeping_den": (0, 54),
        "bath_basin": (84, 64),
        "feed_table": (198, 66),
        "training_log": (382, 58),
        "plants": (14, 54),
        "trophy_shelf": (310, 40),
        "lantern": (354, 4),
        "storage_chest": (420, 70),
    }
    for name, position in anchors.items():
        scene.alpha_composite(Image.open(habitat / "props" / f"{name}.png").convert("RGBA"), position)
    preview = scene.resize((1024, 384), Image.Resampling.NEAREST)
    preview.save(EVIDENCE / "habitat-day.png", optimize=True)
    outputs.extend([EVIDENCE / "characters.png", EVIDENCE / "enemies.png", EVIDENCE / "ui-icons.png", EVIDENCE / "habitat-day.png"])


def write_provenance(source_records: list[dict], outputs: list[Path]) -> None:
    payload = {
        "schema_version": 1,
        "source_snapshot_date_utc": "2026-08-13",
        "style_bible": "docs/ART_STYLE_BIBLE.md",
        "prompt_record": "art_source/prompts/visual-rebuild-assets.md",
        "supplemental_prompt_records": ["art_source/prompts/animation-polish-walk-cycles.md"],
        "processing_command": "python tools/art_pipeline/process_visual_rebuild_assets.py",
        "processing_script_sha256": sha256(Path(__file__)),
        "source_groups": source_records,
        "outputs": [{"path": relative(path), "sha256": sha256(path)} for path in sorted(set(outputs))],
        "license_status": "UNDECIDED",
        "approval_status": "PROVISIONAL_PRODUCT_REVIEW",
    }
    PROVENANCE.parent.mkdir(parents=True, exist_ok=True)
    PROVENANCE.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--cleaned-dir", type=Path, help="Explicit optional keyed-board override directory")
    args = parser.parse_args()
    source_dir = args.source_dir.resolve()
    cleaned_dir = args.cleaned_dir.resolve() if args.cleaned_dir is not None else None
    outputs: list[Path] = []
    source_records: list[dict] = []
    process_characters(source_dir, cleaned_dir, outputs, source_records)
    process_walk_cycles(outputs, source_records)
    process_eggs(source_dir, cleaned_dir, outputs, source_records)
    process_enemies(source_dir, cleaned_dir, outputs, source_records)
    process_habitat(source_dir, cleaned_dir, outputs, source_records)
    process_icons(source_dir, cleaned_dir, outputs, source_records)
    update_animation_manifests(outputs)
    write_visual_manifest(outputs)
    create_contact_sheets(outputs)
    write_provenance(source_records, outputs)
    print(f"Visual rebuild assets processed: {len(outputs)} runtime/evidence files from {len(source_records)} source groups.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
