# Prompt 3.5 — Interactive Windows validation and product review

**Date:** 2026-08-12
**Host:** Windows 11 Pro `10.0.26200` build `26200`, interactive local session, not remote
**Godot:** `4.7.1.stable.official.a13da4feb`
**Renderer:** `gl_compatibility`, `opengl3`
**GPU:** NVIDIA GeForce RTX 4080 SUPER, driver `32.0.16.1062`
**Monitors:** 3; primary `2560x1440` at 125%, two side displays at 100% in the per-monitor-aware environment capture
**Taskbar:** bottom, non-auto-hidden; direct bounds `[0,1380,2560,60]`

## Interactive findings

The product ran through the real Godot Windows process with isolated review saves:

- new save and three separate starter runs: Moss, Ember, Tide
- egg selection, visible hatch progress, development hatch, nickname field
- Feed, Treat, Clean, Train, Sleep, Wake, Sickness, Medicine
- attention call and missed-call state through deterministic review actions/tests
- save and relaunch with the active pet restored
- Minimal, Small, and Expanded product modes
- English/Deutsch toggle path present; final screenshots use German

Direct product evidence:

- [`PROD-STARTER-final.png`](evidence/windows-overlay/screenshots/PROD-STARTER-final.png)
- [`PROD-EGG-moss-final.png`](evidence/windows-overlay/screenshots/PROD-EGG-moss-final.png)
- [`PROD-EGG-ember.png`](evidence/windows-overlay/screenshots/PROD-EGG-ember.png)
- [`PROD-EGG-tide.png`](evidence/windows-overlay/screenshots/PROD-EGG-tide.png)
- [`PROD-PET-sick-moss.png`](evidence/windows-overlay/screenshots/PROD-PET-sick-moss.png)
- [`PROD-PET-medicine-moss.png`](evidence/windows-overlay/screenshots/PROD-PET-medicine-moss.png)
- [`PROD-PET-sleep-moss.png`](evidence/windows-overlay/screenshots/PROD-PET-sleep-moss.png)
- [`PROD-PET-wake-moss.png`](evidence/windows-overlay/screenshots/PROD-PET-wake-moss.png)
- [`PROD-PET-expanded-moss.png`](evidence/windows-overlay/screenshots/PROD-PET-expanded-moss.png)
- [`PROD-PET-relaunch-small.png`](evidence/windows-overlay/screenshots/PROD-PET-relaunch-small.png)

The capture mechanism uses the real native Godot window handle and `PrintWindow` for privacy-safe evidence. The Windows desktop was not copied into product screenshots.

## Confirmed defects fixed

1. Starter view clipped the third egg and omitted imported preview images. Fixed with a three-column grid, explicit card sizing, imported asset loading, and final starter evidence showing all three choices.
2. Starter and action labels fell back to missing-key English strings in German. Fixed by using existing localization keys and adding the missing hatch/status labels in both locales.
3. Expanded history and Small-mode status feedback were below the fixed viewport. Fixed with a scroll container and a visible header status line.
4. Sickness added a Resolve action that was clipped in the fixed action row. Fixed with a compact four-column action grid; Medicine, Sleep, Wake, and Resolve remain reachable in the visible Small layout.
5. Hatch progress was not exposed in the view model/product screen. Fixed with deterministic `hatch_progress_bps`, a progress bar, and a percentage label.
6. Product mode refreshes reset the window size on every action. Fixed so size is applied only when the mode changes.

No P0 was found. No native Windows acceptance claim is made for the remaining shell-level blockers.

## Windows overlay evidence

The existing native overlay spike reached `READY` on Windows. Direct native diagnostics are stored as:

- [`native-diagnostics.minimal.json`](evidence/windows-overlay/native-diagnostics.minimal.json)
- [`native-diagnostics.small.json`](evidence/windows-overlay/native-diagnostics.small.json)
- [`native-diagnostics.expanded.json`](evidence/windows-overlay/native-diagnostics.expanded.json)
- [`environment.windows.json`](evidence/windows-overlay/environment.windows.json)

Directly evidenced: Windows adapter selection, native window creation, borderless mode, transparency flags, transparent viewport, polygonal hit-region state, normal/no-focus policies, status indicator creation/visibility, monitor enumeration, usable rectangles, taskbar edge/state, renderer/GPU diagnostics, and 60 FPS at `Engine.max_fps=60`.

Still blocked or limited: foreground-window takeover was prevented by the active Windows lock screen; therefore native mouse clicks, Alt+Tab, Show Desktop, tray menu activation, minimize/restore by shell, hide/show recovery, and underlying-application routing were not directly observed. Godot diagnostics report mixed-DPI monitor data differently from the per-monitor-aware PowerShell capture; this remains a platform adapter blocker, not an accepted DPI result.

Native spike screenshots:

- [`SPIKE-MINIMAL-native.png`](evidence/windows-overlay/screenshots/SPIKE-MINIMAL-native.png)
- [`SPIKE-SMALL-native.png`](evidence/windows-overlay/screenshots/SPIKE-SMALL-native.png)
- [`SPIKE-EXPANDED-native.png`](evidence/windows-overlay/screenshots/SPIKE-EXPANDED-native.png)

## Accessibility and performance

- Keyboard focus is present on starter choices, mode buttons, action buttons, and nickname save.
- German and English localization paths are wired; no visible missing-key fallback remained in the reviewed screens.
- Small action controls wrap into a compact grid; status and sickness state remain visible without relying on color alone.
- Accessibility acceptance is incomplete: no screen-reader inspection, contrast audit, or user-facing reduced-motion setting was run.
- Idle product process samples: Small `167.6 MB` working set / `0.43%` CPU normalized over 16 logical processors; Expanded `166.8 MB` / `0.43%`; Minimal `167.0 MB` / `0.43%`.
- Native overlay spike reported `60.0 FPS` in all three modes at `Engine.max_fps=60`; GPU utilization was not collected.
- Measurements: [`measurements.json`](evidence/windows-overlay/measurements.json).

## Deterministic and automated validation

- Pet suite: `PASS (32 assertions)`; includes starter, hatch progress, care, waste, attention call, missed call/care mistake, sickness, medicine, sleep/wake, save/reload, and quarantine.
- Existing foundation suite and platform-neutral suite remain required before commit; headless runtime is not native Windows evidence.

## Blockers

- Native Windows shell behavior remains incomplete: Alt+Tab/taskbar policy, tray callbacks/cleanup, focus behavior under the lock screen, shell restore paths, and direct underlying-app routing.
- Mixed-DPI native diagnostics need a Windows-specific DPI bridge or accepted adapter decision before native overlay acceptance.
- No export, signing, packaging, release, or deployment evidence.
- Provisional art remains development-only with `UNDECIDED` provenance/license.

## ADR and recommendation

ADR 0010 remains **proposed**, not accepted. The current evidence is sufficient to keep the Windows adapter spike as the implementation direction and insufficient to accept it as a production overlay contract.

Recommendation: do not start Milestone 4 yet. Finish the remaining native Windows shell/DPI evidence and accessibility review, then accept or supersede ADR 0010. The single-pet vertical slice is suitable for continued product review and art/content decisions.
