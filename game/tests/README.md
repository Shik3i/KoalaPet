# Game Tests

Prompt 1 adds deterministic platform-neutral placement, recovery, persistence-envelope, hit-region, and presentation-transition tests. They validate pure logic only—not Windows compositor or shell behavior.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/platform/run_all.gd
```

Milestone 2 foundation gate:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/foundation/run_all.gd
```

It covers content resolution/security/snapshots, clocks/offline policy, save replacement/recovery/migration/quarantine, feature gates, and bootstrap. It does not validate native windows or pet gameplay.
