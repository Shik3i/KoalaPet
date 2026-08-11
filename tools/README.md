# Repository Tools

- `content_validation/`: draft schema, pack, reference, and path validation
- `art_pipeline/`: reserved for deterministic image/animation processing
- `repository/`: repository-wide quality checks
- `windows_overlay_spike/`: interactive Windows Prompt 1 launcher and evidence collection
- `macos_overlay_spike/`: supplementary macOS native runner, neutral underlay, and deterministic pointer probes

Tools are local, deterministic, and must not require accounts or network services.

Run the complete local Milestone 2 gate with the pinned Python environment:

```sh
.venv/bin/python tools/run_foundation_checks.py
```

On other hosts, pass the pinned executable with `--godot` or set `GODOT_PATH`.
