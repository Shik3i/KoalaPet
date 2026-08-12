# Windows Desktop Overlay Spike

**Milestone:** Prompt 1
**Completion state:** `INTERACTIVE_WINDOWS_PARTIAL`
**Starting commit:** `9e06f25f0e4cdbc5d739f8b79a5d1f0aa0e77310`

The reusable harness, Windows launch/diagnostic scripts, platform adapter contract, placement store, pure tests, evidence structure, and full matrix were prepared. A real Windows 11 run is now recorded. Native creation, transparency flags, hit-region state, monitor/taskbar inventory, status-indicator creation, renderer diagnostics, and idle performance were directly captured. Shell input, Alt+Tab/taskbar policy, tray callbacks, restore paths, and mixed-DPI parity remain unaccepted.

A separate native macOS pass is recorded in [`MACOS_OVERLAY_SPIKE.md`](MACOS_OVERLAY_SPIKE.md). It informs the shared adapter design but does not change a single Windows row.

## Preflight

| Item | Result |
|---|---|
| Repository | Clean `main`, tracking `origin/main`; `git pull --ff-only` returned `Already up to date.` |
| Host | Windows 11 Pro `10.0.26200` build `26200`, interactive local session |
| Session | `UserInteractive=True`, remote session `False`; foreground shell was at the Windows lock screen during native input attempts |
| Hardware | Micro-Star International `MS-7E26`; 16 logical processors; 33,397,133,312 bytes RAM; NVIDIA GeForce RTX 4080 SUPER |
| Godot | `C:\tmp\Godot-4.7.1\Godot_v4.7.1-stable_win64.exe`, `4.7.1.stable.official.a13da4feb` |
| Project renderer | `gl_compatibility`; native spike used Windows DisplayServer and `opengl3` driver |
| Displays/taskbar | 3 monitors; primary 2560×1440 at 125%, two side monitors at 100%; taskbar bottom, 60 px, auto-hide false |

Headless DisplayServer functions return dummy values by design and are not window evidence.

Reference SHA-256 values: Expanded `45d5be185a125a2469dc2bea766f969bdc12d64dd1d61bf2f71f0a598ff7d48b`; Small `3dea25f463d20b2313fa7845ec409ee1d211ef53d859264217225b41e2f6c40c`; Minimal `330b8e4be2931d78d54845385573e82fd813bb4339b2af3ea04558048250b839`.

## Harness architecture

- `WindowModeController`: one authoritative presentation state and per-mode placement memory.
- `DesktopWindowAdapter`: platform-neutral operations and explicit unsupported results.
- `WindowsDesktopWindowAdapter`: Godot high-level Windows implementation, host-gated and capability-reporting.
- `OverlayPlacementSanitizer`: deterministic monitor fallback, normalized anchoring, usable-rect clamping, and off-screen recovery.
- `OverlayPlacementStore`: spike-only version `1` JSON envelope with temporary file, backup rotation, and replaceable write.
- `DesktopOverlaySpike`: one native root `Window` reconfigured across Minimal, Small, and Expanded; technical code-drawn placeholder only.
- `StatusIndicator` recovery menu: generated icon, native-menu preference, cleanup on exit. Product adoption remains open.
- `run_spike.ps1` and `collect_environment.ps1`: exact-version gate, test execution, privacy-reviewed diagnostics, and launch.

The harness does not enter domain, content, gameplay, or future save repositories. `game/src/platform/` owns OS behavior; `game/src/presentation/` owns mode coordination; `game/src/spikes/` owns temporary UI and placement persistence.

## Official API findings

Primary sources only:

- Godot [`Window`](https://docs.godotengine.org/en/4.7/classes/class_window.html) can be native or embedded. Native behavior requires subwindow embedding disabled; `Window` exposes borderless, always-on-top, transparent, unfocusable, complete mouse passthrough, polygonal passthrough, position/size, screen, visibility, minimize/window modes, `start_drag()`, focus/close signals, and runtime reconfiguration.
- Transparency needs all three conditions: [`display/window/per_pixel_transparency/allowed`](https://docs.godotengine.org/en/4.7/classes/class_projectsettings.html), `Window.transparent`, and `Viewport.transparent_bg`. Availability still depends on driver, display manager, and compositor; the project setting has a documented performance cost.
- Godot [`DisplayServer`](https://docs.godotengine.org/en/4.7/classes/class_displayserver.html) exposes screen count, primary screen, position, size, usable rectangle, scale, DPI, current-screen queries, and polygonal mouse passthrough. On Windows, content outside the accepted polygon is documented as **not drawn**. This must be tested against the moving placeholder and transient effects.
- `Window.start_drag()` uses native interactive dragging and participates in operating-system tiling/space behavior. Native drag is the default spike strategy; manual pointer-driven movement is not implemented.
- `Window.dpi_changed` is documented only for macOS and Linux Wayland, not Windows. Windows movement diagnostics must therefore query current screen/scale/DPI during the matrix rather than depend on that signal.
- Godot [`StatusIndicator`](https://docs.godotengine.org/en/4.7/classes/class_statusindicator.html) is implemented on Windows and macOS and supports a native popup menu when `NativeMenu.FEATURE_POPUP_MENU` is available. Runtime visibility, callback behavior, restoration, and cleanup remain blocked.
- [`RenderingServer`](https://docs.godotengine.org/en/4.7/classes/class_renderingserver.html) provides actual rendering method, driver, and adapter diagnostics. Headless runs intentionally return no adapter name.
- Godot 4.7 `Window`/`DisplayServer` exposes no dedicated high-level control for taskbar presence or Alt+Tab presence. Microsoft documents [`WS_EX_TOOLWINDOW`](https://learn.microsoft.com/en-us/windows/win32/winmsg/extended-window-styles) as excluding a tool window from taskbar and Alt+Tab, and `WS_EX_NOACTIVATE` as preventing click activation. The official Godot 4.7 Windows source is [`display_server_windows.cpp`](https://github.com/godotengine/godot/blob/4.7/platform/windows/display_server_windows.cpp); no product bridge is added in this spike.

API availability supports harness feasibility. It does not establish Windows behavior.

## Matrix summary

| Status | Count | Meaning |
|---|---:|---|
| `PASS` | 10 | Host/engine, monitor/taskbar inventory, and deterministic placement/persistence logic |
| `PASS_WITH_LIMITATION` | 10 | Native diagnostics, synthetic geometry/state-machine, status-indicator, and idle/performance evidence with explicit limits |
| `FAIL` | 0 | Nothing was executed and observed to fail |
| `BLOCKED_NOT_RUN` | 28 | Requires unlocked shell interaction or untested Windows configurations |
| `NOT_AVAILABLE` | 1 | A second non-100% comparison configuration was unavailable |
| `NOT_APPLICABLE` | 0 | No required row was removed |

Machine-readable source: [`test-matrix.json`](../evidence/windows-overlay/test-matrix.json).

| ID | Status | Current result |
|---|---|---|
| ENV-001 | PASS | Windows 11 10.0.26200, interactive and non-remote |
| ENV-002 | PASS | Godot/Windows renderer/GPU recorded |
| ENV-003 | PASS | Three Windows monitors, usable rects, DPI, and primary state recorded |
| ENV-004 | PASS | NVIDIA adapter/driver and Godot adapter recorded |
| TRN-001..004 | BLOCKED_NOT_RUN | Transparency, alpha, borderless composition, renderer comparison |
| INP-001..005 | BLOCKED_NOT_RUN | Full/polygonal passthrough, underlying-app routing, movement, recovery |
| FOC-001..006 | BLOCKED_NOT_RUN | Launch/click focus, no-focus, Alt+Tab, taskbar, Show Desktop |
| TOP-001..002 | BLOCKED_NOT_RUN | Always-on-top enabled/disabled |
| DRG-001..003 | BLOCKED_NOT_RUN | Native drag and post-drag restart evidence |
| DPI-001 | PASS | Primary 125% and side 100% capture; mixed-DPI parity remains limited |
| DPI-002 | NOT_AVAILABLE | No second non-100% comparison configuration |
| MON-001 | PASS_WITH_LIMITATION | Three monitors match in count; mixed-DPI logical rectangles differ |
| MON-002 | PASS_WITH_LIMITATION | Negative-coordinate synthetic placement passed |
| MON-003..004 | BLOCKED_NOT_RUN | Real multi-monitor and mixed-DPI movement |
| TSK-001 | PASS_WITH_LIMITATION | Synthetic usable-rect clamping passed |
| TSK-002 | PASS | Bottom taskbar, 60 px, auto-hide false recorded |
| WIN-001..003 | BLOCKED_NOT_RUN | Minimize/restore, hide/show, native close lifecycle |
| PST-001..002 | PASS | Per-mode position/size serialization and restoration passed |
| REC-001..002 | PASS | Missing-monitor/off-screen and corrupted/future-input recovery passed |
| MOD-001..002 | PASS_WITH_LIMITATION | Six paths + 100 logical stress transitions; native effects blocked |
| TRY-001 | PASS_WITH_LIMITATION | Native status indicator created/visible; tray callbacks blocked |
| TRY-002..004 | BLOCKED_NOT_RUN | Tray menu actions, restore, and cleanup |
| PERF-001..004 | PASS_WITH_LIMITATION | Product idle samples and native 60 FPS/update diagnostics; GPU delta unavailable |

## Platform-neutral evidence

Command:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/platform/run_all.gd
```

Current result: `PASS (41 assertions)`. It adds adapter-selection and headless/native-evidence gate checks to the prior geometry, recovery, persistence, transition, stress, and hit-region coverage. The Windows-host run is recorded in [`platform-neutral-tests.windows.txt`](../evidence/windows-overlay/logs/platform-neutral-tests.windows.txt); native Windows artifacts are listed in the Prompt 3.5 review report.

Headless import and a three-frame spike-scene smoke start also completed without parser/runtime errors. None validates native Windows behavior.

## Direct findings by requirement

| Area | Direct finding |
|---|---|
| Transparency | `BLOCKED_NOT_RUN`; only required API/configuration was verified. |
| Passthrough/hit regions | Pure polygon coordinate/bounds logic passed; Windows input routing and documented drawing clip remain blocked. |
| Focus/no-focus | `BLOCKED_NOT_RUN`; Godot flags exist, exact activation behavior requires Windows. |
| Always-on-top | `BLOCKED_NOT_RUN`; high-level flag wired. |
| Dragging | `BLOCKED_NOT_RUN`; `Window.start_drag()` wired. |
| Taskbar/Alt+Tab | `BLOCKED_NOT_RUN`; no dedicated high-level control found. |
| Status indicator | `BLOCKED_NOT_RUN`; generated icon/menu/recovery/cleanup harness wired. |
| DPI/multi-monitor | Synthetic negative coordinates, usable-rect, scale/DPI metadata, monitor loss, and resolution changes passed; all real Windows movement blocked. |
| Persistence/recovery | Versioned serialization, corrupted/future input, per-mode records, clamping, normalized fallback, and oversized recovery passed. Atomic failure injection and real restart remain future evidence. |
| Mode transitions | Logical invariant passed for all paths and 100 stress transitions; native flicker/focus/clipping/resource behavior blocked. |
| Performance | No measurements; all values remain `null`. |

## Provisional recommendations

These are recommendations, not accepted Windows behavior:

1. **Godot sufficiency:** likely sufficient for the first high-level window prototype—transparency, placement, passthrough, drag, topmost, monitor queries, and tray are exposed. Windows release sufficiency remains unanswered until the matrix runs.
2. **Native extension:** do not add one yet. A small isolated Windows bridge is likely only if product requirements demand reliable taskbar/Alt+Tab exclusion or true `WS_EX_NOACTIVATE` behavior while retaining selected mouse interaction.
3. **Window count:** one native root window reconfigured across all three modes. Lowest state/resource risk; consider additional windows only after a measured failure.
4. **Minimal interaction:** test polygonal hit region first, backed by status-indicator recovery and a timed interaction mode. Compare against full passthrough. Windows drawing clipping may make the polygon strategy unsuitable for effects outside the region.
5. **Status indicator:** technically promising as a Minimal recovery mechanism; baseline inclusion remains open until visibility/menu/cleanup evidence and product-owner choice.
6. **Shell presence:** Small/Expanded should provisionally behave like normal app windows. Minimal taskbar/Alt+Tab behavior remains open and may define the native-bridge requirement.
7. **Placement:** persist per-mode monitor index, absolute and normalized position, size, scale/DPI, and bottom-right anchor; sanitize against current usable rectangles and fall back to primary.
8. **Update rate:** compare normal animation with reduced idle update rates on Windows; no FPS value is selected without measurements.
9. **Renderer:** Compatibility is a low-overhead provisional baseline for this 2D shell. Compare actual transparency/alpha/performance with another supported Windows renderer before accepting it.
10. **Untested:** all Windows 10/11 behavior; GPU/driver variants; 100% and non-100% scale; negative-coordinate real monitor; multi-monitor/mixed-DPI; taskbar edges/auto-hide; Show Desktop; tray; resource use.

## Architecture decision status

No accepted ADR 0010. [`0010-windows-desktop-overlay-adapter.md`](../adr/proposals/0010-windows-desktop-overlay-adapter.md) is a proposal gated on real Windows evidence. ADR 0001 and ADR 0002 remain authoritative.

## Exact Windows continuation

Run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\tools\windows_overlay_spike\run_spike.ps1 -GodotPath "C:\path\to\Godot_v4.7.1-stable_win64.exe"
```

Execute all `BLOCKED_NOT_RUN` rows, capture privacy-reviewed evidence, compare renderers where practical, update recommendations, and accept/supersede the proposal only if evidence supports it. Prompt 2 must not begin before Prompt 1 obtains real Windows validation.
