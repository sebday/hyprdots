#!/usr/bin/env bash
# Launch commands through Hyprland's exec dispatcher.
# Hyprland 0.56+ parses dispatch exec as Lua; multi-word commands need exec_cmd().
set -euo pipefail

if (($# == 0)); then
	echo "usage: hypr-launch.sh <command...>" >&2
	exit 1
fi

cmd="$*"
escaped="${cmd//\\/\\\\}"
escaped="${escaped//\"/\\\"}"
hyprctl --quiet eval "hl.dispatch(hl.dsp.exec_cmd(\"$escaped\"))"
