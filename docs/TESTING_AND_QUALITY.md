# Testing and Quality

Evidence must match claims. Repository checks cover schemas/examples, cross-references, Godot headless open/import, Markdown links/local paths, references, prohibited terminology, generated artifacts/binaries, final tree, contradictions, and `git diff --check`.

## Prompt 1 overlay evidence

- `game/tests/platform/run_all.gd`: 41 deterministic assertions for placement, recovery, persistence envelopes, transition invariants, near-edge mode switching, stress transitions, hit-region bounds, platform adapter selection, and the headless/native evidence gate.
- `game/scenes/spikes/windows_overlay_spike.tscn`: parser/runtime smoke target; successful headless startup is not native-window proof.
- `docs/evidence/windows-overlay/test-matrix.json`: all 49 required rows with environment, configuration, method, expected, actual, status, artifacts, notes, and timing fields.
- Current matrix after Prompt 3.5: 10 `PASS`, 10 `PASS_WITH_LIMITATION`, 28 `BLOCKED_NOT_RUN`, 1 `NOT_AVAILABLE`, 0 `FAIL`.
- `tools/windows_overlay_spike/run_spike.ps1`: exact-version Windows launcher and evidence path.
- `docs/evidence/macos-overlay/test-matrix.json`: separate macOS results with direct native, headless-only, unavailable, and blocked cases kept distinct.
- macOS matrix: 15 `PASS`, 10 `PASS_WITH_LIMITATION`, 4 `FAIL`, 8 `BLOCKED_NOT_RUN`, 5 `NOT_AVAILABLE`.
- `tools/macos_overlay_spike/`: exact-version native runners plus deterministic pointer probes used for direct input and drag reproduction.

Headless, macOS, API presence, synthetic geometry, and unit tests must never be reported as evidence of Windows compositor, shell, input routing, DPI movement, tray, or performance behavior. Prompt 3.5 adds direct Windows process/window diagnostics and privacy-safe native captures, but lock-screen-limited shell interactions remain explicitly blocked. Headless macOS validates logic only; `DisplayServer=headless` is explicitly rejected by the native adapter gate.

## Milestone 2 foundation evidence

- `game/tests/foundation/run_all.gd`: 112 deterministic assertions; the symlink fixture is explicitly skipped when the host cannot create links.
- Content coverage: bundled/external common loader, stable snapshot, topology/priority, required/optional dependencies, conflicts, disabled/total-conversion policy, explicit and unauthorized overrides, skin restrictions, duplicate packs/IDs, invalid IDs/API/manifests/documents, logical diagnostics, traversal, absolute paths, unsupported media, executable payloads, symlinks, localization, and reference explanations.
- Time coverage: normal/zero elapsed, rollback, negative drift, forward jump, cap, missing/invalid UTC, and fake wall/monotonic clocks.
- Save coverage: v3 round trip, validated replacement, backup, malformed-primary recovery, both-invalid failure, size/type guards, sequential v1/v2 migration/idempotence, canonical content-snapshot comparison, concurrent-writer rejection, quarantine, raw preservation, and restoration.
- Gate/bootstrap coverage: pass/fail, `all`/`any`/`not`, explanations, repeat determinism, idempotent grants, duplicate prevention, and injected platform-neutral service composition.
- `tools/run_foundation_checks.py`: JSON parse, in-memory Python compile, Python content validation, vertical-slice asset validation, Markdown links, mod payload/symlink scan, terminology scan, repository artifact/cache scan, Godot import, foundation/pet/Milestone 4/platform tests, and `git diff --check`.

Headless tests prove only platform-neutral foundation behavior. Direct Windows diagnostics now supplement them; native shell acceptance remains pending.

## Milestone 3 vertical-slice evidence

- `game/tests/pet/run_all.gd`: 44 deterministic assertions covering three starters, egg state, hatch progress and timed hatching, required bindings, nickname, meal/digestion/waste/cleaning, training, sleep/wake, ailment/treatment, attention calls and missed care mistakes, bounded simulated time, all three view models, save/reload, malformed numeric values, unavailable commands, transaction rollback, invalid record shape, and missing-content quarantine.
- `tools/art_pipeline/validate_vertical_slice_assets.py`: the Milestone-3 baseline validated 109 referenced RGBA assets with minimum 48×48 dimensions; the current stricter result is recorded under Prompt 4.6.
- `game/src/domain/pet_simulation.gd`: pure domain transition boundary; test inputs use fixed fake time and explicit simulated seconds.
- `game/src/app/pet_application.gd`: application/save/catalog boundary; test fixture uses a disposable local save path.
- `game/scenes/pet_game.tscn`: headless startup smoke target. Prompt 3.5 direct Windows product evidence is catalogued in [`PROMPT_0035_INTERACTIVE_PRODUCT_REVIEW.md`](PROMPT_0035_INTERACTIVE_PRODUCT_REVIEW.md); screen-reader, contrast, and reduced-motion acceptance remain open.

## Milestone 4 evidence

- `game/tests/milestone_four/run_all.gd`: 62 deterministic assertions covering all six good/poor family routes, evidence and identity preservation, pending safe-point evolution, identical battle seeds, stance/session persistence, rounds/win/experience/history, injury/treatment, dungeon event/rest/boss flow, first-clear rewards, theme/trophy/unlock persistence, and save/reload.
- `tools/content_validation/validate_content.py`: latest run passed with 2 packs and 86 content documents after Python schema/runtime parity checks.
- `tools/art_pipeline/validate_vertical_slice_assets.py`: the Milestone-4 baseline passed with 109 referenced RGBA PNGs; the current stricter result is recorded under Prompt 4.6.
- Isolated Windows Godot gameplay review used the normal GUI client and the existing `PrintWindow` crop helper. Automatic Mossblüte evolution in Expanded mode was directly captured; native overlay, shell, tray, Alt+Tab, mixed-DPI, and accessibility acceptance were not claimed.

Future quality layers:

- Additional pure pet-domain boundary tests with fixed seeds and property-style invariants
- Broader filesystem fault injection across every backup/rename failure branch
- Long offline intervals, clock rollback, cap, and version-transition tests
- Scene/UI interaction tests across Minimal, Small, and Expanded modes
- Rendered screenshots at compact sizes, DPI scales, and accessibility settings
- Windows hardware/VM matrix for overlay behavior and multi-monitor recovery
- Content-pack contract fixtures, including the bundled base pack

Automated screenshots/video and AI review support art QA, but do not replace runtime/accessibility evidence. CI is deferred until the first workflow can run deterministically on supported environments.

## Prompt 4.5 presentation-rebuild evidence

- `game/tests/presentation/run_all.gd`: `121` assertions for transparent project clear, no legacy scrolling debug shell, explicit dev-tool gate, component contracts, mode dimensions, shared state revision/identity, progression gates, deterministic habitat layers, required assets, DE/EN localized keys, text wrapping/overflow, 100/125/150% logical bounds, action handlers, and Minimal scene hierarchy.
- `tools/art_pipeline/validate_vertical_slice_assets.py`: validates referenced sheets as RGBA, required animation names, frame size/count geometry, and alpha presence; current visual batch result: `212` PNGs, all animation geometry valid, `211` with transparent pixels.
- `tools/visual_review/capture_visual_rebuild.ps1`: isolated-save native Windows captures using the exact pinned Godot binary.
- `tools/visual_review/record_interactive_video.ps1`: physical-screen MJPEG frame capture with real mouse input, foreground F1/F3 key events, native window-size gates and an underlay hit-test target.
- [`evidence/visual-rebuild/README.md`](evidence/visual-rebuild/README.md): reproduction, coverage, hashes, native diagnostic claims and evidence limits.

The native video directly proves the requested Minimal → Small → care → Expanded → Minimal sequence and outside-pet click-through on the recorded Windows 11 / 125% host. It does not prove every DPI, taskbar/Alt+Tab policy, tray lifecycle, screen-reader output or release build.

## Prompt 4.6 animation and UI-polish evidence

- `game/tests/presentation/run_all.gd`: 312 assertions covering eight-frame playable locomotion, complete metadata, animation priority, stale-timer/replay prevention, preferences defaults/type guards/backup recovery/migration/persistence, habitat anchors/delta movement/reduced-motion completion, localization, 100–200% bounds and explicit review-only demo gating.
- `tools/art_pipeline/validate_vertical_slice_assets.py`: 212 PNGs, valid animation geometry and 211 alpha-bearing PNGs; bundled playable walks must provide 6+ frames and GIF evidence.
- `docs/evidence/animation-polish/previews/`: nine ten-fps walk GIFs. `contact-sheets/walk-cycles.png` displays all 72 normalized frames.
- Native Windows debug screenshots cover Small 100/150%, Expanded 100% and text 150%, Settings, Minimal pet 75/150%, bowl approach, training approach and sleeping at the den. Adjacent JSON records viewport/window, scale, animation state and anchor.
- `animation-polish-film.avi`: 184 MJPEG frames, 1600×1000, 8 fps, 23 seconds; review sequence covers roaming/turn, feed, train, sleep, Expanded, live 125% UI scale and Minimal.
- `performance.json`: seven native scenarios sampled for four seconds each. CPU is normalized to 16-logical-processor total capacity; RAM is working set. GPU counters were unavailable in the deterministic harness and are not claimed.
- Computer-use initialization failed with `EPERM: operation not permitted, lstat 'C:\Users\s3ish\AppData\Local\OpenAI\Codex'`; native Godot/Win32 capture was used instead. This does not constitute formal keyboard/screen-reader accessibility testing.

## Prompt 4.7 living-animation evidence

- `game/tests/presentation/run_all.gd`: `1053` assertions covering 29-state playable coverage, five-state enemy coverage, geometry/markers, queue priority/dedup/overflow/cancel, marker completion, true Reduced Motion playback, preferences migration/type guards, ambient determinism, Minimal/Habitat constraints, combat terminal poses and hidden playback suspension.
- `tools/art_pipeline/validate_vertical_slice_assets.py`: `373` PNGs, `372` with transparency; validates complete player/enemy animation sets, `4–8`-frame geometry, alpha, frame uniqueness, event markers, twelve family VFX sheets and generated review evidence.
- Native Movie Writer evidence: seven AVI recordings, complete and dense contact sheets, ten selected PNG frames, three family reels plus a combined reel. Godot logs are rejected on `SCRIPT ERROR:` or `ERROR:` even when the process exit code is zero.
- `tools/visual_review/make_video_contact_sheet.py` and `extract_video_frame.py`: bounded evidence-only input/output paths, maximum `256 MiB` source video and bounded sample count; pinned review dependencies stay outside the game runtime.
- `performance.json`: eight isolated four-second native scenarios. Result: `59–60 FPS`, at most `1.843%` total 16-thread CPU capacity, `203.44 MiB` peak working set and `10.59 MiB` peak texture memory. GPU counter unavailable and not claimed.
- Win32 `PrintWindow` returned blank Godot/Vulkan frames; the capture helper now rejects near-uniform captures. Physical-screen evidence was also rejected because occluding windows can contaminate it. Prompt 4.7 accepts only Movie Writer frames.
- Mutating `--review-actions`, demo scenarios and `--dev-tools` require both an explicit flag and a debug build; release builds ignore those paths and may only emit requested diagnostics.
- Formal keyboard traversal, screen-reader output, full manual contrast, all Windows DPI/monitor transitions and macOS/Linux overlay behavior remain untested.

## Prompt 4.6 hardening audit

- Ruff `0.16.2`: all repository Python tools pass.
- GDLint from gdtoolkit `4.5.0`: all repository GDScript passes the checked semantic rule set in `gdlintrc`.
- `pip-audit 2.10.1`: pinned `jsonschema==4.25.0` and `Pillow==12.3.0` dependency sets have no known vulnerability advisories at audit time.
- No `package.json`, npm lockfile, Node runtime dependency, or JavaScript/TypeScript source exists; `npm audit`, npm lint, and npm build are therefore not applicable.
- Path and resource guards cover evidence outputs, temporary capture directories, frame count/rate/duration/dimensions, contact-sheet pixels, PNG dimensions, Save JSON bytes, malformed value types, and invalid active records.
- Save/application race coverage includes atomic replacement, backup recovery, stale-writer rejection, action-timer revision checks, and state rollback after failed commands or persistence.
- `.gitignore` explicitly excludes Godot imports/cache, Python bytecode/cache, Ruff/GDToolkit caches, generated source output, tool temp/output, previews, editors, OS metadata, local environment files, secrets, and exports. Committed evidence remains intentionally visible.
