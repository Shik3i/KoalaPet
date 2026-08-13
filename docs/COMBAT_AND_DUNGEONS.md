# Combat and Dungeons

## Normal battles

Short repeatable encounters. They can contribute experience/level, battle count, win ratio, drops, injuries, evolution flags, and opponent history. Basic combat state belongs to the domain and cannot depend on a presentation mode.

Milestone 4 implements a bounded semi-automatic prototype. The player selects Aggressive, Balanced, Defensive, or Auto; content-defined moves, hit checks, damage, effects, and enemy selection advance through a persisted deterministic session state. Sessions contain an instance ID, encounter, seed/random state, round, stance, transient HP, effects, event log, result, and reward state. Six rounds are the current cap. Save/reload resumes the same session without rerolling. Experience and a content-defined level curve are persisted, with a level cap of five.

The bundled roster has three normal encounters and one boss encounter. Drops are stackable and data-defined. Defeats or very low battle HP create the explicit `canopy_sprain` injury; `restorative_wrap` always provides baseline treatment, while sleep provides configured natural recovery. Injury blocks further battle/dungeon entry until recovered. This interaction model is a tested Milestone 4 prototype, not the final combat decision.

## Dungeons

Longer deterministic or seed-recorded sequences of encounters and events ending in a boss. A dungeon may unlock its background/theme, ground and props, blueprints, recipes, materials, enemies/codex entries, trophies, egg or fragment conditions, evolution flags, and Trading Post requests.

Content defines encounter pools, structure, boss, rewards, theme, prerequisites, and unlock flags. Milestone 4 implements one reusable five-node `quiet_canopy` run: normal encounter, choice event, normal encounter, rest, and boss. The run persists its seed, current/completed nodes, choices, transient HP, encountered enemies, rewards, and result. A failed run returns safely and does not grant first-clear rewards. The first clear stores the dungeon flag, boss flag, codex records, experience, `canopy_theme`, `canopy_trophy`, and a special item; repeat clears use repeat rewards. The habitat editor is not implemented yet.

## Open interaction model

Current direction: automatic or semi-automatic combat with a small preparation or stance choice. Fully controlled action-RPG combat is not accepted. Prompt 4 validates the stance prototype for determinism, save/reload, accessibility without timing input, and desktop-sized sessions; product feel, pacing, and final interaction remain open.

Injuries are explicit outcomes with treatment and recovery paths. Closing the game cannot create unbounded combat risk.
