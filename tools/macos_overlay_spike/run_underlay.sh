#!/bin/zsh
set -euo pipefail

godot_path="${GODOT_PATH:-/Applications/Godot.app/Contents/MacOS/Godot}"
repository_root="${0:A:h:h:h}"
game_path="$repository_root/game"

if [[ "$(uname -s)" != "Darwin" ]]; then
	print -u2 "BLOCKED_NOT_MACOS: run_underlay.sh requires an interactive macOS session."
	exit 2
fi
if [[ ! -x "$godot_path" ]]; then
	print -u2 "GODOT_NOT_FOUND: $godot_path"
	exit 2
fi

exec "$godot_path" --path "$game_path" --scene res://scenes/spikes/overlay_underlay_probe.tscn -- "$@"
