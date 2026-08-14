# Window Modes

All modes present one authoritative simulation and one active partner. Switching mode cannot duplicate, pause unexpectedly, reset, or fork game state.

## Minimal

True transparent companion: pet animation plus brief need icon, heart, sleep symbol, or interaction hint. No persistent habitat. Pet may move along a configurable desktop edge/lane. Transparent noninteractive areas should pass mouse input where Windows/Godot behavior permits.

## Small

Default everyday compact, movable window, initially near bottom-right but freely repositionable. Shows pet, personalized habitat, compact status, quick actions, and expand control. It remains unobtrusive.

## Expanded

Optional inspection/customization/management for detailed values, history, inventory, evolution, battle/dungeon, habitat, and later farm. It remains practical and leaves desktop context visible. One resizable window versus several compact panels is provisional.

## Milestone 4 product shell

The current Godot shell keeps one authoritative `PetApplication` state across all three modes. Minimal exposes only pet-local activity/injury/battle/dungeon/evolution status; Small adds context-sensitive Battle/Dungeon access, level/experience, injury, pending evolution, and current adventure state; Expanded adds route/discovery, battle history, inventory, unlocks, and dungeon context. Battle and Dungeon controls are absent until their data-defined gates pass. The evolution effect and exact disclosure policy remain provisional and are not a native overlay decision.

## Prompt 4.5 player presentation

- Minimal is fixed at logical `240×160`. It contains no persistent panel/background, uses alpha-clear rendering, shows only the 128×128 animated pet/egg plus a temporary call bubble, applies no-focus and a pet-following polygonal hit region, and opens Small when the pet is clicked.
- Small is fixed at logical `560×304`. It is the compact daily habitat with title controls, six segmented status indicators, a 512×192 layered habitat and Care/Adventure/More action sets.
- Expanded defaults to `1040×640` and remains resizable. It provides a three-column management layout and tabs for Overview, Battle, Dungeon, Inventory, Codex and Evolution.
- All modes remain transparent/borderless and always-on-top in the current Windows adapter. Only Expanded is resizable. Sizes are logical Godot coordinates; the native evidence host observed `192×128`, `448×243`, and `832×512` through a non-DPI-aware window-query process at Windows 125%, while Godot diagnostics retained the canonical logical sizes.
- Mode changes use one `PetApplication`, preserve `state_revision` and pet identity, and store per-mode placement. Debug tools require `--dev-tools` and open separately.

Direct Prompt 4.5 evidence confirms Minimal transparency and outside-pet click-through. It does not accept ADR 0010 or prove taskbar/Alt+Tab control, tray lifecycle, all monitor transitions, or a full Windows 10/11 DPI matrix.

## Prompt 4.6 presentation preferences and readability

- Minimal remains `240×160` at 100% pet scale and grows only when the independent Minimal pet scale requires it. Roaming uses sprite-dependent bounds, pauses, a turn delay and metadata-controlled mirroring.
- Small is now `640×360`; Expanded is `1120×720`. Normal text starts at 16 px, titles at 18 px, comfortable primary controls at 48×44 px.
- UI scale supports Auto/100/125/150/175/200%; text supports 100/125/150/175%; standard and Minimal pet scales support 75/100/125/150/200%. These are independent.
- Versioned `user://preferences.json` is separate from simulation saves, sanitized/migrated on load and atomically replaced with backup rotation.
- Small exposes three readable context actions. Expanded keeps three columns and allocates full reflow room for enlarged German text. Settings is scrollable and keeps each label/control pair together.
- Quiet Canopy has explicit bowl, treat, bath, training, bed, medicine and departure anchors. Domain actions move only presentation state; reduced motion uses instant routing and still completes the visual action timer.

## Prompt 4.7 living presentation

- Minimal uses a deterministic weighted scheduler for stationary idle, look/rest/playful variants and bounded travel. Cursor proximity turns the pet and plays attention; a pet click plays a short reaction before opening Small. Sleeping, sickness, injury and battle suppress incompatible ambient behavior.
- Small/Expanded use the same bounded priority queue and animation profiles. Care routes to stations; sleep enters the den and loops; battle drives actor-specific attack/hit/dodge/victory/defeat sequences plus separate family effects.
- Ambient frequency is Low/Normal/High. Reduced Motion prevents ambient travel/playful locomotion, shortens presentation cadence without skipping frame markers and uses reduced effects. Hit shake, damage flash and cursor reaction are separately configurable.
- Hidden/removed mode trees suspend their animation and ambient processors. Mode switching still preserves one `PetApplication`, pet identity and state revision.

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
