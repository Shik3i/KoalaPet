# Window Modes

All modes present one authoritative simulation and one active partner. Switching mode cannot duplicate, pause unexpectedly, reset, or fork game state.

## Minimal

True transparent companion: pet animation plus brief need icon, heart, sleep symbol, or interaction hint. No persistent habitat. Pet may move along a configurable desktop edge/lane. Transparent noninteractive areas should pass mouse input where Windows/Godot behavior permits.

## Small

Default everyday compact, movable window, initially near bottom-right but freely repositionable. Shows pet, personalized habitat, compact status, quick actions, and expand control. It remains unobtrusive.

## Expanded

Optional inspection/customization/management for detailed values, history, inventory, evolution, battle/dungeon, habitat, and later farm. It remains practical and leaves desktop context visible. One resizable window versus several compact panels is provisional.

## Prompt 3.5 Windows evidence

The first direct Windows run was completed on 2026-08-12 with Windows 11 Pro `10.0.26200`, Godot `4.7.1.stable.official.a13da4feb`, three monitors, per-monitor-aware PowerShell capture, primary 125% scaling, a bottom non-auto-hidden taskbar, and an NVIDIA RTX 4080 SUPER. The native spike reached `READY` for native window creation, borderless/transparency flags, transparent viewport, polygonal hit regions, focus policies, monitor enumeration, status indicator creation, and 60 FPS at the configured cap. Evidence is in [`PROMPT_0035_INTERACTIVE_PRODUCT_REVIEW.md`](PROMPT_0035_INTERACTIVE_PRODUCT_REVIEW.md).

Not accepted: direct mouse/underlay routing, Alt+Tab, taskbar policy, tray menu callback/cleanup, minimize/restore from the shell, and mixed-DPI parity. The active Windows lock screen prevented foreground interaction; native Godot monitor DPI values also require reconciliation with the per-monitor-aware PowerShell values.

## Required Prompt 1 evidence

On Windows 10/11 test transparency, passthrough, hit regions, always-on-top, dragging, focus, DPI scaling, taskbar and auto-hide edges, mixed-DPI multiple monitors, minimize/restore, lost-window recovery, and persisted position. Godot API presence is not proof. Supplementary host validation may inform the shared contract but cannot provide Windows evidence.

## Prompt 1 prepared implementation

- One native root `Window` is reconfigured across all modes; this is provisional pending Windows evidence.
- `WindowModeController` owns presentation transitions and per-mode placement intent without domain state.
- `DesktopWindowAdapter` defines explicit capability and degraded/unsupported results. `GodotNativeWindowAdapter` contains shared high-level mechanics; thin Windows and macOS adapters isolate host behavior.
- Minimal supports complete passthrough, polygonal hit-region, and temporary-interaction strategies in the harness. A generated status-indicator menu provides a recovery path.
- Positions are stored per mode with monitor, usable rectangle, absolute and normalized coordinates, size, scale/DPI, and bottom-right anchor metadata. Restore sanitizes against current usable rectangles.
- The code-drawn spike visual is diagnostic only. The supplied concept references are not runtime assets.

The native macOS pass validated transparency, input routing, topmost behavior, drag, Retina coordinates, per-mode placement, and selected focus behavior. It also found platform-specific activation, hide, minimize, and status-item gaps. The Windows evidence is partial and does not supersede the proposed ADR; see [`spikes/MACOS_OVERLAY_SPIKE.md`](spikes/MACOS_OVERLAY_SPIKE.md) and [`spikes/WINDOWS_OVERLAY_SPIKE.md`](spikes/WINDOWS_OVERLAY_SPIKE.md).
