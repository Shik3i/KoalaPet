# Milestone 4 gameplay evidence

Captured 2026-08-13 on Windows with Godot `4.7.1.stable.official.a13da4feb`. Each image is a privacy-safe native-window crop made with `tools/windows_overlay_spike/capture_interactive.ps1 -PrintWindow`; isolated temporary saves were used under `C:\tmp\koalapet-m4-review`. No desktop background, private application, overlay shell, tray, Alt+Tab, or mixed-DPI behavior is claimed from these images.

## Reproduction

From the repository root, start the visible client with a temporary save and development actions:

```powershell
& "C:\tmp\Godot-4.7.1\Godot_v4.7.1-stable_win64.exe" --path game -- --dev-tools --mode=expanded --save-path=C:/tmp/koalapet-m4-review/review.json --review-actions=choose:moss,hatch,train,hour
```

Useful review actions include `battle`, `round`, `win`, `loss`, `dungeon`, `node`, `dungeon_event`, `injury_treatment`, `poor:tide`, and `mode:minimal|small|expanded`. The normal application/domain paths perform the actions; shortcuts are development-only.

## Matrix

| Evidence | Reproduction state | Result | SHA-256 |
|---|---|---|---|
| `screenshots/M4-EVO-GOOD.png` | moss starter, hatch, train, one simulated hour | Mossblüte good-care route visible; discovered route recorded | `96e3ef2e8f8f053775574e19b69f580dd797d0ad2a1a21cdc14198b9e397dff3` |
| `screenshots/M4-EVO-POOR.png` | tide starter, `poor:tide` | Schilfwacht poor-care route visible; two Pflegefehler visible | `a5a1d2e21393ec185ea30d21ff66d53b93c992a67efb720b35637e39fb3fb46e` |
| `screenshots/M4-UI-SMALL.png` | evolved pet, Small mode | compact care/adventure layout visible | `cee2c26046c8476e4a83b3b2d4ecdbf694ce37b3a5a5d0a990493a627b89ba07` |
| `screenshots/M4-BATTLE-IN-PROGRESS.png` | normal encounter, battle started, one round | battle indicator and round action visible | `6f01ffba5d2e538ea867e89465296a2edb97c4a70443382aea3ef37f4bae741e` |
| `screenshots/M4-DUNGEON-UNLOCKED.png` | two deterministic wins, dungeon started | Dungeon state and next-stage action visible | `63d7c96a95aaa8d54836eaacf8a6eaf0211799859721c2aac03b057b6de5ad52` |
| `screenshots/M4-DUNGEON-EVENT.png` | dungeon node two choice | dungeon node progression remained visible | `5b6237dc63fd636dc5eb2e49e7f881e03ffc17b2b54e40633457bd503996a934` |
| `screenshots/M4-BOSS-BATTLE.png` | dungeon node five | boss battle context, dungeon node 5, transient HP visible | `a9a69b36bacda6ac4691a19d15f4475d3d69b7de411078178e0ea2417951bd97` |
| `screenshots/M4-INJURY-DEFEAT.png` | forced development loss | explicit Wurzelzerrung injury and treatment action visible | `bd0014e29960e75babbfe68045297441eeb627d069428d69ed2af8d4e7823654` |
| `screenshots/M4-INJURY-TREATED.png` | reload same save, injury treatment | injury cleared; Ready for care visible | `723fb0172a8a32af902fd54be56e63168f930b3bb8ba44df683b2c80f6f9ad88` |
| `screenshots/M4-FIRST-CLEAR-REWARDS.png` | dungeon clear | Expanded view shows battle result/XP and reward/inventory context | `3bd7e652bacfffefed777657734dd74b27cd8de41c9269ef867e8a785dc65673` |

Minimal mode was started and the pet-local status path executed. The Windows `PrintWindow` path does not expose the transparent layered pet pixels reliably, so no Minimal screenshot is promoted as direct visual evidence. This is a capture limitation, not overlay acceptance. Native shell, taskbar, tray, Alt+Tab, focus, mixed-DPI, and accessibility acceptance remain outside this gameplay matrix.
