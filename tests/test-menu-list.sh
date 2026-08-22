#!/usr/bin/env bash
set -euo pipefail

root="${EVOSHELL_ROOT:-$HOME/projects/evoshell}"
lib="${root}/bin/evo-menu-list-lib"
fail=0

# shellcheck source=/dev/null
source "$lib"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
home="${tmpdir}/home"
mkdir -p "${home}/.config/hypr"

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" != "$actual" ]]; then
    echo "FAIL: $label" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
    fail=1
  fi
}

assert_json_keys() {
  local json="$1"
  local keys
  keys="$(jq -r '.[0] | keys | sort | join(",")' <<< "$json")"
  assert_eq "bindings json keys" "detail,files,keys,name" "$keys"
}

out="$(EVOSHELL_ROOT="$root" menu_list_bindings "" "$home")"
line_count="$(printf '%s\n' "$out" | sed '/^$/d' | wc -l)"
if (( line_count < 20 )); then
  echo "FAIL: expected at least 20 bindings, got $line_count" >&2
  fail=1
fi

json="$(printf '%s\n' "$out" | menu_list_bindings_to_json)"
assert_json_keys "$json"

name="$(jq -r '.[] | select(.keys == "SUPER + W") | .name' <<< "$json")"
assert_eq "close binding name" "Close Active Window" "$name"

detail="$(jq -r '.[] | select(.keys == "SUPER + left") | .detail' <<< "$json")"
assert_eq "focus left detail" "Hyprland: move focus left" "$detail"

lock_detail="$(jq -r '.[] | select(.keys == "SUPER + L") | .detail' <<< "$json")"
if [[ "$lock_detail" != Runs:*evo*system*lock* ]]; then
  echo "FAIL: lock binding detail" >&2
  echo "  expected detail matching: Runs:*evo*system*lock*" >&2
  echo "  actual:   $lock_detail" >&2
  fail=1
fi

global="$(jq -r '.[] | select(.keys == "SUPER + Space") | .detail' <<< "$json")"
assert_eq "global dispatcher" "Hyprland global event: evoshell:systemMenu" "$global"

settings_name="$(jq -r '.[] | select(.keys == "SUPER + B") | .name' <<< "$json")"
assert_eq "evoshell settings binding" "Settings" "$settings_name"

print_name="$(jq -r '.[] | select(.keys == "PRINT") | .name' <<< "$json")"
assert_eq "evoshell screenshot binding" "Screenshot region" "$print_name"

terminal_name="$(jq -r '.[] | select(.keys == "SUPER + Return") | .name' <<< "$json")"
assert_eq "desktop terminal binding" "Terminal" "$terminal_name"

settings_files="$(jq -r '.[] | select(.keys == "SUPER + B") | .files' <<< "$json")"
if [[ "$settings_files" != *"${root}/hypr/bindings.lua"* ]]; then
  echo "FAIL: evoshell settings source file" >&2
  echo "  expected to include: ${root}/hypr/bindings.lua" >&2
  echo "  actual:   $settings_files" >&2
  fail=1
fi

w_count="$(jq -r '[.[] | select(.keys == "SUPER + W")] | length' <<< "$json")"
assert_eq "single SUPER + W entry" "1" "$w_count"

exit "$fail"
