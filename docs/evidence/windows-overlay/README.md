# Windows Overlay Evidence

**Completion state:** `PREPARED_BUT_BLOCKED`

Prompt 1 was prepared on macOS, not an interactive Windows 10/11 desktop. `environment.json` and the platform-neutral test log describe the preparation host only. They are not evidence for Windows transparency, compositor output, focus, passthrough, taskbar, Alt+Tab, tray, DPI, multi-monitor, or performance behavior.

- `test-matrix.json`: machine-readable required matrix and current statuses
- `environment.json`: privacy-reviewed preparation-host metadata
- `measurements.json`: empty Windows measurement envelope
- `logs/platform-neutral-tests.txt`: direct headless logic-test output
- `screenshots/`: reserved for selected privacy-reviewed Windows desktop evidence

Use `tools/windows_overlay_spike/run_spike.ps1` on a real interactive Windows host. Replace statuses only with direct evidence. Headless/CI import may support parsing but cannot prove desktop behavior.
