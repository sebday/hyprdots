#!/usr/bin/env bash
set -euo pipefail

root="${EVOSHELL_ROOT:-$HOME/projects/evoshell}"
bin="${EVOSHELL_BIN:-${root}/bin}"
script="${bin}/evo-system-packages"
fail=0

assert_json() {
  jq -e "$1" >/dev/null 2>&1 || {
    echo "assert failed: $1" >&2
    fail=1
  }
}

[[ -x "$script" ]] || {
  echo "missing executable: $script" >&2
  exit 1
}

if ! command -v pacman >/dev/null 2>&1; then
  echo "skip: pacman not available"
  exit 0
fi

out="$("$script" breakdown)"
assert_json '.ok == true' <<<"$out"
assert_json '.summary | type == "object"' <<<"$out"
assert_json '.categories | type == "array"' <<<"$out"
assert_json '.orphans | type == "array"' <<<"$out"
assert_json '(.categories[] | .name | type == "string") and (.categories[] | .packages | type == "array")' <<<"$out"

exit "$fail"
