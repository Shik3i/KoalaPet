# Source Boundaries

- `domain/`: pure simulation and rules
- `content/`: runtime pack discovery, trust-boundary validation, resolution, and snapshots
- `app/`: use-case coordination
- `infrastructure/`: persistence/content adapters
- `time/`: injected wall/monotonic clocks and offline elapsed policy
- `progression/`: read-only facts, declarative gates, and unlock ledger
- `platform/`: operating-system integration, with Windows isolated below it
- `presentation/`: three mode views/controllers
- `shared/`: narrowly shared primitives

Milestone 2 implements only current foundation behavior; pet gameplay remains absent.
