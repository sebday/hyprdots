#!/usr/bin/env bash
set -euo pipefail

root="${EVOSHELL_ROOT:-$HOME/projects/evoshell}"
layout="${EVOSHELL_BIN:-${root}/bin}/evo-layout"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

export XDG_CONFIG_HOME="${tmpdir}/config"
export XDG_STATE_HOME="${tmpdir}/state"
export EVOSHELL_CONFIG="${XDG_CONFIG_HOME}/evoshell"
export EVOSHELL_STATE="${XDG_STATE_HOME}/evoshell"
mkdir -p "$EVOSHELL_CONFIG" "${EVOSHELL_STATE}"
printf '{"fieldsetRounding":true,"obsidianVault":"/tmp/vault"}' >"${EVOSHELL_CONFIG}/ui.json"

set_out="$("$layout" side set '{"open":true,"module":"calc","focus":"tasks"}')"
[[ "$set_out" == *'"open":true'* ]] || { echo "side set open failed: $set_out" >&2; exit 1; }
[[ "$set_out" == *'"focus":"tasks"'* ]] || { echo "side set focus failed: $set_out" >&2; exit 1; }

ui_merged="$(cat "${EVOSHELL_CONFIG}/ui.json")"
[[ "$ui_merged" == *'"fieldsetRounding":true'* ]] || { echo "ui config dropped fieldsetRounding: $ui_merged" >&2; exit 1; }
[[ "$ui_merged" == *'"/tmp/vault"'* ]] || { echo "ui config dropped obsidianVault: $ui_merged" >&2; exit 1; }

session_merged="$(cat "${EVOSHELL_STATE}/session.json")"
[[ "$session_merged" == *'"sidePanel"'* ]] || { echo "session missing sidePanel: $session_merged" >&2; exit 1; }

get_out="$("$layout" side get)"
[[ "$get_out" == "$set_out" ]] || { echo "side get mismatch: $get_out vs $set_out" >&2; exit 1; }

"$layout" ui toggle fieldsetRounding >/dev/null
ui_merged="$(cat "${EVOSHELL_CONFIG}/ui.json")"
session_merged="$(cat "${EVOSHELL_STATE}/session.json")"
[[ "$session_merged" == *'"sidePanel"'* ]] || { echo "fieldset toggle dropped sidePanel: $session_merged" >&2; exit 1; }
[[ "$ui_merged" == *'"/tmp/vault"'* ]] || { echo "fieldset toggle dropped obsidianVault: $ui_merged" >&2; exit 1; }

close_out="$("$layout" side set '{"open":false,"module":"calc","focus":""}')"
[[ "$close_out" == *'"open":false'* ]] || { echo "side set close failed: $close_out" >&2; exit 1; }

echo "ok"
