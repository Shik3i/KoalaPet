# Animation and Presentation

## Runtime contracts

- Animation descriptors are data-driven. Bundled profiles include frame count/fps/loop, `frame_size`, `pivot`, `ground_anchor`, `visual_center`, interaction/effect bounds, mirroring policy, event markers, provenance and review status.
- All nine playable profiles expose the 29-state contract in [`ANIMATION_COVERAGE.md`](ANIMATION_COVERAGE.md), using `4–8` chronological `128×128` frames. Current enemies expose five `4–8`-frame battle/reaction states. World movement is delta-time translation by the presentation controller; sheets stay in place.
- Priority is evolution `800`, battle `700`, care `600`, condition `500`, sleep `400`, locomotion `300`, attention `200`, ambient `100`. One-shots use stable IDs, are consumed once, cap pending events at `32`, retain `64` recent IDs and return to an authoritative loop.
- Attack, hit, dodge, sleep, wake and care markers drive only visual effects. Gameplay outcomes and command completion remain domain-authoritative.
- Reduced Motion disables continuous roaming/playful travel and uses reduced feedback while still advancing every chronological frame. Marker frames cannot be skipped. Care commands route instantly to the correct anchor and complete their presentation timers.
- Player controls dispatch state-changing callbacks deferred from their Godot signal emission. Presentation refresh removes the old tree immediately but releases it with `queue_free()`, so a button, selector or toggle is never destroyed while emitting its own signal.

## Habitat anchors

`idle_center`, `feeding_bowl`, `treat_position`, `bath`, `training`, `bed`, `medicine`, `departure`, `trophy`, `roam_left`, and `roam_right` share the ground line. Feed, clean, train, medicine, sleep/wake, battle and dungeon entry use these anchors without changing domain timing. Data-defined prop interactions may temporarily route to a compatible anchor, then return to the authoritative loop.

## UI scaling

- 100% logical sizes: Minimal `240×160`, Small `640×360`, Expanded `1120×720`.
- UI scale changes native/rendered bounds from 100–200%. Text scale separately reflows at 100–175%. Pet scale separately changes standard and Minimal sprite size from 75–200%.
- Player text begins at 16 px; titles begin at 18 px; comfortable controls use at least 48×44 px. German and English use the same flexible containers.
- Settings live in versioned `user://preferences.json`, not in simulation saves. Missing/malformed/future-version values recover to sanitized defaults; writes rotate a backup and atomically replace the file.

## Evidence boundaries

Automated tests prove data contracts, layout intent and persistence. Native debug captures prove the recorded Windows host only. They do not establish screen-reader behavior, complete contrast acceptance, every mixed-DPI transition, Windows 10 parity, release export behavior, taskbar/Alt+Tab policy, art rights or ADR 0010 acceptance.
