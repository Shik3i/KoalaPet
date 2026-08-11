# Game Tests

Prompt 1 adds deterministic platform-neutral placement, recovery, persistence-envelope, hit-region, and presentation-transition tests. They validate pure logic only—not Windows compositor or shell behavior.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/platform/run_all.gd
```

Future domain, content-registry, save/migration, offline-time, scene, and production presentation tests arrive with their implementations.
