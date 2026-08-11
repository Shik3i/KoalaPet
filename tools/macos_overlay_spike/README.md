# macOS Overlay Spike Runner

This runner is evidence tooling for Prompt 1. It is not a macOS release commitment and produces no Windows evidence.

```sh
tools/macos_overlay_spike/run_underlay.sh --position=180,120
tools/macos_overlay_spike/run_spike.sh --mode=minimal --input=hit_region --position=300,240
```

Supported spike arguments:

- `--mode=minimal|small|expanded`
- `--input=interactive|hit_region|full_passthrough`
- `--focus=normal|no_focus`
- `--position=x,y`
- `--always-on-top`
- `--evidence-auto` writes current diagnostics once per second under Godot `user://`
- `--max-fps=n` applies an explicit spike-only frame cap for resource comparison

Runtime controls remain `F1`–`F11` and `Esc`. The menu-bar status item exposes recovery, diagnostics, minimize, hide, and quit actions. `macos_click_probe.swift` and `macos_drag_probe.swift` post deterministic native pointer events and report whether the invoking process has macOS Accessibility trust.

Do not change Stage Manager, Spaces, display scaling, Dock, menu-bar, or accessibility settings for the matrix. Mark unavailable configurations accurately.
