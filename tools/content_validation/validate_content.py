#!/usr/bin/env python3
"""Validate KoalaPet content packs and cross-references."""

from __future__ import annotations

import json
import sys
from collections.abc import Iterable
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator
from jsonschema.exceptions import SchemaError

ROOT = Path(__file__).resolve().parents[2]
PACK_ROOTS = (ROOT / "game" / "content_packs", ROOT / "mods" / "examples")
MAX_PACK_FILES = 1_024
FORBIDDEN_EXTENSIONS = {
    ".gd", ".gdc", ".cs", ".dll", ".so", ".dylib", ".exe", ".com", ".bat", ".cmd",
    ".ps1", ".sh", ".app", ".jar", ".class", ".py", ".rb", ".js", ".mjs", ".wasm",
    ".zip", ".rar", ".7z", ".tar", ".gz", ".bz2", ".xz", ".pkg", ".dmg", ".msi",
}
SKIN_OVERRIDE_SCHEMAS = {
    "animation-profile.schema.json",
    "furniture-prop.schema.json",
    "habitat-theme.schema.json",
}


@dataclass
class Document:
    path: Path
    pack_root: Path
    data: dict[str, Any]
    schema_name: str


class ValidationReport:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.documents: list[Document] = []
        self.pack_count = 0

    def error(self, path: Path, json_path: str, message: str) -> None:
        try:
            display = path.relative_to(ROOT)
        except ValueError:
            display = path
        self.errors.append(f"{display}:{json_path}: {message}")


def load_json(path: Path, report: ValidationReport, json_path: str = "$") -> dict[str, Any] | None:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        report.error(path, json_path, str(exc))
        return None
    if not isinstance(value, dict):
        report.error(path, json_path, "expected a JSON object")
        return None
    return value


def contained_path(root: Path, relative: str) -> Path | None:
    candidate = (root / relative).resolve()
    try:
        candidate.relative_to(root.resolve())
    except ValueError:
        return None
    return candidate


def json_path(parts: Iterable[Any]) -> str:
    result = "$"
    for part in parts:
        result += f"[{part}]" if isinstance(part, int) else f".{part}"
    return result


def validate_schema(document_path: Path, pack_root: Path, data: dict[str, Any], report: ValidationReport) -> str | None:
    schema_ref = data.get("$schema")
    if not isinstance(schema_ref, str):
        report.error(document_path, "$.$schema", "missing repository-relative schema reference")
        return None
    schema_path = (document_path.parent / schema_ref).resolve()
    schemas_root = (ROOT / "schemas").resolve()
    if schema_path is None or not schema_path.is_relative_to(schemas_root):
        report.error(document_path, "$.$schema", "schema path must resolve inside schemas/")
        return None
    if not schema_path.is_file():
        report.error(document_path, "$.$schema", f"schema does not exist: {schema_ref}")
        return None
    schema = load_json(schema_path, report)
    if schema is None:
        return None
    try:
        Draft202012Validator.check_schema(schema)
        validator = Draft202012Validator(schema)
    except SchemaError as exc:
        report.error(schema_path, "$", f"invalid schema: {exc}")
        return None
    for error in sorted(validator.iter_errors(data), key=lambda item: list(item.absolute_path)):
        report.error(document_path, json_path(error.absolute_path), error.message)
    return schema_path.name


def validate_asset_path(document: Document, manifest: dict[str, Any], location: Any, pointer: str, report: ValidationReport) -> None:
    if not isinstance(location, str) or not location:
        report.error(document.path, pointer, "asset path must be a non-empty string")
        return
    asset_roots = manifest.get("asset_roots", [])
    if not any(location == root or location.startswith(f"{root}/") for root in asset_roots if isinstance(root, str)):
        report.error(document.path, pointer, "asset path is outside declared asset roots")
        return
    target = contained_path(document.pack_root, location)
    if target is None:
        report.error(document.path, pointer, "asset path escapes pack root")
        return
    if target.suffix.lower() not in {".png", ".webp", ".ogg", ".wav"}:
        report.error(document.path, pointer, "asset extension is not allowlisted")
    if not target.is_file() and not location.startswith("assets/placeholders/"):
        report.error(document.path, pointer, f"asset file does not exist: {location}")


def load_packs(report: ValidationReport) -> list[tuple[Path, dict[str, Any]]]:
    packs: list[tuple[Path, dict[str, Any]]] = []
    for root in PACK_ROOTS:
        if not root.is_dir():
            continue
        for manifest_path in sorted(root.glob("*/manifest.json")):
            pack_root = manifest_path.parent.resolve()
            manifest = load_json(manifest_path, report)
            if manifest is None:
                continue
            validate_schema(manifest_path, pack_root, manifest, report)
            validate_pack_payloads(pack_root, manifest_path, report)
            packs.append((pack_root, manifest))
            report.pack_count += 1
    return packs


def validate_pack_payloads(pack_root: Path, manifest_path: Path, report: ValidationReport) -> None:
    files = sorted(path for path in pack_root.rglob("*") if path.is_file() or path.is_symlink())
    if len(files) > MAX_PACK_FILES:
        report.error(manifest_path, "$", f"pack exceeds {MAX_PACK_FILES} files")
    total_size = 0
    for path in files:
        if path.is_symlink():
            report.error(path, "$", "symbolic links and reparse points are forbidden in packs")
            continue
        if path.suffix.lower() in FORBIDDEN_EXTENSIONS:
            report.error(path, "$", "executable or archive payload is forbidden")
        try:
            size = path.stat().st_size
        except OSError as exc:
            report.error(path, "$", f"could not inspect payload: {exc}")
            continue
        total_size += size
        if path.suffix.lower() == ".json" and size > 2 * 1024 * 1024:
            report.error(path, "$", "JSON file exceeds 2097152 bytes")
    if total_size > 64 * 1024 * 1024:
        report.error(manifest_path, "$", "pack exceeds 67108864 bytes")


def version_matches(actual: str, requirement: str) -> bool:
    if requirement in {"", "*"}:
        return True
    prefix = ""
    if requirement.startswith((">=", "^")):
        prefix, requirement = (requirement[:2], requirement[2:]) if requirement.startswith(">=") else ("^", requirement[1:])
    try:
        actual_parts = tuple(int(part) for part in actual.split("-", 1)[0].split(".")[:3])
        required_parts = tuple(int(part) for part in requirement.split("-", 1)[0].split(".")[:3])
    except ValueError:
        return False
    if prefix == ">=":
        return actual_parts >= required_parts
    if prefix == "^":
        return actual_parts >= required_parts and actual_parts[0] == required_parts[0]
    return actual == requirement


def validate_pack_relationships(packs: list[tuple[Path, dict[str, Any]]], report: ValidationReport) -> None:
    by_id: dict[str, tuple[Path, dict[str, Any]]] = {}
    duplicate_ids: set[str] = set()
    for pack_root, manifest in packs:
        pack_id = manifest.get("pack_id")
        if not isinstance(pack_id, str):
            continue
        if pack_id in by_id:
            duplicate_ids.add(pack_id)
            report.error(pack_root / "manifest.json", "$.pack_id", f"duplicate pack ID also defined in {by_id[pack_id][0].relative_to(ROOT)}")
        else:
            by_id[pack_id] = (pack_root, manifest)
    for pack_id in duplicate_ids:
        first_root, _ = by_id[pack_id]
        report.error(first_root / "manifest.json", "$.pack_id", "duplicate pack ID")
    for pack_root, manifest in packs:
        pack_id = manifest.get("pack_id")
        if manifest.get("type") != "total_conversion" and manifest.get("base_pack_enabled") is False:
            report.error(pack_root / "manifest.json", "$.base_pack_enabled", "only total_conversion packs may disable the bundled base pack")
        for index, dependency in enumerate(manifest.get("dependencies", [])):
            required_id = dependency.get("pack_id") if isinstance(dependency, dict) else None
            if required_id not in by_id:
                report.error(pack_root / "manifest.json", f"$.dependencies[{index}]", f"missing required dependency: {required_id}")
            elif not version_matches(str(by_id[required_id][1].get("version", "")), str(dependency.get("version", ""))):
                report.error(pack_root / "manifest.json", f"$.dependencies[{index}].version", f"dependency version mismatch: {required_id}")
        for index, conflict in enumerate(manifest.get("incompatibilities", [])):
            conflict_id = conflict.get("pack_id") if isinstance(conflict, dict) else None
            if conflict_id in by_id and version_matches(str(by_id[conflict_id][1].get("version", "")), str(conflict.get("version", ""))):
                report.error(pack_root / "manifest.json", f"$.incompatibilities[{index}]", f"enabled pack conflicts with {conflict_id}")


def load_entries(pack_root: Path, manifest: dict[str, Any], report: ValidationReport) -> None:
    pack_id = manifest.get("pack_id")
    for index, entry in enumerate(manifest.get("entry_points", [])):
        if not isinstance(entry, str):
            continue
        path = contained_path(pack_root, entry)
        if path is None:
            report.error(pack_root / "manifest.json", f"$.entry_points[{index}]", "entry point escapes pack root")
            continue
        if not path.is_file():
            report.error(pack_root / "manifest.json", f"$.entry_points[{index}]", f"entry point does not exist: {entry}")
            continue
        data = load_json(path, report)
        if data is None:
            continue
        schema_name = validate_schema(path, pack_root, data, report)
        if schema_name is None:
            continue
        content_id = data.get("id")
        is_owned = isinstance(content_id, str) and isinstance(pack_id, str) and content_id.startswith(pack_id + ":")
        is_override = isinstance(content_id, str) and content_id in manifest.get("overrides", [])
        if isinstance(content_id, str) and isinstance(pack_id, str) and not is_owned and not is_override:
            report.error(path, "$.id", f"ID namespace must be owned by pack {pack_id!r}")
        if is_override and manifest.get("type") == "skin" and schema_name not in SKIN_OVERRIDE_SCHEMAS:
            report.error(path, "$.id", "skin packs may override presentation definitions only")
        report.documents.append(Document(path, pack_root, data, schema_name))


def require_reference(document: Document, pointer: str, value: Any, expected: set[str], by_id: dict[str, Document], report: ValidationReport) -> None:
    if not isinstance(value, str):
        return
    target = by_id.get(value)
    if target is None:
        report.error(document.path, pointer, f"unresolved content ID: {value}")
    elif target.schema_name not in expected:
        report.error(document.path, pointer, f"{value} resolves to {target.schema_name}, expected {sorted(expected)}")


def require_many(document: Document, pointer: str, values: Any, expected: set[str], by_id: dict[str, Document], report: ValidationReport) -> None:
    if isinstance(values, list):
        for index, value in enumerate(values):
            require_reference(document, f"{pointer}[{index}]", value, expected, by_id, report)


def validate_cross_references(packs: list[tuple[Path, dict[str, Any]]], report: ValidationReport) -> None:
    by_id: dict[str, Document] = {}
    localized: dict[Path, set[str]] = {}
    manifests: dict[Path, dict[str, Any]] = {pack_root: manifest for pack_root, manifest in packs}
    for document in report.documents:
        if document.schema_name == "localization-bundle.schema.json":
            localized.setdefault(document.pack_root, set()).update(document.data.get("strings", {}).keys())
        content_id = document.data.get("id")
        if isinstance(content_id, str):
            previous = by_id.get(content_id)
            if previous is not None:
                report.error(document.path, "$.id", f"duplicate ID also defined in {previous.path.relative_to(ROOT)}")
            else:
                by_id[content_id] = document

    for pack_root, manifest in packs:
        display_key = manifest.get("display_name_key")
        if isinstance(display_key, str) and display_key not in localized.get(pack_root, set()) and manifest.get("entry_points"):
            report.error(pack_root / "manifest.json", "$.display_name_key", f"missing localization key: {display_key}")

    rule_ids: dict[str, Path] = {}
    for document in report.documents:
        data = document.data
        display_key = data.get("display_name_key")
        if isinstance(display_key, str) and display_key not in localized.get(document.pack_root, set()):
            report.error(document.path, "$.display_name_key", f"missing localization key: {display_key}")

        schema = document.schema_name
        if schema == "starter-pool.schema.json":
            require_many(document, "$.egg_ids", data.get("egg_ids"), {"egg.schema.json"}, by_id, report)
        elif schema == "egg.schema.json":
            require_reference(document, "$.family_id", data.get("family_id"), {"species-family.schema.json"}, by_id, report)
            require_reference(document, "$.hatch_form_id", data.get("hatch_form_id"), {"form.schema.json"}, by_id, report)
            require_reference(document, "$.animation_profile_id", data.get("animation_profile_id"), {"animation-profile.schema.json"}, by_id, report)
        elif schema == "species-family.schema.json":
            require_many(document, "$.form_ids", data.get("form_ids"), {"form.schema.json"}, by_id, report)
            require_reference(document, "$.evolution_graph_id", data.get("evolution_graph_id"), {"evolution-graph.schema.json"}, by_id, report)
        elif schema == "form.schema.json":
            require_reference(document, "$.family_id", data.get("family_id"), {"species-family.schema.json"}, by_id, report)
            require_reference(document, "$.animation_profile_id", data.get("animation_profile_id"), {"animation-profile.schema.json"}, by_id, report)
            if "care_profile_id" in data:
                require_reference(document, "$.care_profile_id", data.get("care_profile_id"), {"care-profile.schema.json"}, by_id, report)
            require_many(document, "$.move_ids", data.get("move_ids"), {"move.schema.json"}, by_id, report)
        elif schema == "evolution-graph.schema.json":
            for index, rule in enumerate(data.get("rules", [])):
                rule_id = rule.get("id")
                if isinstance(rule_id, str):
                    previous = rule_ids.get(rule_id)
                    if previous:
                        report.error(document.path, f"$.rules[{index}].id", f"duplicate rule ID also defined in {previous.relative_to(ROOT)}")
                    rule_ids[rule_id] = document.path
                require_reference(document, f"$.rules[{index}].from_form_id", rule.get("from_form_id"), {"form.schema.json"}, by_id, report)
                require_reference(document, f"$.rules[{index}].to_form_id", rule.get("to_form_id"), {"form.schema.json"}, by_id, report)
        elif schema == "enemy-encounter.schema.json":
            require_many(document, "$.move_ids", data.get("move_ids"), {"move.schema.json"}, by_id, report)
            if "animation_profile_id" in data:
                require_reference(document, "$.animation_profile_id", data.get("animation_profile_id"), {"animation-profile.schema.json"}, by_id, report)
            for index, drop in enumerate(data.get("drops", [])):
                require_reference(document, f"$.drops[{index}].item_id", drop.get("item_id"), {"item.schema.json"}, by_id, report)
        elif schema == "dungeon.schema.json":
            require_many(document, "$.encounter_ids", data.get("encounter_ids"), {"enemy-encounter.schema.json"}, by_id, report)
            require_reference(document, "$.boss_encounter_id", data.get("boss_encounter_id"), {"enemy-encounter.schema.json"}, by_id, report)
            require_many(document, "$.reward_item_ids", data.get("reward_item_ids"), {"item.schema.json"}, by_id, report)
            require_many(document, "$.unlock_ids", data.get("unlock_ids"), {"habitat-theme.schema.json", "feature-gate.schema.json"}, by_id, report)
            if "prerequisite_gate_id" in data:
                require_reference(document, "$.prerequisite_gate_id", data.get("prerequisite_gate_id"), {"feature-gate.schema.json"}, by_id, report)
            if "boss_flag_id" in data:
                require_reference(document, "$.boss_flag_id", data.get("boss_flag_id"), {"feature-gate.schema.json"}, by_id, report)
            for index, node in enumerate(data.get("nodes", [])):
                if isinstance(node, dict) and "encounter_id" in node:
                    require_reference(document, f"$.nodes[{index}].encounter_id", node.get("encounter_id"), {"enemy-encounter.schema.json"}, by_id, report)
        elif schema == "habitat-theme.schema.json":
            require_many(document, "$.furniture_ids", data.get("furniture_ids"), {"furniture-prop.schema.json"}, by_id, report)
            require_reference(document, "$.unlock_gate_id", data.get("unlock_gate_id"), {"feature-gate.schema.json"}, by_id, report)
        elif schema == "farm-job.schema.json":
            require_reference(document, "$.station_id", data.get("station_id"), {"furniture-prop.schema.json"}, by_id, report)
            require_reference(document, "$.output_item_id", data.get("output_item_id"), {"item.schema.json"}, by_id, report)
        elif schema == "ailment.schema.json" or schema == "injury.schema.json":
            require_reference(document, "$.treatment_item_id", data.get("treatment_item_id"), {"item.schema.json"}, by_id, report)
        elif schema == "progression-balance.schema.json":
            require_reference(document, "$.battle_gate_id", data.get("battle_gate_id"), {"feature-gate.schema.json"}, by_id, report)
            require_reference(document, "$.dungeon_gate_id", data.get("dungeon_gate_id"), {"feature-gate.schema.json"}, by_id, report)
            require_many(document, "$.injury_ids", data.get("injury_ids"), {"injury.schema.json"}, by_id, report)

        manifest = manifests[document.pack_root]
        if schema == "animation-profile.schema.json":
            validate_asset_path(document, manifest, data.get("preview", ""), "$.preview", report)
            validate_asset_path(document, manifest, data.get("portrait", ""), "$.portrait", report)
            for name, animation in data.get("world_animations", {}).items():
                validate_asset_path(document, manifest, animation.get("asset", ""), f"$.world_animations.{name}.asset", report)
                frames = animation.get("frames", 0)
                marker_frames = [marker.get("frame", -1) for marker in animation.get("event_markers", []) if isinstance(marker, dict)]
                for index, marker_frame in enumerate(marker_frames):
                    if not isinstance(marker_frame, int) or not isinstance(frames, int) or marker_frame < 0 or marker_frame >= frames:
                        report.error(document.path, f"$.world_animations.{name}.event_markers[{index}].frame", f"marker frame must be within 0..{max(0, frames - 1)}")
                if marker_frames != sorted(marker_frames):
                    report.error(document.path, f"$.world_animations.{name}.event_markers", "marker frames must be ordered")
        elif schema == "habitat-theme.schema.json":
            validate_asset_path(document, manifest, data.get("background_asset", ""), "$.background_asset", report)
            validate_asset_path(document, manifest, data.get("ground_asset", ""), "$.ground_asset", report)
        elif schema == "furniture-prop.schema.json":
            validate_asset_path(document, manifest, data.get("asset", ""), "$.asset", report)


def main() -> int:
    report = ValidationReport()
    packs = load_packs(report)
    validate_pack_relationships(packs, report)
    for pack_root, manifest in packs:
        load_entries(pack_root, manifest, report)
    validate_cross_references(packs, report)
    if report.errors:
        for error in sorted(report.errors):
            print(f"ERROR: {error}", file=sys.stderr)
        print(f"Validation failed: {len(report.errors)} error(s).", file=sys.stderr)
        return 1
    print(f"Validation passed: {report.pack_count} pack(s), {len(report.documents)} content document(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
