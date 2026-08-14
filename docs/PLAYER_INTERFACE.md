# Player Interface

Authoritative UI/UX rules for the normal player path. Minimal, Small and Expanded
remain three presentations of one simulation; this document governs what each one
shows, how it is composed and what it must never do.

## Information architecture

### Small — the everyday interface

Small is the default. It must stay calm enough to leave open during other work and
understandable without a manual. Top to bottom:

| Region | Contains | Rule |
| --- | --- | --- |
| Header | Portrait, name, `stage · level`, one urgent chip, Settings, Expand, Minimal, Minimize, Close | Identity and window control only. No care, adventure or navigation icons. |
| Primary status | Satiety, Mood, Energy, Hygiene | Exactly four meters, each with icon, localized name, percentage and bar. |
| Contextual alerts | Injury, sickness, low health, sleeping, attention calls, running battle/dungeon, pending evolution | Present only while true. The first alert is promoted into the header. |
| Habitat | Pet, stations, trophies | The visual focus. Takes all remaining vertical space. |
| Primary actions | Three or four actions for the current page | Icon **and** localized text. |
| Footer navigation | Care, Adventure, More | Icon and text. Adventure is absent until a gate opens. |

Health, discipline, weight, experience, waste and care mistakes belong to Expanded,
not to the Small status row.

### Contextual action replacement

A contextual action replaces the action it supersedes; it is never appended as an
extra permanent button.

| Condition | Care page shows |
| --- | --- |
| Default | Feed · Clean · Train |
| Sick | Feed · **Medicine** · Train |
| Injured | Feed · **Treatment** · Train |
| Sleeping | Feed · Clean/Medicine/Treatment · **Wake** |

Treat, Sleep, Inventory and Codex live on the More page. Battle and Dungeon live on
the Adventure page and only exist once their data-driven gate opens.

### Expanded — optional management

Three columns inside one resizable window:

- **Left** — identity, six care meters, experience, weight, waste, care mistakes and every active alert.
- **Centre** — habitat at its natural aspect ratio, the tab row, then the tab body.
- **Right** — actions and detail *for the selected tab only*, plus the current objective or the recent-event list.

The right column never shows every panel at once. Only intentionally scrollable
content scrolls (event history, codex, inventory); the interface itself does not.

## Composition rules

- Spacing, type sizes, control heights and icon sizes come from `UiMetrics`. No new
  hardcoded pixel constants in layout code.
- Base grid: `4 / 8 / 12 / 16 / 24`. Body text 16, action text 17, panel titles 20,
  screen titles 22, captions 14 — all before text scale.
- Icons are drawn at integer multiples of the 24 px source (24 for status and
  window controls, 48 for primary actions), so pixel art is never resampled.
- Layout uses Godot containers. Absolute coordinates are allowed only inside the
  habitat, which owns its own coordinate space and is wrapped by `HabitatFrame`.

## Feedback rules

1. Every action reports input acceptance (button state), progress (the pet walks to
   the station and plays the one-shot) and a result (status meter change plus one
   short localized sentence).
2. Failures never surface an `error_code` or an internal `reason`. `ActionFeedback`
   maps every outcome to a localization key with a severity, and unknown codes fall
   back to one safe generic sentence.
3. Severity drives colour *and* icon. No state is communicated by colour alone.
4. An action that cannot run right now is disabled and carries the reason as its
   tooltip and accessible label, rather than failing after the click.

## Input safety

- One authoritative command may be in flight at a time.
- Repeating the *same* command within 450 ms is treated as one intent. A different
  action is never delayed. Suppressed repeats are counted, not silently dropped.
- The player interface is rebuilt from the authoritative view model; a rebuild can
  never re-enter itself, and a resize reflows without rebuilding.
- Transient status toasts are click-through and sit over the habitat, so they can
  never swallow the next action.

## Window chrome

Every screen, including the starter choice, carries the same header: identity
plus Settings, Expand/Collapse, Minimal, Minimize and Close. Minimal is hidden
until a pet exists, because it is a pet-only presentation and would otherwise
drop the starter choice into a 240x160 window.

## Accessibility

- Every control is keyboard focusable, appears in the focus order and activates
  with Enter or Space.
- Every icon-only control has a localized tooltip and an accessible label.
- Every status carries a text alternative: name, percentage and a state word
  (`Dringend` / `Niedrig` / `In Ordnung` / `Voll`).
- Below roughly 168 logical pixels per meter the status row drops the names and
  keeps icon plus percentage; the full name stays in the tooltip.

Known engine limitation: Godot 4.7 controls still expose no usable Windows
accessibility child tree, so screen-reader acceptance remains unproven. See
[`ACCESSIBILITY_DPI_FINDINGS.md`](ACCESSIBILITY_DPI_FINDINGS.md).

## Onboarding

Contextual, never a tutorial modal sequence. Expanded's Overview shows one hint
that follows the pet's current need; the Small header promotes the most urgent
state; locked features are absent rather than shown disabled.
