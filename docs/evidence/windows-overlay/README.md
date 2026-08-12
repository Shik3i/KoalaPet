# Windows Overlay Evidence

**Completion state:** `INTERACTIVE_WINDOWS_PARTIAL`

Prompt 1 was prepared on macOS; Prompt 3.5 added a direct Windows 11 run. Native creation, transparency flags, hit-region state, monitor/taskbar inventory, status-indicator creation, renderer diagnostics, and idle performance are now recorded. Foreground mouse/shell routing, Alt+Tab/taskbar policy, tray callbacks, restore paths, and mixed-DPI parity remain limited or blocked. Full scope and screenshots: [`PROMPT_0035_INTERACTIVE_PRODUCT_REVIEW.md`](../../PROMPT_0035_INTERACTIVE_PRODUCT_REVIEW.md).

- `test-matrix.json`: machine-readable required matrix and current statuses
- `environment.windows.json`: privacy-reviewed direct Windows host metadata
- `native-diagnostics.*.json`: direct Godot Windows overlay diagnostics for Minimal, Small, and Expanded
- `measurements.json`: direct Windows product idle samples and native spike FPS/update measurements
- `logs/platform-neutral-tests.txt`: direct headless logic-test output
- `screenshots/`: reserved for selected privacy-reviewed Windows desktop evidence

Use `tools/windows_overlay_spike/run_spike.ps1` on a real interactive Windows host. Replace statuses only with direct evidence. Headless/CI import may support parsing but cannot prove desktop behavior.
