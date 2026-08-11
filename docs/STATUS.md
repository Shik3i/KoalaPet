# Project Status

**Phase:** Prompt 0 — pre-production foundation

## Repository state

- Repository was confirmed empty with no commits on `main` before bootstrap.
- Canonical documentation, accepted ADRs, draft schemas, a neutral example pack, validation tooling, repository hygiene, and a minimal Godot shell are established by this milestone.
- KoalaPet remains a replaceable codename.

## Implemented

- Repository structure and contributor/agent guidance
- Draft content API `0.1` schemas and neutral architecture fixtures
- Python JSON Schema and cross-reference validator
- Minimal Godot project metadata and blank bootstrap scene

## Documented only

All pet simulation, care, time/offline progression, persistence, presentation modes, Windows overlay integration, evolution, battle, dungeon, habitat, farm, Trading Post, and production art behavior. No gameplay or platform behavior is implemented.

## Latest quality checks

- Content validation passed for 2 packs and 17 content documents.
- Godot `4.7.1.stable.official.a13da4feb` completed a headless editor import of `game/`.
- Repository-relative Markdown link validation passed for 41 local targets.

## Known blockers

- The three UI-mode concept images were not available during bootstrap; the expected paths are indexed as missing.
- Licensing and several product/Windows interaction decisions remain open.

## Next recommended milestone

Prompt 1: a Windows desktop-overlay technical spike validating transparent windows, click-through/mouse passthrough, always-on-top, dragging, DPI, taskbars, multiple monitors, minimize/restore, persistence, and mode transitions. Do not begin gameplay during that spike.
