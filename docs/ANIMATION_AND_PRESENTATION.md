# Animation and Presentation

## Runtime contracts

- Animation descriptors are data-driven. Bundled profiles include frame count/fps/loop, `frame_size`, `pivot`, `ground_anchor`, `visual_center`, interaction/effect bounds, mirroring policy, event markers, provenance and review status.
- All nine playable walk sheets contain eight `128×128` chronological frames at 10 fps. World movement is delta-time translation by the presentation controller; the sheet stays in place.
- Priority: sleep, sickness, injury, battle, movement, call, idle. One-shots use stable IDs, are consumed once and return to an authoritative loop.
- Reduced Motion disables continuous roaming, turn/bob motion and ambient dust. Care commands still route instantly to the correct anchor, show a held action pose and complete their timers.

## Habitat anchors

`idle_center`, `feeding_bowl`, `treat_position`, `bath`, `training`, `bed`, `medicine`, `departure`, `trophy`, `roam_left`, and `roam_right` share the ground line. Feed, clean, train, medicine, sleep/wake, battle and dungeon entry use these anchors without changing domain timing.

## UI scaling

- 100% logical sizes: Minimal `240×160`, Small `640×360`, Expanded `1120×720`.
- UI scale changes native/rendered bounds from 100–200%. Text scale separately reflows at 100–175%. Pet scale separately changes standard and Minimal sprite size from 75–200%.
- Player text begins at 16 px; titles begin at 18 px; comfortable controls use at least 48×44 px. German and English use the same flexible containers.
- Settings live in versioned `user://preferences.json`, not in simulation saves. Missing/malformed/future-version values recover to sanitized defaults; writes rotate a backup and atomically replace the file.

## Evidence boundaries

Automated tests prove data contracts, layout intent and persistence. Native debug captures prove the recorded Windows host only. They do not establish screen-reader behavior, complete contrast acceptance, every mixed-DPI transition, Windows 10 parity, release export behavior, taskbar/Alt+Tab policy, art rights or ADR 0010 acceptance.
