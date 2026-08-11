# Modding

Initial mods are versioned JSON plus safe PNG, WebP, OGG, and WAV assets. They can localize or replace display content; add/replace eggs, pets, forms, animations, evolution, moves, items, enemies, dungeons, jobs, themes, furniture, sounds, and starter pools; provide skin-only replacements; or disable the base roster as a total conversion.

No GDScript, DLL, shared library, native binary, executable archive, macro, or arbitrary code payload is loaded. Mods do not require the Godot editor.

Packs declare dependencies, conflicts, type, license/source metadata, entry points, asset roots, priority, and explicit overrides. Deterministic resolution follows `CONTENT_MODEL.md`. Errors identify the file and JSON path. Removing a pack quarantines affected pet/save records without deleting raw data.

Runtime discovery uses injected roots: bundled `res://content_packs/`, external `user://mods/`, and test/development roots. Immediate child directories with `manifest.json` are candidates. Official and external packs follow the same validation and resolution functions.

Replacement policy is explicit: content packs list every replaced ID, skins can replace presentation definitions only, and total conversions alone may disable the base pack. Duplicate or unauthorized definitions never win by filesystem order.

`mods/examples/example.neutral/` is a fictitious architecture fixture, not official product content or balance. The bundled `koalapet.base` pack uses the same manifest/registry rules.
