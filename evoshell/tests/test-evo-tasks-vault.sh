#!/usr/bin/env bash
set -euo pipefail

root="${EVOSHELL_ROOT:-$HOME/projects/evoshell}"
tasks="${root}/bin/evo-tasks"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

export HOME="${tmpdir}/home"
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_STATE_HOME="${HOME}/.local/state"
export EVOSHELL_CONFIG="${XDG_CONFIG_HOME}/evoshell"
export EVOSHELL_STATE="${XDG_STATE_HOME}/evoshell"

tasks_file="$("$tasks" settings get | jq -r '.tasksFile')"
[[ "$tasks_file" == "${EVOSHELL_STATE}/apps/tasks.json" ]] || {
    echo "expected json tasks file, got: $tasks_file" >&2
    exit 1
}

[[ "$("$tasks" settings get | jq -r '.format')" == "json" ]] || {
    echo "expected json format" >&2
    exit 1
}

"$tasks" save '{"tasks":[{"text":"one","done":false}]}' >/dev/null
loaded="$("$tasks" load)"
jq -e '.tasks | length == 1 and .[0].text == "one"' <<<"$loaded" >/dev/null

echo "ok"
