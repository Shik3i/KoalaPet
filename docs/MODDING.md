# Modding

Initial mods are versioned JSON plus safe PNG, WebP, OGG, and WAV assets. They can localize or replace display content; add/replace eggs, pets, forms, animations, evolution, moves, items, enemies, dungeons, jobs, themes, furniture, sounds, and starter pools; provide skin-only replacements; or disable the base roster as a total conversion.

No GDScript, DLL, shared library, native binary, executable archive, macro, or arbitrary code payload is loaded. Mods do not require the Godot editor.

Packs declare dependencies, conflicts, type, license/source metadata, entry points, asset roots, priority, and explicit overrides. Deterministic resolution follows `CONTENT_MODEL.md`. Errors identify the file and JSON path. Removing a pack quarantines affected pet/save records without deleting raw data.

`mods/examples/example.neutral/` is a fictitious architecture fixture, not official product content or balance. The bundled `koalapet.base` pack uses the same manifest/registry rules.
