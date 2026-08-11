# Farm and Idle Progression

The farm/sanctuary is absent from normal startup UI. It appears provisionally after a mature pet, meaningful progression, and a second-egg unlock. Exact gates remain data-driven.

There is one active partner. A sufficiently mature, settled-ready pet may become a resident and can be recalled at any time. Residents retain stable instance ID, custom name, form, stats, traits, bond, history, and evolution record. They are not generic worker tokens and cannot die from the game being closed or from missing repetitive active-care tasks.

Initial jobs: gathering/foraging, workshop/crafting, research/analysis, patrol/training support, and Trading Post fulfillment. Stats, form, traits, affinities, furniture, and station upgrades may modify performance.

Offline output is calculated from elapsed timestamps, a declared cap, job rate, station modifiers, and deterministic rounding. Never simulate every resident every frame. Calculations record inputs and outcomes for reproducibility. Clock rollback, extreme elapsed time, removed content, and version changes require explicit safe policies.

Settled-ready eligibility prevents freezing eggs/newborns to bypass care. Switching active/resident status must be atomic and save-safe.
