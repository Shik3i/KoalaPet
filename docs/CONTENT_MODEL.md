# Content Model

External JSON is canonical authoring; Godot Resources may later be generated caches, never a mod-author requirement. The draft content API is `0.1`.

## Identity and localization

Every content object has a stable `namespace:name` ID such as `koalapet.base:forest_egg` or `example.author:custom_form`. Names and descriptions are localization keys. Renaming visible text cannot change identity.

## Pack manifest

A manifest declares pack ID, display-name key, semantic version, content API version, `skin`/`content`/`total_conversion` type, authors, license metadata, dependencies, optional dependencies, incompatibilities, deterministic load priority, base-pack policy, entry files, asset roots, and explicit overrides.

Resolution order is dependency topology, numeric priority, then pack ID lexical order. Same-ID collisions are errors unless the later pack declares an explicit override and compatibility permits it. Skin packs may replace presentation references but not mechanics. Total conversions may disable the bundled base pack.

## Draft definitions

Schemas cover manifest, localization, starter pools, eggs, species/families, forms, animations, evolution graphs, moves, items, enemies/encounters, dungeons, habitat themes, furniture/props, farm jobs/stations, and feature gates. Prompt 0 fields are deliberately small `0.x` contracts, not final balance.

All references resolve through the registry. Asset paths are relative to declared pack roots after normalization. The official base pack remains intentionally content-empty until original designs are accepted.
