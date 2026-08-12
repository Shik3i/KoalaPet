# Content Model

External JSON is canonical authoring; Godot Resources may later be generated caches, never a mod-author requirement. Content API `0.1` is implemented but explicitly experimental, not a long-term compatibility promise.

## Identity and localization

Every content object has a stable `namespace:name` ID such as `koalapet.base:forest_egg` or `example.author:custom_form`. Names and descriptions are localization keys. Renaming visible text cannot change identity.

## Pack manifest

A manifest declares pack ID, display-name key, semantic version, content API version, `skin`/`content`/`total_conversion` type, authors, license metadata, dependencies, optional dependencies, incompatibilities, deterministic load priority, base-pack policy, entry files, asset roots, and explicit overrides.

Resolution order uses one-at-a-time stable topological selection: required and present optional dependencies first, then numeric priority, then pack ID lexical order. Lower priority loads earlier. Missing required dependencies, cycles, active conflicts, duplicate pack IDs, and incompatible API versions reject the affected pack. Missing optional dependencies do not.

Same-ID collisions are errors unless the later pack lists the exact ID in `overrides`. A normal `content` pack is a replacement pack only for those IDs. `skin` packs may override animation, habitat-theme, and furniture presentation definitions, not mechanics. A `total_conversion` may set `base_pack_enabled: false`; other pack types cannot disable `koalapet.base`. `enabled` defaults to true and permits deterministic local disabling.

## Draft definitions

Schemas cover manifest, localization, starter pools, eggs, species/families, forms, animations, evolution graphs, moves, items, enemies/encounters, dungeons, habitat themes, furniture/props, farm jobs/stations, and feature gates. Prompt 0 fields are deliberately small `0.x` contracts, not final balance.

All references and required local display-name keys resolve through the registry before a pack is applied. Runtime schema checks mirror the authoring contracts, including required fields and additional-property rejection. Asset paths are relative to declared pack roots after normalization. The official base pack remains intentionally content-empty until original designs are accepted.

Runtime queries list resolved packs/documents, resolve IDs and owners, explain missing or wrong-kind references, inspect applied overrides, retrieve localization values with deterministic locale fallback, and list rejected packs/diagnostics. Diagnostics contain a logical source label and JSON path.

## Content snapshot

Each resolved pack contributes pack ID, semantic version, content API version, order, and SHA-256 fingerprint over its pack JSON and safe-media files. The snapshot also records sorted resolved content IDs and an aggregate fingerprint. Saves persist this reproducibility record.

## Content API 0.1 changes in Milestone 2

- Manifest: optional boolean `enabled`; dependency version requirements are exact, `*`, `>=x.y.z`, or `^x.y.z`.
- Feature gates: stable namespaced `feature` and `reward_ids`; recursive `condition` supporting leaf comparisons plus `all`, `any`, and `not`.

No executable payload field or runtime code hook was added.
