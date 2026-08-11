# Game Agent Rules

Obey root `AGENTS.md` first. Keep domain simulation independent from Godot scenes, UI modes, wall clock, and Windows APIs. Access time, saves, content, and platform behavior through explicit boundaries. All concrete gameplay content and balance belong to validated packs. Minimal, Small, and Expanded consume one application state. Do not add speculative gameplay or platform hacks without the relevant milestone and documentation.

Keep reference/source art outside `game/`. Only approved game-ready assets enter `assets_generated/`. Run headless import and relevant tests for every game change.
