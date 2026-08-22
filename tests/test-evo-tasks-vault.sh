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
mkdir -p "${HOME}/.config/obsidian" "$EVOSHELL_STATE/apps"

vault_with_tasks="${tmpdir}/notes"
vault_without="${tmpdir}/plans"
mkdir -p "$vault_with_tasks" "$vault_without"
printf '# Tasks\n\n- [ ] one\n' >"${vault_with_tasks}/tasks.md"

cat >"${HOME}/.config/obsidian/obsidian.json" <<EOF
{"vaults":{"plans":{"path":"${vault_without}"},"notes":{"path":"${vault_with_tasks}"}}}
EOF

tasks_file="$("$tasks" settings get | jq -r '.tasksFile')"
[[ "$tasks_file" == "${vault_with_tasks}/tasks.md" ]] || {
    echo "expected tasks in vault with tasks.md, got: $tasks_file" >&2
    exit 1
}

rm -f "${vault_with_tasks}/tasks.md"
tasks_file="$("$tasks" settings get | jq -r '.tasksFile')"
[[ "$tasks_file" == *"/apps/tasks.json" ]] || {
    echo "expected json fallback without tasks.md, got: $tasks_file" >&2
    exit 1
}

echo "ok"
