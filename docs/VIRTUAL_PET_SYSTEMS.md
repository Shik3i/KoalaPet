# Virtual-Pet Systems

Prompt 0 defines boundaries, not final numbers.

| System | Intent | Important records |
|---|---|---|
| Hunger/fullness | Feeding cadence, food quality, overfeeding tradeoffs | meals, fullness curve, overfeeding events |
| Weight | Consequence and build input, not cosmetic shame | time-series summary, healthy band by form |
| Mood/happiness | Response to care, play, rest, environment | trend and notable events |
| Energy | Gates exertion and supports sleep rhythm | current/average, exhaustion events |
| Strength/effort | Training progression by category | totals, recent effort, equipment modifiers |
| Discipline | Behavioral teaching and attention response | calls, correct responses, training history |
| Hygiene/waste | Recurring readable care task | waste created/cleaned, dirty duration |
| Sleep/light | Daily rhythm and bedtime interaction | disturbances, sleep quality, schedule profile |
| Health | Illness, battle injury, recovery | ailments, treatments, untreated duration |
| Age/stage | Lifecycle clock independent of frame rate | born time, active/offline stage time |
| Attention/care mistakes | Fair consequence for ignored important calls | reason, call window, resolution |

Services consume a clock abstraction and explicit commands. Presentation subscribes to state/results but does not own simulation. Values, thresholds, decay, call windows, offline caps, and profile differences belong to validated data or versioned balance configuration.

The current vertical slice realizes the baseline records through `care-profile`, `ailment`, `training-activity`, and `item.use` data. `PetSimulation` keeps current care values, bounded event history, and aggregate counters in the pet record; it does not own presentation or platform state. Milestone 4 adds `EvolutionResolver`, `BattleService`, and `DungeonService` as domain services over the same authoritative state. Battle injuries are distinct from ordinary sickness, carry cause/treatment/recovery state, block unsafe adventure entry, and never delete the pet. Care history remains an evolution input rather than a disconnected minigame score.

Essential actions must have free baseline variants. Sickness and injuries require readable diagnosis/treatment and cannot be disguised random punishment. Minigames should be short, repeatable, accessible, and swappable without changing core state contracts.
