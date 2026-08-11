#!/usr/bin/env python3
"""Validate KoalaPet content packs and cross-references."""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Set, Tuple

from jsonschema import Draft202012Validator


ROOT = Path(__file__).resolve().parents[2]
PACK_ROOTS = (ROOT / "game" / "content_packs", ROOT / "mods" / "examples")


@dataclass
class Document:
    path: Path
    pack_root: Path
    data: Dict[str, Any]
    schema_name: str


class ValidationReport:
    def __init__(self) -> None:
        self.errors: List[str] = []
        self.documents: List[Document] = []
        self.pack_count = 0

    def error(self, path: Path, json_path: str, message: str) -> None:
        try:
            display = path.relative_to(ROOT)
        except ValueError:
            display = path
        self.errors.append(f"{display}:{json_path}: {message}")


def load_json(path: Path, report: ValidationReport, json_path: str = "$") -> Optional[Dict[str, Any]]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        report.error(path, json_path, str(exc))
        return None
    if not isinstance(value, dict):
        report.error(path, json_path, "expected a JSON object")
        return None
    return value


def contained_path(root: Path, relative: str) -> Optional[Path]:
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


def validate_schema(document_path: Path, pack_root: Path, data: Dict[str, Any], report: ValidationReport) -> Optional[str]:
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
    except Exception as exc:  # jsonschema reports detailed schema diagnostics here.
        report.error(schema_path, "$", f"invalid schema: {exc}")
        return None
    for error in sorted(validator.iter_errors(data), key=lambda item: list(item.absolute_path)):
        report.error(document_path, json_path(error.absolute_path), error.message)
    return schema_path.name


def validate_asset_path(document: Document, location: str, pointer: str, report: ValidationReport) -> None:
    target = contained_path(document.pack_root, location)
    if target is None:
        report.error(document.path, pointer, "asset path escapes pack root")
        return
    if target.suffix.lower() not in {".png", ".webp", ".ogg", ".wav"}:
        report.error(document.path, pointer, "asset extension is not allowlisted")
    if not target.is_file() and not location.startswith("assets/placeholders/"):
        report.error(document.path, pointer, f"asset file does not exist: {location}")


def load_packs(report: ValidationReport) -> List[Tuple[Path, Dict[str, Any]]]:
    packs: List[Tuple[Path, Dict[str, Any]]] = []
    for root in PACK_ROOTS:
        if not root.is_dir():
            continue
        for manifest_path in sorted(root.glob("*/manifest.json")):
            pack_root = manifest_path.parent.resolve()
            manifest = load_json(manifest_path, report)
            if manifest is None:
                continue
            validate_schema(manifest_path, pack_root, manifest, report)
            packs.append((pack_root, manifest))
            report.pack_count += 1
    return packs


def load_entries(pack_root: Path, manifest: Dict[str, Any], report: ValidationReport) -> None:
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
        if isinstance(content_id, str) and isinstance(pack_id, str) and not content_id.startswith(pack_id + ":"):
            report.error(path, "$.id", f"ID namespace must be owned by pack {pack_id!r}")
        report.documents.append(Document(path, pack_root, data, schema_name))


def require_reference(document: Document, pointer: str, value: Any, expected: Set[str], by_id: Dict[str, Document], report: ValidationReport) -> None:
    if not isinstance(value, str):
        return
    target = by_id.get(value)
    if target is None:
        report.error(document.path, pointer, f"unresolved content ID: {value}")
    elif target.schema_name not in expected:
        report.error(document.path, pointer, f"{value} resolves to {target.schema_name}, expected {sorted(expected)}")


def require_many(document: Document, pointer: str, values: Any, expected: Set[str], by_id: Dict[str, Document], report: ValidationReport) -> None:
    if isinstance(values, list):
        for index, value in enumerate(values):
            require_reference(document, f"{pointer}[{index}]", value, expected, by_id, report)


def validate_cross_references(packs: List[Tuple[Path, Dict[str, Any]]], report: ValidationReport) -> None:
    by_id: Dict[str, Document] = {}
    localized: Dict[Path, Set[str]] = {}
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

    rule_ids: Dict[str, Path] = {}
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
            for index, drop in enumerate(data.get("drops", [])):
                require_reference(document, f"$.drops[{index}].item_id", drop.get("item_id"), {"item.schema.json"}, by_id, report)
        elif schema == "dungeon.schema.json":
            require_many(document, "$.encounter_ids", data.get("encounter_ids"), {"enemy-encounter.schema.json"}, by_id, report)
            require_reference(document, "$.boss_encounter_id", data.get("boss_encounter_id"), {"enemy-encounter.schema.json"}, by_id, report)
            require_many(document, "$.reward_item_ids", data.get("reward_item_ids"), {"item.schema.json"}, by_id, report)
            require_many(document, "$.unlock_ids", data.get("unlock_ids"), {"habitat-theme.schema.json", "feature-gate.schema.json"}, by_id, report)
        elif schema == "habitat-theme.schema.json":
            require_many(document, "$.furniture_ids", data.get("furniture_ids"), {"furniture-prop.schema.json"}, by_id, report)
            require_reference(document, "$.unlock_gate_id", data.get("unlock_gate_id"), {"feature-gate.schema.json"}, by_id, report)
        elif schema == "farm-job.schema.json":
            require_reference(document, "$.station_id", data.get("station_id"), {"furniture-prop.schema.json"}, by_id, report)
            require_reference(document, "$.output_item_id", data.get("output_item_id"), {"item.schema.json"}, by_id, report)

        if schema == "animation-profile.schema.json":
            validate_asset_path(document, data.get("preview", ""), "$.preview", report)
            validate_asset_path(document, data.get("portrait", ""), "$.portrait", report)
            for name, animation in data.get("world_animations", {}).items():
                validate_asset_path(document, animation.get("asset", ""), f"$.world_animations.{name}.asset", report)
        elif schema == "habitat-theme.schema.json":
            validate_asset_path(document, data.get("background_asset", ""), "$.background_asset", report)
            validate_asset_path(document, data.get("ground_asset", ""), "$.ground_asset", report)
        elif schema == "furniture-prop.schema.json":
            validate_asset_path(document, data.get("asset", ""), "$.asset", report)


def main() -> int:
    report = ValidationReport()
    packs = load_packs(report)
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
