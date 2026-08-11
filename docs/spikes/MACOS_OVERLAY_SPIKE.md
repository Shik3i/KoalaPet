# macOS Desktop Overlay Validation

**Milestone:** Prompt 1 supplementary host validation

**State:** `VALIDATED_WITH_LIMITATIONS`; Windows release evidence remains blocked

## Findings

Direct native passes on macOS `26.5.2` with Godot `4.7.1`:

- Per-pixel transparency, alpha edges, and a borderless Minimal window.
- Always-on-top enabled and disabled.
- Whole-window passthrough, polygon interior/exterior routing, interaction with the neutral underlay, and a moving polygon updated at 30 Hz.
- Native dragging in Small.
- Normal focus acquisition and no-focus behavior when Minimal was already inactive.
- Retina scale/DPI reporting, menu-bar usable-area exclusion, saved per-mode positions, and native Minimal/Small/Expanded geometry changes.

Direct failures:

- Focused Small → Minimal did not release app activation: `unfocusable=true`, but the root window remained focused/frontmost.
- Root-window hide is unsupported through the Godot 4.7 high-level API: `Can't change visibility of main window.`
- The generated `StatusIndicator` reported `visible=true` with rect `[-9120,-6,44,64]`, but no item appeared in the captured menu bar; recovery controls were therefore unusable.

Limitations:

- Borderless minimize was ignored. `MacOSDesktopWindowAdapter` now temporarily restores native decoration before minimizing; this worked but is degraded behavior. Restore-through-Dock was not validated.
- The one available display was Retina scale `2.0`; multi-monitor, differing scales, and negative real coordinates were `NOT_AVAILABLE`.
- Stage Manager was disabled, so it is `NOT_AVAILABLE`, not a failure.
- Cmd+Tab, Mission Control, Spaces, Show Desktop, native close, and reliable restore remained `BLOCKED_NOT_RUN`.
- Short native samples averaged roughly `5.6%` CPU in one Minimal run. Memory tools disagreed (`89 MiB` vs `213632 KiB` RSS); no per-process GPU measurement was available. No performance target is accepted.

Matrix: 15 `PASS`, 10 `PASS_WITH_LIMITATION`, 4 `FAIL`, 8 `BLOCKED_NOT_RUN`, 5 `NOT_AVAILABLE`. See [`test-matrix.json`](../evidence/macos-overlay/test-matrix.json).

## Architecture result

`DesktopWindowAdapter` stays platform-neutral. Shared Godot high-level mechanics live in `GodotNativeWindowAdapter`; thin `WindowsDesktopWindowAdapter` and `MacOSDesktopWindowAdapter` subclasses own host selection and genuine platform differences. `DesktopWindowAdapterFactory` is the only OS selector. Domain and presentation-mode logic contain no macOS branch.

Headless Godot now passes 41 platform-neutral assertions, including an explicit gate that rejects `DisplayServer=headless` as native window evidence. The macOS findings do not change or unblock any Windows matrix row. Proposal ADR 0010 remains proposed.

Evidence: [`macos-overlay`](../evidence/macos-overlay/README.md). Windows continuation remains [`WINDOWS_OVERLAY_SPIKE.md`](WINDOWS_OVERLAY_SPIKE.md).
