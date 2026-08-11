# Windows Overlay Spike Runner

Run only in a normal, real interactive Windows 10/11 desktop session with Godot `4.7.1.stable.official.a13da4feb`:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\tools\windows_overlay_spike\run_spike.ps1 -GodotPath "C:\path\to\Godot_v4.7.1-stable_win64.exe"
```

The launcher verifies the exact engine version, runs platform-neutral tests, records privacy-reviewed environment metadata, then opens `res://scenes/spikes/windows_overlay_spike.tscn`. It does not change the registry, display settings, taskbar settings, wallpaper, scaling, or global PowerShell policy.

## Controls

- `F1`, `F2`, `F3`: Minimal, Small, Expanded
- `F4`: debug panel
- `F5`: ten-second interactive recovery window
- `F6`: reset to primary-screen safe default
- `F7`: always-on-top
- `F8`: Minimal input strategy cycle
- `Esc`: save spike placement, clean up status indicator, quit

The status-indicator menu provides Small/Expanded recovery, always-on-top, temporary interaction, position reset, and quit actions. This is spike behavior—not a product decision.

## Evidence procedure

1. Start with a neutral empty editor or test window behind the spike; close notifications and private applications.
2. Copy `docs/evidence/windows-overlay/test-matrix.json` to a working branch or evidence worktree.
3. Execute each row exactly; never promote synthetic/headless results to Windows compositor evidence.
4. Save selected cropped screenshots under `docs/evidence/windows-overlay/screenshots/` using the test ID, for example `TRN-001.png`.
5. Record actual values, timestamps, evidence paths, limitations, and exact Windows configuration.
6. Capture idle CPU/memory from Task Manager or PowerShell after stabilization; GPU only if available without installing tools.
7. Review every artifact for usernames, notifications, paths, account data, and secrets before staging.
8. Update `docs/spikes/WINDOWS_OVERLAY_SPIKE.md`, status, open questions, and any evidence-supported ADR. Do not accept platform behavior from a headless or macOS run.

The current committed matrix is a prepared non-Windows baseline. Real Windows rows remain `BLOCKED_NOT_RUN` until replaced by direct evidence.
