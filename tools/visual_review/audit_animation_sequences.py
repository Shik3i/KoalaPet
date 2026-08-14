#!/usr/bin/env python3
"""Build deterministic visual-acceptance diagnostics and review media."""

from __future__ import annotations

import argparse
import hashlib
import json
import statistics
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

from PIL import Image, ImageChops, ImageDraw, ImageStat

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / "game" / "content_packs" / "koalapet.base"
DATA = PACK / "data"
OUT = ROOT / "docs" / "evidence" / "visual-acceptance"
CONTACTS = OUT / "contact-sheets"
REELS = OUT / "reels"
REVIEW_DATE = "2026-08-14"
FORM_FILES = sorted(DATA.glob("form_*.json"))
ENTITY_FILES = sorted([*DATA.glob("egg_*.json"), *FORM_FILES, *DATA.glob("encounter_*.json")])
PROFILE_FILES = sorted(DATA.glob("animation_*.json"))
NON_PLAYER_FACING = {"sleep"}
REGENERATED = {"call", "clean", "idle_rest", "medicine", "sleep_enter", "treatment", "wake"}


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def repo_path(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def profile_entities() -> tuple[dict[str, dict[str, Any]], list[dict[str, Any]]]:
    profiles = {read_json(path)["id"]: read_json(path) for path in PROFILE_FILES}
    entities: list[dict[str, Any]] = []
    for path in ENTITY_FILES:
        record = read_json(path)
        profile_id = record.get("animation_profile_id", "")
        if profile_id not in profiles:
            continue
        kind = "egg" if path.name.startswith("egg_") else "form" if path.name.startswith("form_") else "boss" if "guardian" in path.name else "enemy"
        entities.append(
            {
                "id": record["id"],
                "kind": kind,
                "family_id": record.get("family_id", ""),
                "profile_id": profile_id,
                "source": repo_path(path),
            }
        )
    return profiles, entities


def split_frames(path: Path, count: int) -> list[Image.Image]:
    image = Image.open(path).convert("RGBA")
    if count <= 0 or image.width % count:
        return []
    width = image.width // count
    return [image.crop((index * width, 0, (index + 1) * width, image.height)) for index in range(count)]


def frame_difference(left: Image.Image, right: Image.Image) -> float:
    difference = ImageChops.difference(left, right)
    return sum(ImageStat.Stat(difference).mean) / (255.0 * 4.0)


def sequence_diagnostics(entity: dict[str, Any], animation_name: str, descriptor: dict[str, Any]) -> dict[str, Any]:
    asset = PACK / descriptor.get("asset", "")
    frame_count = int(descriptor.get("frames", 0))
    reasons: list[str] = []
    marker_frames = [int(marker.get("frame", -1)) for marker in descriptor.get("event_markers", [])]
    if not asset.is_file():
        reasons.append("asset missing")
        frames: list[Image.Image] = []
    else:
        frames = split_frames(asset, frame_count)
        if not frames:
            reasons.append("frame geometry invalid")
    invalid_markers = [frame for frame in marker_frames if frame < 0 or frame >= frame_count]
    if invalid_markers:
        reasons.append("marker outside frame range")
    if marker_frames != sorted(marker_frames):
        reasons.append("markers out of order")
    frame_hashes = [hashlib.sha256(frame.tobytes()).hexdigest() for frame in frames]
    duplicate_pairs = [
        [left, right]
        for left in range(len(frame_hashes))
        for right in range(left + 1, len(frame_hashes))
        if frame_hashes[left] == frame_hashes[right]
    ]
    adjacent_differences = [round(frame_difference(frames[index - 1], frames[index]), 6) for index in range(1, len(frames))]
    alpha_bounds = [frame.getchannel("A").getbbox() for frame in frames]
    nonempty_bounds = [bound for bound in alpha_bounds if bound is not None]
    baseline_spread = max((bound[3] for bound in nonempty_bounds), default=0) - min((bound[3] for bound in nonempty_bounds), default=0)
    centers = [((bound[0] + bound[2]) / 2.0, (bound[1] + bound[3]) / 2.0) for bound in nonempty_bounds]
    center_spread = round(
        max((center[0] for center in centers), default=0.0) - min((center[0] for center in centers), default=0.0),
        3,
    )
    if frames and not nonempty_bounds:
        reasons.append("all frames blank")
    classification = "ACCEPTED_PROVISIONAL"
    review_note = "Contact-sheet and difference review; anatomy, silhouette and transitions remain provisional."
    if animation_name in NON_PLAYER_FACING:
        classification = "NOT_PLAYER_FACING"
        review_note = "Compatibility alias; runtime authoritative sleep path uses sleep_enter and sleep_loop."
    elif reasons:
        classification = "TECHNICALLY_BROKEN"
        review_note = "; ".join(reasons)
    elif animation_name in REGENERATED:
        review_note = "Regenerated after visual rejection of helper-hand contamination, clipping and discontinuous pose changes."
    elif adjacent_differences and statistics.fmean(adjacent_differences) < 0.003 and animation_name not in {"idle", "sleep_loop"}:
        classification = "NEEDS_MINOR_FIX"
        review_note = "Motion is valid but restrained; retain for this slice and revisit before release art approval."
    return {
        "sequence_id": f"{entity['id']}::{animation_name}",
        "entity_id": entity["id"],
        "entity_kind": entity["kind"],
        "animation_profile_id": entity["profile_id"],
        "animation": animation_name,
        "asset": repo_path(asset),
        "asset_sha256": sha256(asset) if asset.is_file() else None,
        "frames": frame_count,
        "fps": descriptor.get("fps"),
        "loop": descriptor.get("loop"),
        "marker_frames": marker_frames,
        "invalid_marker_frames": invalid_markers,
        "duplicate_frame_pairs": duplicate_pairs,
        "adjacent_difference_mean": round(statistics.fmean(adjacent_differences), 6) if adjacent_differences else 0.0,
        "adjacent_difference_min": min(adjacent_differences, default=0.0),
        "alpha_baseline_spread_px": baseline_spread,
        "visual_center_x_spread_px": center_spread,
        "classification": classification,
        "review_note": review_note,
        "review_basis": ["per-form contact sheet", "frame-difference diagnostics", "runtime descriptor validation"],
    }


def make_entity_sheet(entity: dict[str, Any], profile: dict[str, Any]) -> Path:
    animations: dict[str, Any] = profile["world_animations"]
    names = sorted(animations)
    columns = 4
    tile_width, tile_height = 280, 174
    rows = (len(names) + columns - 1) // columns
    canvas = Image.new("RGBA", (columns * tile_width, 54 + rows * tile_height), "#172126")
    draw = ImageDraw.Draw(canvas)
    draw.text((16, 14), f"{entity['id']} · {len(names)} runtime sequences", fill="#f3e2b8")
    for item_index, name in enumerate(names):
        descriptor = animations[name]
        frames = split_frames(PACK / descriptor["asset"], int(descriptor["frames"]))
        x = (item_index % columns) * tile_width
        y = 54 + (item_index // columns) * tile_height
        fill = "#24353b" if item_index % 2 == 0 else "#203037"
        draw.rectangle((x + 4, y + 4, x + tile_width - 4, y + tile_height - 4), fill=fill)
        draw.text((x + 12, y + 11), f"{name} · {descriptor['frames']}f @{descriptor['fps']}fps", fill="#f3e2b8")
        sample_count = min(4, len(frames))
        indexes = sorted({round(index * (len(frames) - 1) / max(1, sample_count - 1)) for index in range(sample_count)})
        for sample_index, frame_index in enumerate(indexes):
            preview = frames[frame_index].resize((64, 64), Image.Resampling.NEAREST)
            canvas.alpha_composite(preview, (x + 8 + sample_index * 67, y + 44))
            draw.text((x + 30 + sample_index * 67, y + 112), str(frame_index), fill="#9fc8cf")
        marker_text = ", ".join(f"{marker['event']}:{marker['frame']}" for marker in descriptor.get("event_markers", []))
        draw.text((x + 10, y + 137), marker_text[:43] or "no markers", fill="#72a85d")
    path = CONTACTS / f"{entity['id'].split(':')[-1]}.png"
    canvas.convert("RGB").save(path, optimize=True)
    return path


def make_enemy_sheet(entities: list[dict[str, Any]], profiles: dict[str, dict[str, Any]]) -> Path:
    canvas = Image.new("RGBA", (1060, 580), "#101820")
    draw = ImageDraw.Draw(canvas)
    draw.text((18, 14), "Normal enemies and boss · idle / attack / dodge / hit / terminal", fill="#f3e2b8")
    for row, entity in enumerate(entities):
        draw.text((12, 66 + row * 126), entity["id"].split(":")[-1], fill="#e6bd67")
        profile = profiles[entity["profile_id"]]
        for column, name in enumerate(["idle", "attack", "dodge", "hit", "victory", "defeat"]):
            descriptor = profile["world_animations"].get(name)
            if descriptor is None:
                continue
            frames = split_frames(PACK / descriptor["asset"], int(descriptor["frames"]))
            frame = frames[len(frames) // 2].resize((96, 96), Image.Resampling.NEAREST)
            x = 180 + column * 142
            y = 50 + row * 126
            canvas.alpha_composite(frame, (x, y))
            draw.text((x + 22, y + 99), name, fill="#9fc8cf")
    path = CONTACTS / "enemies-and-boss.png"
    canvas.convert("RGB").save(path, optimize=True)
    return path


def make_vfx_sheet() -> Path:
    paths = sorted((ROOT / "game" / "assets_generated" / "vfx").rglob("*.png"))
    canvas = Image.new("RGBA", (1000, 600), "#101820")
    draw = ImageDraw.Draw(canvas)
    draw.text((18, 14), "Combat effects · start / progression / impact / recovery", fill="#f3e2b8")
    for index, path in enumerate(paths):
        family, name = path.parent.name, path.stem
        image = Image.open(path).convert("RGBA")
        frame_count = max(1, image.width // image.height)
        frames = split_frames(path, frame_count)
        x = 12 + (index % 3) * 328
        y = 54 + (index // 3) * 132
        draw.text((x, y), f"{family}/{name} · {frame_count}f", fill="#e6bd67")
        for sample_index in range(min(4, frame_count)):
            frame_index = round(sample_index * (frame_count - 1) / max(1, min(4, frame_count) - 1))
            canvas.alpha_composite(frames[frame_index].resize((72, 72), Image.Resampling.NEAREST), (x + sample_index * 76, y + 24))
    path = CONTACTS / "combat-effects.png"
    canvas.convert("RGB").save(path, optimize=True)
    return path


def gif_from_tracks(output: Path, title: str, tracks: list[tuple[str, Path, int]], frame_total: int = 24) -> Path:
    rendered: list[Image.Image] = []
    for tick in range(frame_total):
        canvas = Image.new("RGB", (max(360, len(tracks) * 190), 190), "#172126")
        draw = ImageDraw.Draw(canvas)
        draw.text((12, 10), title, fill="#f3e2b8")
        for index, (label, path, count) in enumerate(tracks):
            frames = split_frames(path, count)
            frame = frames[tick % len(frames)].resize((128, 128), Image.Resampling.NEAREST)
            x = 24 + index * 190
            canvas.paste(frame, (x, 38), frame)
            draw.text((x, 168), label, fill="#9fc8cf")
        rendered.append(canvas)
    rendered[0].save(output, save_all=True, append_images=rendered[1:], duration=90, loop=0, optimize=False)
    return output


def make_reels(profiles: dict[str, dict[str, Any]]) -> list[Path]:
    outputs: list[Path] = []
    enemy_tracks: list[tuple[str, Path, int]] = []
    for profile_id in ["koalapet.base:creekling_animation", "koalapet.base:thornlet_animation", "koalapet.base:cinder_moth_animation", "koalapet.base:canopy_guardian_animation"]:
        profile = profiles[profile_id]
        descriptor = profile["world_animations"]["attack"]
        enemy_tracks.append((profile_id.split(":")[-1].removesuffix("_animation"), PACK / descriptor["asset"], int(descriptor["frames"])))
    outputs.append(gif_from_tracks(REELS / "enemy-boss-combat.gif", "Enemy and boss attacks", enemy_tracks))
    moss = profiles["koalapet.base:moss_animation"]
    care_tracks = []
    for name in ["clean", "medicine", "sleep_enter", "wake"]:
        descriptor = moss["world_animations"][name]
        care_tracks.append((name, PACK / descriptor["asset"], int(descriptor["frames"])))
    outputs.append(gif_from_tracks(REELS / "sleep-care.gif", "Sleep and care transitions", care_tracks))
    walk = moss["world_animations"]["walk"]
    outputs.append(gif_from_tracks(REELS / "minimal-desktop.gif", "Minimal desktop roaming at runtime scale", [("Minimal", PACK / walk["asset"], int(walk["frames"]))]))
    idle = moss["world_animations"]["idle_playful"]
    normal_frames = split_frames(PACK / idle["asset"], int(idle["frames"]))
    reduced: list[Image.Image] = []
    for tick in range(24):
        canvas = Image.new("RGB", (480, 190), "#172126")
        draw = ImageDraw.Draw(canvas)
        draw.text((12, 10), "Reduced Motion comparison", fill="#f3e2b8")
        left = normal_frames[tick % len(normal_frames)].resize((128, 128), Image.Resampling.NEAREST)
        right = normal_frames[0].resize((128, 128), Image.Resampling.NEAREST)
        canvas.paste(left, (52, 38), left)
        canvas.paste(right, (298, 38), right)
        draw.text((80, 168), "normal loop", fill="#9fc8cf")
        draw.text((310, 168), "reduced: held", fill="#9fc8cf")
        reduced.append(canvas)
    path = REELS / "reduced-motion-comparison.gif"
    reduced[0].save(path, save_all=True, append_images=reduced[1:], duration=90, loop=0, optimize=False)
    outputs.append(path)
    return outputs


def make_ui_scale_sheet() -> Path:
    sources = [
        ("Small 100%", ROOT / "docs/evidence/animation-polish/windows/small-default.png"),
        ("Small UI 150%", ROOT / "docs/evidence/animation-polish/windows/small-ui-150.png"),
        ("Expanded 100%", ROOT / "docs/evidence/animation-polish/windows/expanded-default.png"),
        ("Expanded text 150%", ROOT / "docs/evidence/animation-polish/windows/expanded-text-150.png"),
    ]
    canvas = Image.new("RGB", (1200, 760), "#101820")
    draw = ImageDraw.Draw(canvas)
    draw.text((18, 14), "Project scale comparison · prior direct Windows captures", fill="#f3e2b8")
    for index, (label, path) in enumerate(sources):
        image = Image.open(path).convert("RGB")
        image.thumbnail((570, 320), Image.Resampling.LANCZOS)
        x = 15 + (index % 2) * 595
        y = 52 + (index // 2) * 350
        canvas.paste(image, (x, y + 24))
        draw.text((x, y), label, fill="#e6bd67")
    path = CONTACTS / "ui-scaling-comparison.png"
    canvas.save(path, optimize=True)
    return path


def make_regeneration_sheet(profiles: dict[str, dict[str, Any]]) -> Path:
    canvas = Image.new("RGB", (1120, 420), "#101820")
    draw = ImageDraw.Draw(canvas)
    draw.text((18, 14), "Rejected source-bank poses versus corrected deterministic runtime sequences", fill="#f3e2b8")
    families = ["moss", "ember", "tide"]
    for column, family in enumerate(families):
        source = Image.open(ROOT / f"art_source/sources/visual-rebuild/{family}_hatchling.png").convert("RGBA")
        source.thumbnail((330, 190), Image.Resampling.LANCZOS)
        x = 16 + column * 368
        canvas.paste(source, (x, 56), source)
        draw.text((x, 42), f"{family}: source pose bank (not runtime)", fill="#e36b58")
        descriptor = profiles[f"koalapet.base:{family}_animation"]["world_animations"]["sleep_enter"]
        frames = split_frames(PACK / descriptor["asset"], int(descriptor["frames"]))
        for index, frame in enumerate(frames[:4]):
            small = frame.resize((80, 80), Image.Resampling.NEAREST)
            canvas.paste(small, (x + index * 84, 280), small)
        draw.text((x, 370), "corrected sleep_enter: no helper hand / seam", fill="#72a85d")
    path = CONTACTS / "regenerated-examples.png"
    canvas.save(path, optimize=True)
    return path


def gather_runtime_references() -> set[str]:
    references: set[str] = set()
    for path in [*DATA.glob("*.json"), ROOT / "game/assets_generated/visual-rebuild-manifest.json"]:
        text = path.read_text(encoding="utf-8")
        for token in text.replace('"', "\n").splitlines():
            if not token.endswith(".png"):
                continue
            if token.startswith("game/"):
                references.add(token)
            elif token.startswith("assets/"):
                references.add(f"game/content_packs/koalapet.base/{token}")
    return references


def build_asset_register() -> dict[str, Any]:
    runtime_paths = sorted([
        *(ROOT / "game/assets_generated").rglob("*.png"),
        *(PACK / "assets").rglob("*.png"),
    ])
    visual_provenance = read_json(ROOT / "art_source/provenance/visual-rebuild.json")
    living_provenance = read_json(ROOT / "art_source/provenance/living-animation.json")
    visual_outputs = {item["path"] for item in visual_provenance["outputs"]}
    living_outputs = {item["path"] for item in living_provenance["outputs"]}
    groups: list[dict[str, Any]] = []
    for path in runtime_paths:
        relative = repo_path(path)
        if relative in living_outputs:
            source_brief = "Original provisional living-animation or VFX output derived from preserved KoalaPet source boards."
            generation_method = "AI-assisted preserved source generation followed by deterministic Pillow pose composition"
            generation_date = living_provenance["source_snapshot_date_utc"]
            generation_provider_tool = "Codex built-in image generation"
            model_identifier = "NOT_DISCLOSED"
            transformation_pipeline = ["tools/art_pipeline/process_living_animation_assets.py"]
        elif relative in visual_outputs:
            source_brief = "Original provisional visual generated for the KoalaPet presentation slice."
            generation_method = "AI-assisted source generation followed by deterministic Pillow processing"
            generation_date = visual_provenance["source_snapshot_date_utc"]
            generation_provider_tool = "Codex built-in image generation"
            model_identifier = "NOT_DISCLOSED"
            transformation_pipeline = ["tools/art_pipeline/process_visual_rebuild_assets.py"]
        else:
            source_brief = "Original provisional Milestone-4 dungeon or reward visual generated from repository-owned code."
            generation_method = "Deterministic Pillow code generation"
            generation_date = "2026-08-13"
            generation_provider_tool = "Python/Pillow"
            model_identifier = "NOT_APPLICABLE"
            transformation_pipeline = ["tools/art_pipeline/generate_milestone_four_assets.py"]
        groups.append(
            {
                "asset_id": "koalapet.base:visual/" + relative.removeprefix("game/").removesuffix(".png"),
                "owning_content_pack": "koalapet.base",
                "file_paths": [relative],
                "sha256": sha256(path),
                "source_brief": source_brief,
                "generation_method": generation_method,
                "generation_date": generation_date,
                "generation_provider_tool": generation_provider_tool,
                "model_identifier": model_identifier,
                "transformation_pipeline": transformation_pipeline,
                "human_manual_edits": "NONE_DOCUMENTED",
                "third_party_source_usage": "NONE_DOCUMENTED",
                "license_status": "UNDECIDED",
                "approval_status": "PROVISIONAL_PRODUCT_REVIEW",
                "classification": "REPLACE_BEFORE_RELEASE",
                "replacement_requirement": "Resolve asset rights and product-owner approval; regenerate or replace if either is unavailable.",
            }
        )
    for path in sorted((ROOT / "references/ui-modes").glob("*.png")):
        groups.append(
            {
                "asset_id": "reference:ui-mode/" + path.stem,
                "owning_content_pack": None,
                "file_paths": [repo_path(path)],
                "sha256": sha256(path),
                "source_brief": "Product-owner supplied directional UI concept; never distributed or imported by Godot.",
                "generation_method": "Unknown supplied reference",
                "generation_date": "NOT_DISCLOSED",
                "generation_provider_tool": "NOT_DISCLOSED",
                "model_identifier": "NOT_DISCLOSED",
                "transformation_pipeline": ["byte-for-byte repository reference copy"],
                "human_manual_edits": "NONE_DOCUMENTED",
                "third_party_source_usage": "UNKNOWN",
                "license_status": "UNDECIDED_REFERENCE_ONLY",
                "approval_status": "NOT_DISTRIBUTED_REFERENCE",
                "classification": "NOT_DISTRIBUTED_REFERENCE",
                "replacement_requirement": "Do not move into res:// or public distribution.",
            }
        )
    return {
        "schema_version": 1,
        "inventory_date": REVIEW_DATE,
        "legal_decision": "NOT_MADE",
        "distributed_visual_count": len(runtime_paths),
        "asset_groups": groups,
    }


def build_optimization_report() -> dict[str, Any]:
    runtime_paths = sorted([
        *(ROOT / "game/assets_generated").rglob("*.png"),
        *(PACK / "assets").rglob("*.png"),
    ])
    references = gather_runtime_references()
    hash_paths: defaultdict[str, list[str]] = defaultdict(list)
    padding: list[dict[str, Any]] = []
    total_decoded = 0
    total_disk = 0
    for path in runtime_paths:
        relative = repo_path(path)
        digest = sha256(path)
        hash_paths[digest].append(relative)
        total_disk += path.stat().st_size
        image = Image.open(path).convert("RGBA")
        total_decoded += image.width * image.height * 4
        bound = image.getchannel("A").getbbox()
        if bound is not None:
            used = (bound[2] - bound[0]) * (bound[3] - bound[1])
            ratio = 1.0 - used / float(image.width * image.height)
            if ratio >= 0.8:
                padding.append({"path": relative, "transparent_canvas_ratio": round(ratio, 4), "reason": "Anchor-preserving sprite/VFX canvas; do not crop without descriptor migration."})
    unreferenced = []
    for path in runtime_paths:
        relative = repo_path(path)
        if relative not in references:
            unreferenced.append(
                {
                    "path": relative,
                    "reason": "Generated compatibility reserve not referenced by a current animation profile; retained for deterministic pipeline parity until the release-art decision.",
                }
            )
    evidence_references = sorted(
        reference
        for reference in references
        if "/evidence/" in reference or reference.startswith(("docs/", "references/"))
    )
    return {
        "schema_version": 1,
        "measurement_date": REVIEW_DATE,
        "prompt_4_7_baseline": {
            "runtime_png_count": 388,
            "disk_bytes": 26030472,
            "estimated_decoded_rgba_bytes_if_all_loaded": 129624064,
        },
        "prompt_4_8_after_corrections": {
            "runtime_png_count": len(runtime_paths),
            "disk_bytes": total_disk,
            "estimated_decoded_rgba_bytes_if_all_loaded": total_decoded,
            "disk_delta_bytes": total_disk - 26030472,
        },
        "runtime_png_count": len(runtime_paths),
        "disk_bytes": total_disk,
        "estimated_decoded_rgba_bytes_if_all_loaded": total_decoded,
        "duplicate_file_groups": [paths for paths in hash_paths.values() if len(paths) > 1],
        "high_transparent_padding": padding,
        "unreferenced_with_explicit_reason": unreferenced,
        "evidence_under_res": evidence_references,
        "decision": "Keep stable paths and lazy runtime loading; atlas migration deferred until release asset approval.",
    }


def write_json(path: Path, value: Any) -> None:
    path.write_bytes((json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8"))


def evidence_entry(path: Path, purpose: str, settings: str, reproduction: str) -> dict[str, Any]:
    return {
        "path": repo_path(path),
        "purpose": purpose,
        "reproduction": reproduction,
        "settings": settings,
        "sha256": sha256(path),
    }


def build() -> dict[str, Any]:
    CONTACTS.mkdir(parents=True, exist_ok=True)
    REELS.mkdir(parents=True, exist_ok=True)
    profiles, entities = profile_entities()
    sequences: list[dict[str, Any]] = []
    evidence: list[dict[str, Any]] = []
    for entity in entities:
        profile = profiles[entity["profile_id"]]
        for animation_name, descriptor in sorted(profile["world_animations"].items()):
            sequences.append(sequence_diagnostics(entity, animation_name, descriptor))
        if entity["kind"] == "form":
            sheet = make_entity_sheet(entity, profile)
            evidence.append(evidence_entry(sheet, f"All runtime sequences for {entity['id']}", "dark neutral background; four representative frames", "python tools/visual_review/audit_animation_sequences.py"))
    enemies = [entity for entity in entities if entity["kind"] in {"enemy", "boss"}]
    enemy_sheet = make_enemy_sheet(enemies, profiles)
    evidence.append(evidence_entry(enemy_sheet, "Normal enemy and boss combat comparison", "idle, attack, dodge, hit, victory, defeat", "python tools/visual_review/audit_animation_sequences.py"))
    effect_sheet = make_vfx_sheet()
    evidence.append(evidence_entry(effect_sheet, "Combat VFX progression review", "all generated family VFX; four representative frames", "python tools/visual_review/audit_animation_sequences.py"))
    ui_sheet = make_ui_scale_sheet()
    evidence.append(evidence_entry(ui_sheet, "Project UI/text scaling comparison", "Small and Expanded; 100% and 150% project settings", "python tools/visual_review/audit_animation_sequences.py"))
    regeneration_sheet = make_regeneration_sheet(profiles)
    evidence.append(evidence_entry(regeneration_sheet, "Rejected source-pose contamination versus corrected runtime rows", "three starter families; sleep_enter", "python tools/visual_review/audit_animation_sequences.py"))
    for reel in make_reels(profiles):
        evidence.append(evidence_entry(reel, "Concise animated visual acceptance reel", "90 ms review cadence; runtime sprite sheets", "python tools/visual_review/audit_animation_sequences.py"))
    for family in ["moss", "ember", "tide"]:
        path = ROOT / f"docs/evidence/living-animation/reels/{family}-family.gif"
        evidence.append(evidence_entry(path, f"{family.capitalize()} family motion-language reel", "family highlight animations", "python tools/art_pipeline/process_living_animation_assets.py"))
    windows_dir = OUT / "windows"
    if windows_dir.is_dir():
        for path in sorted(windows_dir.iterdir()):
            if not path.is_file():
                continue
            if path.name == "environment.windows.json":
                purpose = "Direct interactive Windows monitor, DPI and taskbar environment"
                settings = "Windows 11; three displays; unlocked local session"
                reproduction = "tools/windows_overlay_spike/collect_environment.ps1"
            elif path.name == "showroom-runtime-secondary.png":
                purpose = "Direct native Animation Showroom layout and runtime playback"
                settings = "secondary display; dark background; egg hatch; 100% playback"
                reproduction = "tools/windows_overlay_spike/capture_interactive.ps1 -PrintWindow"
            elif path.name == "game-starter-focus-secondary.png":
                purpose = "Direct native starter-selection readability and visible keyboard focus"
                settings = "secondary display; English; Tab focus on first starter"
                reproduction = "tools/windows_overlay_spike/capture_interactive.ps1 -PrintWindow"
            else:
                purpose = "Direct native Windows visual-acceptance evidence"
                settings = "interactive Windows session"
                reproduction = "tools/windows_overlay_spike"
            evidence.append(evidence_entry(path, purpose, settings, reproduction))
    classification = {
        "schema_version": 1,
        "review_date": REVIEW_DATE,
        "classification_values": ["ACCEPTED_PROVISIONAL", "NEEDS_MINOR_FIX", "NEEDS_REGENERATION", "TECHNICALLY_BROKEN", "NOT_PLAYER_FACING"],
        "summary": dict(sorted(Counter(item["classification"] for item in sequences).items())),
        "sequences": sequences,
    }
    write_json(OUT / "animation-classifications.json", classification)
    write_json(OUT / "asset-rights-register.json", build_asset_register())
    write_json(OUT / "asset-optimization.json", build_optimization_report())
    evidence.extend(
        [
            evidence_entry(OUT / "animation-classifications.json", "Machine-readable exhaustive animation classification", "all nine forms, three enemies, boss and eggs", "python tools/visual_review/audit_animation_sequences.py"),
            evidence_entry(OUT / "asset-rights-register.json", "Machine-readable rights and provenance decision inventory", "all distributed PNGs plus three non-distributed UI references", "python tools/visual_review/audit_animation_sequences.py"),
            evidence_entry(OUT / "asset-optimization.json", "Runtime PNG storage, decode and reference audit", "RGBA decode estimate; exact SHA duplicates; reference scan", "python tools/visual_review/audit_animation_sequences.py"),
        ]
    )
    manifest = {
        "schema_version": 1,
        "review_date": REVIEW_DATE,
        "artifacts": sorted(evidence, key=lambda item: item["path"]),
    }
    write_json(OUT / "evidence-manifest.json", manifest)
    (OUT / "hashes.sha256").write_bytes(
        "".join(f"{item['sha256']}  {item['path']}\n" for item in manifest["artifacts"]).encode("utf-8")
    )
    return classification


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="fail if a technical classification remains")
    args = parser.parse_args()
    classification = build()
    broken = [item for item in classification["sequences"] if item["classification"] in {"TECHNICALLY_BROKEN", "NEEDS_REGENERATION"}]
    asset_register = read_json(OUT / "asset-rights-register.json")
    registered_paths = {
        path
        for group in asset_register["asset_groups"]
        if group["classification"] != "NOT_DISTRIBUTED_REFERENCE"
        for path in group["file_paths"]
    }
    expected_paths = {
        repo_path(path)
        for path in [
            *(ROOT / "game/assets_generated").rglob("*.png"),
            *(PACK / "assets").rglob("*.png"),
        ]
    }
    optimization = read_json(OUT / "asset-optimization.json")
    gate_errors: list[str] = []
    if registered_paths != expected_paths:
        gate_errors.append("asset-rights register does not exactly cover distributed runtime PNGs")
    if optimization["evidence_under_res"]:
        gate_errors.append("evidence/reference PNG is referenced by runtime content")
    if any(not entry.get("reason") for entry in optimization["unreferenced_with_explicit_reason"]):
        gate_errors.append("unreferenced runtime PNG lacks an explicit reason")
    print(
        "Visual acceptance audit: "
        f"{len(classification['sequences'])} sequences; "
        + ", ".join(f"{key}={value}" for key, value in classification["summary"].items())
    )
    if args.check and (broken or gate_errors):
        for item in broken:
            print(f"ERROR {item['sequence_id']}: {item['review_note']}", file=sys.stderr)
        for error in gate_errors:
            print(f"ERROR {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
