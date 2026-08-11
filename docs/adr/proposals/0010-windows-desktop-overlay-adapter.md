# Proposal 0010: Windows Desktop Overlay Adapter and One-Window Baseline

**Status:** Proposed — blocked pending interactive Windows evidence
**Date:** 2026-08-11

## Context

KoalaPet requires Minimal, Small, and Expanded over one authoritative state. Godot 4.7 exposes high-level native-window, transparency, passthrough, dragging, focus, monitor, and status-indicator APIs, but Prompt 1 ran on macOS. API inspection and headless logic cannot establish Windows compositor or shell behavior.

## Proposed decision

Keep a narrow `DesktopWindowAdapter` contract. Use one native root `Window` reconfigured across all three presentations. Implement Windows behavior through `WindowsDesktopWindowAdapter`; keep placement sanitation and mode coordination platform-neutral. Add no native extension until a measured high-level API gap requires it.

## Current evidence

- Godot 4.7.1 parsed/imported the complete harness and started the spike scene headlessly.
- 39 deterministic assertions passed for geometry, persistence envelope, recovery, transitions including a near-edge mode switch, and hit-region bounds.
- Official Godot documentation exposes required baseline APIs but no dedicated taskbar/Alt+Tab visibility controls.
- No interactive Windows behavior was run.

## Expected consequences

- Future presentation/domain code remains independent from Win32.
- One-window transitions minimize duplicate state, tray, focus, and native-resource risk.
- Unsupported and degraded outcomes remain explicit.
- A future isolated bridge may be needed for `WS_EX_TOOLWINDOW`/`WS_EX_NOACTIVATE`-class behavior.

## Known limitations

Transparency, input routing, activation, topmost behavior, native drag, taskbar/Alt+Tab, tray, DPI, multi-monitor, lifecycle, and resource use remain unverified. Windows polygonal passthrough may clip all drawing outside the region.

## Rejected for now

- Multiple production windows: no demonstrated need and higher lifecycle/state risk.
- Immediate GDExtension/DLL: the gap is documented but not yet proven necessary for accepted product behavior.
- Full-screen transparent overlay: risks invisible input blocking and violates compact-window intent.

## Acceptance or superseding trigger

Run the full matrix on interactive Windows 10/11. Accept only if one-window high-level behavior is robust enough and limitations are explicit. Supersede if evidence requires multiple native windows, a different renderer, or a minimal native bridge.
