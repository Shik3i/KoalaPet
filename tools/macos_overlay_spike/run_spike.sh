#!/bin/zsh
set -euo pipefail

godot_path="${GODOT_PATH:-/Applications/Godot.app/Contents/MacOS/Godot}"
repository_root="${0:A:h:h:h}"
game_path="$repository_root/game"
expected_version="4.7.1.stable.official.a13da4feb"

if [[ "$(uname -s)" != "Darwin" ]]; then
	print -u2 "BLOCKED_NOT_MACOS: run_spike.sh requires an interactive macOS session."
	exit 2
fi
if [[ ! -x "$godot_path" ]]; then
	print -u2 "GODOT_NOT_FOUND: $godot_path"
	exit 2
fi

actual_version="$($godot_path --version | head -n 1)"
if [[ "$actual_version" != "$expected_version" ]]; then
	print -u2 "GODOT_VERSION_MISMATCH: expected $expected_version, got $actual_version"
	exit 2
fi

exec "$godot_path" --path "$game_path" --scene res://scenes/spikes/windows_overlay_spike.tscn -- "$@"
