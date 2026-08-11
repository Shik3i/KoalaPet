# Project Canon

This file is the highest-authority concise source for durable product decisions. Accepted ADRs and detailed documents may expand but not contradict it.

## Accepted

- **Identity:** KoalaPet is a replaceable codename for a Windows-first, local-first desktop virtual-pet game. Branding and application identity must be centralized and replaceable without renaming domain concepts.
- **Experience:** the player begins with a data-defined choice of starter eggs, one active companion, and a complete classic V-pet care loop. Collection, dungeon, customization, farm, and idle progression grow around pets the player personally raised.
- **Presentation:** Minimal, Small, and Expanded are presentations of one authoritative simulation. Minimal is pet-only and transparent; Small is the compact everyday default; Expanded is optional management, not a permanent full-screen takeover.
- **Progression:** startup does not expose a dashboard of unavailable systems. Farm/sanctuary appears only when it has purpose; before then it is absent from normal UI.
- **Care:** baseline food, cleaning, sleep, and basic treatment cannot be blocked by currency. Care includes hunger/fullness, overfeeding, weight, mood, energy, strength/effort, discipline, hygiene/waste, sleep/light, attention calls, care mistakes, health, sickness, injuries, medicine, age, training, and lifecycle stages.
- **Evolution:** branching evolution is declarative and may consider care, training, physiology, history, battles, dungeons, items, traits, achievements, habitat, and lineage. Poor-care forms remain interesting and viable.
- **Adventure:** normal battles are short repeatable encounters. Dungeons are longer encounter/event sequences with bosses and cross-system rewards. The exact combat interaction remains open.
- **Residents:** one pet is active. Eligible mature pets may settle safely as persistent, recallable farm residents. They retain identity and do not require active care micromanagement or die from offline neglect.
- **Economy:** a Trading Post/order loop is planned. A full restaurant simulation is not required for the first product MVP.
- **Customization:** layered habitat backgrounds, ground, structures, furniture, props, stations, effects, and lighting are a major pillar. A traditional generic RPG tileset is not required.
- **Modding:** external JSON is canonical authoring. Official content is itself a versioned pack. Initial mods are data and safe media only; no scripts, DLLs, native code, or executable payloads.
- **Content and saves:** stable namespaced IDs, localization keys, versioned content APIs, deterministic overrides, save envelopes, migrations, backups, atomic writes, and missing-content quarantine are foundational.
- **Architecture:** pure domain simulation is separated from content, application coordination, persistence, time/offline progress, progression, presentation, and platform adapters. Balance is independent of frame rate and tested through an injectable clock.
- **Production:** Godot 4.x and GDScript are the engine direction; Python supports deterministic validation/asset tools. The standard art workflow is AI-first and does not require manual art-editor work by the product owner.
- **Privacy and IP:** no account, telemetry, tracking, ads, server, cloud dependency, or unauthorized third-party franchise content belongs in the current core plan.
- **Governance:** the product owner makes final product decisions. Agents challenge assumptions and document alternatives but never silently replace accepted scope.

## Provisional and tunable

- Three starter eggs are intended in the bundled pack, but count is data-defined.
- Farm reveal is provisionally after a mature pet, a meaningful achievement, and a second-egg unlock.
- Combat is likely automatic or semi-automatic with small timing, preparation, or tactical input.
- Offline production uses capped elapsed time and deterministic modifiers; caps and rates are tuning data.
- Expanded presentation may use one resizable window or multiple compact panels after technical prototyping.

## Open

Final name/branding, care profile, lifecycle endpoint, evolution cadence, combat input, evolution-condition disclosure, habitat placement model, MVP content counts, Windows tray/multi-monitor/taskbar behavior, later platforms, and licensing. See `OPEN_QUESTIONS.md`.

## Out of scope for the first product MVP

- Full restaurant/café and customer simulation
- Executable-code mods
- Steam integration, accounts, cloud saves, telemetry, analytics, ads, or networking
- Linux/macOS release commitment before Windows validation
- A generic traditional tileset pipeline

These exclusions do not silently remove accepted later possibilities.
