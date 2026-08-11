# macOS Overlay Evidence

Supplementary Prompt 1 validation on macOS. It is neither a macOS release commitment nor Windows evidence.

## Inventory

- `environment.json`: privacy-reviewed host, Godot, renderer, and display facts.
- `test-matrix.json`: 42 results; every row identifies platform, OS, environment, reproduction, direct evidence, and status.
- `measurements.json`: approximate native resource samples and the directly observed 30 Hz polygon update rate.
- `logs/native-session-findings.txt`: concise native diagnostics and event observations.
- `logs/platform-neutral-tests.txt`: Godot headless result, including the native-evidence gate.
- `screenshots/`: privacy-safe native captures. SHA-256 values are listed below.

## Screenshot reproduction

| Artifact | Reproduction | SHA-256 |
|---|---|---|
| `MAC-TRN-001-minimal-transparency.png` | Start the underlay, then Minimal in hit-region mode; capture the overlap. | `6d6f089bd0c212737191234041e4724bff678bc3e8dac883ba937844439ac06b` |
| `MAC-INP-001-full-passthrough.png` | Start Minimal with `--input=full_passthrough`; click through it and capture the incremented underlay counter. | `599606ddf157c9fb6dee42bd337be3a66e5004b3d7bc003c546a9bb1f14a3f29` |
| `MAC-MOD-001-small-topmost.png` | Start Small with `--always-on-top`, activate the underlay, and capture the overlap. | `90b397cc034cbc1ecbe1e90de02e21f1df6b92ab8c984d9141d696dab0071c0c` |
| `MAC-TOP-002-disabled.png` | Disable always-on-top, activate the underlay, and capture it covering the overlay. | `fcf479290157228e4c322fa4597e78faf9aed93b1077810ce8a597167aa43b7f` |
| `MAC-TRY-001-status-item-missing.png` | Launch the spike and capture the menu bar; the expected generated item is absent. | `5cb02eabfe69f8327d3f940b1f69d0643d8677f63c4aff1ebdde3820099db56d` |

Commands:

```sh
tools/macos_overlay_spike/run_underlay.sh --position=180,120
tools/macos_overlay_spike/run_spike.sh --mode=minimal --input=hit_region --position=300,240
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/platform/run_all.gd
```

The native runners require an interactive display. The final command intentionally validates only platform-neutral behavior; `ENV-HEADLESS-002` rejects it as native-window evidence.
