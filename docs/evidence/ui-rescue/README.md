# Prompt 4.9 UI rescue evidence

Direct evidence for the interface stabilisation and rebuild. All values were
produced on Windows 11 Pro `10.0.26200` with Godot `4.7.1.stable.official.a13da4feb`
on a three-monitor host with mixed display scaling (primary at 125%).

## How the images were produced

`tools/visual_review/capture_ui_rescue.ps1` launches the real native client per
scenario against a disposable save, preference and placement file, then reads the
frame back **from the application's own viewport** (`--capture-path`).

Screen capture was deliberately abandoned for this milestone. The player window is
borderless, transparent and always-on-top; a screen grab of it captures whatever
sits behind it, which is both unreliable evidence and a privacy risk on a real
desktop. The viewport read-back can only ever contain KoalaPet's own rendered
frame. This also explains why earlier prompts saw blank `PrintWindow` results.

The set covers 30 scenarios. `screenshots/index.json` lists every scenario with its launch mode, setup actions,
pixel size and SHA-256. Each image has a sibling `.json` with the full runtime
diagnostics captured at the same moment.

## Screenshot set

| Image | Shows |
| --- | --- |
| `01-starter-selection` | Egg choice |
| `02-egg-waiting` | Egg screen with a disabled hatch action |
| `03-small-care-default` | Redesigned Small, care page |
| `04-small-care-english` | Same layout in English |
| `05-small-urgent-hunger` | Satiety 14% in alert colour, urgent header chip, call bubble |
| `06-small-sick` | Sickness chip, Medicine replacing Clean, Train disabled |
| `07-small-sleeping` | Sleep chip, pet at the den, Wake replacing Sleep |
| `08-small-more-page` | Treat, Sleep, Inventory, Codex |
| `09-small-adventure-page` | Battle present, Dungeon still gated |
| `10-small-minimum-size` | `600×380` logical: narrow meters, everything reachable |
| `11-small-large-size` | Enlarged Small, habitat takes the extra space |
| `12/13/14-small-ui-100/150/200` | UI scale grows the window, not the crowding |
| `15-small-text-150` | 150% text scale |
| `16-expanded-overview` | Three-column Expanded |
| `17-expanded-english` | Expanded in English |
| `18-expanded-battle` | Battle tab with a contextual right column |
| `19-expanded-dungeon` | Dungeon tab after the gate opens |
| `20-expanded-inventory` / `21-expanded-evolution` | Remaining tabs |
| `22-expanded-large-size` | Expanded enlarged, no empty bands |
| `23-settings` | Settings sheet |
| `24-blocked-action` | Safe localized message for a blocked action |
| `25-small-injured` | Injury chip, bandaged pet, Treatment replacing Clean, Train disabled |
| `26-expanded-codex` | Codex entries with the portrait each discovery earned |
| `27-small-first-care-hint` | The one-time hint a brand new companion gets |
| `28-small-text-175` | 175% text: nothing clipped, every window control reachable |
| `29-small-high-contrast` | High-contrast borders |
| `30-small-compact-density` | Compact layout density |

## Interactive action matrix

`action-matrix.json` records real Win32 input against the running client. Each step
resolves the target control from the application's own live diagnostics, sends a
real mouse click or key press, and reads the refreshed authoritative state back.
Recorded per step: control name, resolved accessible label, disabled state, number
of `pressed` connections, resulting mode/page/tab, domain `state_revision` delta,
the localized feedback key and severity, the suppressed-duplicate counter, the
native window size, and whether the process survived.

Confirmed by that harness:

- Feed, Clean, Train, Treat, Sleep, Wake, Medicine each produce exactly one domain
  revision, the correct localized feedback and the correct habitat animation.
- Every control carries exactly one `pressed` connection.
- A 10 ms double click on Feed produces one command and one counted suppression.
- A 10-click burst inside 94 ms produces exactly one command.
- Sick: Train is disabled and its accessible label is the reason.
- Sleeping: Clean is disabled with "Dein Gefährte schläft gerade."
- Expanded tabs, contextual right-column actions, keyboard mode switching
  (`tabto:HeaderModeSwitch`, `F1`/`F2`/`F3`) and the settings sheet all respond.
- No step terminated the process; no engine error was logged.

### Keyboard verification of the full care loop

Because the mouse path is unreliable on this host (see below), the complete care
loop was also driven coordinate-free: Tab to the control the application reports
as focused, then Enter. All eight steps passed —

| Step | Control | Revision delta | Feedback | Habitat |
| --- | --- | --- | --- | --- |
| 1 | Füttern | +1 | `feedback.feed.ok` | `turn_left` |
| 2 | Reinigen | +1 | `feedback.clean.ok` | `turn_left` |
| 3 | Trainieren | +1 | `feedback.train.ok` | `walk` |
| 4 | Mehr | 0 | — | page → more |
| 5 | Leckerli | +1 | `feedback.feed.overfed` | `walk` |
| 6 | Schlafen | +1 | `feedback.sleep.ok` | `turn_left` |
| 7 | Pflege | 0 | — | `sleep_loop` |
| 8 | Aufwecken | +1 | `feedback.wake.ok` | `wake` |

Each control was reached in 5–10 Tab presses, every action produced exactly one
domain revision and one localized message, and Wake correctly replaced Sleep.

### Harness limitation, not a product defect

On this mixed-DPI multi-monitor host, Win32 window metrics queried from a
DPI-virtualised process disagree with the pointer coordinate space when the window
sits on a monitor whose scaling differs from the system scaling. Some mouse steps
therefore landed on the neighbouring control and are recorded as no-ops.

The affected controls were re-verified coordinate-free through keyboard focus and
Enter activation, which is authoritative because it does not involve screen
coordinates at all: `tabto:HeaderModeSwitch` switched Small → Expanded → Small, and
`F1`/`F2` reached Minimal and back. Rows whose `note` contains `no_refresh` together
with an unchanged `mode_requests` counter are harness misses of this kind, not
unresponsive controls.

## Animation audit

`animation-quality.json` measures every one of the 290 referenced animations:
declared frames, fps, resulting cycle length, real per-frame pixel change as a
share of the drawn area, the quietest and loudest transition, and every repeated
frame classified as deliberate structure or waste.

`tools/art_pipeline/audit_animation_quality.py --check` currently reports **0
issues** and is a foundation-check gate.

The audit found one genuine defect. The three starter eggs shipped as two-frame
sheets, with `world` and `hatch` at 10 fps: the first animation any new player
watches was a 0.2 second flicker, and hatching was over before it read as an
event. `tools/art_pipeline/generate_egg_animations.py` re-poses the accepted egg
art into a 6-frame rocking idle (1.0 s), a livelier 6-frame Minimal cycle (1.2 s)
and an 8-frame hatch (1.0 s) that escalates from nervous jolts through the crack
to the burst. The pristine two-pose input lives in
`art_source/sources/egg-poses/`, so the generator can never consume its own
output.

Everything else the blunt first pass flagged turned out to be craft rather than
defect: a one-shot returning to its rest pose, a ping-pong sharing its mirrored
midpoint, and a breathing loop visiting rest twice per cycle. The audit now
classifies those instead of reporting them, so the remaining signal is real.

## Runtime performance

`performance.json` plus the per-scenario `*-diagnostics.json` files: eight
isolated four-second native samples.

| Measure | Result |
| --- | --- |
| Frame rate | 60 FPS in every scenario |
| CPU | at most 1.938% of 16-thread total capacity (Expanded idle) |
| Peak working set | 203.12 MiB |
| Texture memory | 1.82 MiB Minimal, 38.2 MiB Small habitat, 39.3 MiB during a battle |

The Prompt 4.7 baseline was 59-60 FPS, at most 1.843% CPU and 203.44 MiB peak
working set, so the rebuilt interface costs nothing measurable. Texture memory is
not comparable to the 4.7 figure: it tracks which animation sheets happen to be
resident at the sample moment, and these scenarios drive more of them.

## Stability soak

`stability-soak.json`: one client run driven by 307 scripted player intents —
100 care actions, 103 mode switches and 100 Expanded tab switches.

- process survived, no engine error
- animation queue fully drained (`habitat_pending_events` 0)
- no control accumulated a second `pressed` handler across 100+ full rebuilds
- no leaked full-screen background node after repeated mode transitions
- peak working set 210.6 MiB, still 60 FPS at the end

## Icon set

`contact-sheets/ui-icon-set.png` shows the complete runtime icon set at 2×.
`tools/art_pipeline/generate_ui_symbol_icons.py --check` verifies that the nine
procedurally generated symbols and every 2× twin still match their generator.

## Limits of this evidence

- No video was recorded for this milestone. The click-level record in
  `action-matrix.json` plus the per-scenario viewport captures replace it; a
  recording of the physical screen would again risk capturing unrelated desktop
  content behind the transparent window.
- Display scaling above the values the host actually offers, tray lifecycle,
  Show Desktop and controlled cross-monitor movement remain unavailable.
- No screen-reader acceptance is claimed; Godot 4.7 controls still expose no usable
  Windows accessibility child tree.
