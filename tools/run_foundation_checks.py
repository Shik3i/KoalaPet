#!/usr/bin/env python3
"""Run deterministic local checks for the content and simulation foundation."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from collections.abc import Iterable, Sequence
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SKIP_PARTS = {".git", ".godot", ".venv", "__pycache__"}
ARTIFACT_SCAN_SKIP_PARTS = {".git", ".godot", ".venv"}
FORBIDDEN_MOD_SUFFIXES = {
    ".gd", ".gdc", ".cs", ".dll", ".so", ".dylib", ".exe", ".com", ".bat", ".cmd",
    ".ps1", ".sh", ".app", ".jar", ".class", ".py", ".rb", ".js", ".mjs", ".wasm",
    ".zip", ".rar", ".7z", ".tar", ".gz", ".bz2", ".xz", ".pkg", ".dmg", ".msi",
}
FORBIDDEN_TRACKED_PARTS = {".godot", "__pycache__", ".DS_Store"}
FRANCHISE_TERMS = ("pokemon", "pokémon", "digimon", "tamagotchi")


def run(command: Sequence[str], label: str) -> None:
    print(f"CHECK: {label}")
    subprocess.run(command, cwd=ROOT, check=True)


def run_godot(command: Sequence[str], label: str) -> None:
    print(f"CHECK: {label}")
    completed = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False)
    if completed.stdout:
        print(completed.stdout, end="")
    if completed.stderr:
        print(completed.stderr, end="", file=sys.stderr)
    combined = completed.stdout + "\n" + completed.stderr
    if completed.returncode != 0 or "SCRIPT ERROR:" in combined or "ERROR:" in combined:
        raise RuntimeError(f"{label} reported a Godot error (exit={completed.returncode})")


def iter_files(roots: Iterable[Path], suffixes: set[str] | None = None) -> Iterable[Path]:
    for root in roots:
        if not root.exists():
            continue
        for path in sorted(root.rglob("*")):
            if not path.is_file() or any(part in SKIP_PARTS for part in path.parts):
                continue
            if suffixes is None or path.suffix.lower() in suffixes:
                yield path


def locate_godot(explicit: str | None) -> str:
    candidates = [explicit, os.environ.get("GODOT_PATH"), shutil.which("godot"), shutil.which("godot4")]
    if sys.platform == "darwin":
        candidates.append("/Applications/Godot.app/Contents/MacOS/Godot")
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            path = Path(candidate)
            if sys.platform == "win32" and not path.stem.endswith("_console"):
                console_path = path.with_name(path.stem + "_console" + path.suffix)
                if console_path.is_file():
                    return str(console_path)
                continue
            return str(path)
    raise RuntimeError("Godot console executable not found; pass --godot with the Windows _console.exe binary")


def check_json() -> None:
    count = 0
    for path in iter_files([ROOT], {".json"}):
        json.loads(path.read_text(encoding="utf-8"))
        count += 1
    print(f"PASS: parsed {count} JSON file(s)")


def check_python_compile() -> None:
    count = 0
    for path in iter_files([ROOT / "tools"], {".py"}):
        compile(path.read_text(encoding="utf-8"), str(path), "exec")
        count += 1
    print(f"PASS: compiled {count} Python source file(s) in memory")


def check_mod_payloads() -> None:
    violations: list[str] = []
    for path in sorted((ROOT / "mods").rglob("*")):
        if path.is_symlink():
            violations.append(f"symlink:{path.relative_to(ROOT)}")
        elif path.is_file() and path.suffix.lower() in FORBIDDEN_MOD_SUFFIXES:
            violations.append(f"payload:{path.relative_to(ROOT)}")
    if violations:
        raise RuntimeError("forbidden mod content: " + ", ".join(violations))
    print("PASS: no executable/archive mod payloads or symlinks")


def check_franchise_terms() -> None:
    violations: list[str] = []
    roots = [ROOT / "game" / "src", ROOT / "game" / "content_packs", ROOT / "mods" / "examples", ROOT / "schemas"]
    for path in iter_files(roots, {".gd", ".json", ".tscn"}):
        text = path.read_text(encoding="utf-8", errors="replace").lower()
        for term in FRANCHISE_TERMS:
            if term in text:
                violations.append(f"{path.relative_to(ROOT)}:{term}")
    if violations:
        raise RuntimeError("franchise terms found: " + ", ".join(violations))
    print("PASS: neutral terminology scan")


def check_tracked_artifacts() -> None:
    output = subprocess.check_output(["git", "ls-files"], cwd=ROOT, text=True)
    violations: list[str] = []
    for value in output.splitlines():
        path = Path(value)
        if any(part in FORBIDDEN_TRACKED_PARTS for part in path.parts) or path.suffix.lower() in {".pyc", ".pyo"}:
            violations.append(value)
    for path in ROOT.rglob("*"):
        if any(part in ARTIFACT_SCAN_SKIP_PARTS for part in path.parts):
            continue
        if path.name == ".DS_Store" or path.name == "__pycache__" or path.suffix.lower() in {".pyc", ".pyo"}:
            relative = str(path.relative_to(ROOT))
            if relative not in violations:
                violations.append(relative)
    if violations:
        raise RuntimeError("repository cache/artifact files: " + ", ".join(sorted(violations)))
    print("PASS: repository artifact/cache scan")


def main() -> int:
    os.environ.setdefault("PYTHONDONTWRITEBYTECODE", "1")
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", help="Path to the pinned Godot executable")
    args = parser.parse_args()
    godot = locate_godot(args.godot)

    check_json()
    check_python_compile()
    run([sys.executable, "tools/content_validation/validate_content.py"], "Python content validation")
    run([sys.executable, "tools/art_pipeline/validate_vertical_slice_assets.py", "--repo-root", str(ROOT)], "Vertical-slice asset validation")
    run([sys.executable, "tools/visual_review/audit_animation_sequences.py", "--check"], "Exhaustive visual-acceptance diagnostics")
    run([sys.executable, "tools/art_pipeline/generate_ui_symbol_icons.py", "--check"], "UI symbol icon parity")
    run([sys.executable, "tools/art_pipeline/generate_egg_animations.py", "--check"], "Egg animation parity")
    run([sys.executable, "tools/art_pipeline/audit_animation_quality.py", "--check"], "Animation frame-count and motion audit")
    run([sys.executable, "tools/repository/check_markdown_links.py"], "Markdown links")
    check_mod_payloads()
    check_franchise_terms()
    check_tracked_artifacts()
    run_godot([godot, "--headless", "--path", "game", "--import"], "Godot complete headless import")
    run_godot([godot, "--headless", "--path", "game", "--script", "res://tests/foundation/run_all.gd"], "Milestone 2 foundation tests")
    run_godot([godot, "--headless", "--path", "game", "--script", "res://tests/pet/run_all.gd"], "Milestone 3 pet vertical-slice tests")
    run_godot([godot, "--headless", "--path", "game", "--script", "res://tests/milestone_four/run_all.gd"], "Milestone 4 evolution/battle/dungeon tests")
    run_godot([godot, "--headless", "--path", "game", "--script", "res://tests/platform/run_all.gd"], "Platform-neutral regression tests")
    run_godot([godot, "--headless", "--path", "game", "--script", "res://tests/presentation/run_all.gd"], "Visual presentation tests")
    run(["git", "diff", "--check"], "Git whitespace check")
    print("RESULT: PASS — foundation checks complete")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.CalledProcessError, json.JSONDecodeError) as exc:
        print(f"RESULT: FAIL — {exc}", file=sys.stderr)
        raise SystemExit(1)
