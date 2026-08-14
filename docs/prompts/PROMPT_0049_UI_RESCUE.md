# Prompt 4.9 execution record — interactive UI/UX rescue

## Scope

Stabilise and rebuild the player-facing interface. No Milestone 5 work; no new
pets, forms, enemies, dungeons, habitat editing, farm, residents or economy.

## Reported Feed crash

The report was that clicking Feed terminated the application.

**Reproduction attempts.** Feed was driven from the real native client with real
Win32 clicks against: a clean save, the product owner's own Milestone 4 save
(copied, never modified), a hatchling, a hungry pet, a full pet, a sleeping pet, a
sick pet, an injured pet, an active battle, Small and Expanded, single clicks,
double clicks and 25-click bursts. The process never terminated and no engine error
was logged in any of them. The Godot log that would have carried the original stack
trace had already rotated out (the engine keeps five).

**Honest conclusion.** The exact reported incident could not be reproduced, so no
root cause can be claimed for it. What the investigation did find on the Feed path
were four real defects, each fixed and regression-tested:

1. **Raw engine text reached the player.** `_command_status` printed
   `result.reason` / `error_code` verbatim, so a blocked Feed rendered a developer
   string. Every outcome now resolves through `ActionFeedback` to a localized
   sentence with a severity; unknown codes fall back to one safe sentence.
2. **Duplicate submission.** Nothing prevented two Feed commands from a double
   click. A 10 ms double click produced two domain revisions. Same-command repeats
   inside 450 ms are now one intent, counted in `suppressed_duplicate_commands`.
3. **Re-entrant rebuild.** `_refresh()` clears and rebuilds the whole tree, and a
   deferred `pressed` callback arriving mid-rebuild could free controls the outer
   rebuild was still populating. Rebuilds are now guarded and re-queued.
4. **Input-blocking toast.** The status toast was an opaque `PanelContainer`
   overlapping the action area. It is now click-through and positioned over the
   habitat.

## Other defects found and fixed

- **Auto UI scale never left 100%.** `DisplayServer.screen_get_scale()` returns
  `1.0` on Windows, so the whole interface rendered at ~80% of its intended physical
  size on a 125% display — the direct cause of "tiny unclear icons and meters".
  Auto now derives from `screen_get_dpi() / 96`.
- **The window could not be resized.** `Window.content_scale_size` pinned the root
  viewport and therefore the native client area to the project's boot size. It is
  now left unset; Small and Expanded carry real `min_size` / `max_size`.
- **Icons pointed at the wrong subject.** `close` rendered the injury plaster,
  `minimize` the Minimal-mode glyph, `discipline` the training log, `call` the
  health cross. Nine missing symbols were generated and the alias table now only
  maps genuine synonyms.
- **Advancing a battle was blocked by the battle it was advancing.** The Adventure
  action reused the `battle` id while a battle ran, so the "next round" button
  disabled itself. Advancing now has its own action id.
- **Expanded overflowed its own window.** An autowrapping caption inside a narrow
  grid column collapsed to one character per line and pushed the tab row off-screen.

## Interface rebuild

See [`../PLAYER_INTERFACE.md`](../PLAYER_INTERFACE.md) for the authoritative rules.
Summary of the change:

- Small header reduced from eight mixed icon buttons to identity plus window
  controls; care, adventure and navigation moved into their own regions.
- Six tiny segmented meters replaced by four labelled meters with icon, localized
  name, percentage, coloured bar and a state word.
- Health, sickness, injury, sleep, calls, battle, dungeon and pending evolution
  became contextual alerts; the most urgent one is promoted into the header.
- Habitat wrapped in `HabitatFrame` so it scales with the window instead of sitting
  at a fixed 512×192.
- Three or four primary actions with icon and text, contextual replacement for
  Wake / Medicine / Treatment, and a labelled Care / Adventure / More footer.
- Expanded rebuilt into three columns with a right column that follows the
  selected tab.
- `UiMetrics` introduced as the single source for spacing, type, control heights
  and icon sizes.

## Validation

- `tools/run_foundation_checks.py`: `RESULT: PASS`.
- Presentation suite `4976` assertions, foundation `114`, pet `44`, milestone four
  `62`, platform `46` — all pass.
- New coverage: Feed in seven pet states across both modes, invalid-command
  mapping, duplicate suppression, single-connection and label/focus checks for
  every constructed control, Small layout bounds across five UI scales × two text
  scales, complete `ActionFeedback` × error-code × locale matrix, and the full icon
  contract.
- Ruff `0.16.2` and GDLint (gdtoolkit `4.5.0`): clean.

## Evidence

[`../evidence/ui-rescue/README.md`](../evidence/ui-rescue/README.md) — 24 viewport
captures with diagnostics, the interactive action matrix, and an explicit note on
what the harness could and could not verify on a mixed-DPI host.

## Not done

- No video recording; the rationale and replacement are documented in the evidence
  README.
- Performance was not re-measured against the Prompt 4.7 baseline.
- Screen-reader acceptance remains blocked by the engine.
