# Animation Coverage

## Playable contract

Every current hatchling and Juvenile profile exposes the same 29 data-defined animation IDs. All sheets use `128×128` cells, explicit pivot/ground/visual geometry, interaction/effect bounds, mirroring policy, markers, provenance and review status. Current sequences contain `4–8` chronological frames.

| Family | Form | Coverage | Frames |
|---|---|---:|---:|
| Moss | `moss` | 29/29 | 4–8 |
| Moss | `moss_bloom` | 29/29 | 4–8 |
| Moss | `moss_bracken` | 29/29 | 4–8 |
| Ember | `ember` | 29/29 | 4–8 |
| Ember | `ember_dawn` | 29/29 | 4–8 |
| Ember | `ember_cinder` | 29/29 | 4–8 |
| Tide | `tide` | 29/29 | 4–8 |
| Tide | `tide_glass` | 29/29 | 4–8 |
| Tide | `tide_reed` | 29/29 | 4–8 |

Required IDs:

- Idle/movement: `idle`, `idle_look`, `idle_playful`, `idle_rest`, `walk`, `turn_left`, `turn_right`, `playful_hop`, `playful_pounce`.
- Care/attention: `eat`, `treat`, `clean`, `training`, `medicine`, `treatment`, `attention`, `happy`, `call`.
- Condition/sleep: `sick`, `injured`, `sleep_enter`, `sleep`, `sleep_loop`, `wake`.
- Battle: `attack`, `hit`, `dodge`, `victory`, `defeat`.

Egg profiles remain intentionally limited to `idle`, `hatch` and `world` at two frames each.

## Enemy contract

`creekling`, `thornlet`, `cinder_moth` and `canopy_guardian` each expose `idle`, `attack`, `hit`, `dodge` and `defeat`, with `4–8` frames per sequence.

## Playback and event contract

- Priority is deterministic: evolution `800`, battle `700`, care `600`, condition `500`, sleep `400`, locomotion `300`, attention `200`, ambient `100`.
- One-shots use stable IDs, deduplicate replays, cap pending events at `32`, cap recent IDs at `64` and return to an authoritative loop.
- Attack, hit, dodge, sleep, wake and care actions expose frame markers. Gameplay results remain authoritative; marker callbacks trigger only presentation effects.
- Family VFX are separate data-defined Moss/Ember/Tide layers. Effect intensity is `off`, `reduced` or `normal`; hit shake and damage flash are independent preferences.
- Reduced Motion advances every chronological frame at a faster cadence, disables ambient roaming/playful travel and reduces effects. It never skips marker frames or changes gameplay timing.
- Hidden presentation nodes suspend playback and ambient processing.

## Evidence and limits

Contact sheets, reels, native Godot movies, extracted frames and performance results are indexed in [`evidence/living-animation/README.md`](evidence/living-animation/README.md). Current generated art is `PROVISIONAL_PRODUCT_REVIEW` with `license_status=UNDECIDED`; final production-art and accessibility acceptance remain separate gates.
