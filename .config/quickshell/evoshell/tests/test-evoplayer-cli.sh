#!/usr/bin/env bash
set -euo pipefail

bin="${HOME}/.local/bin"
lib="${HOME}/.local/lib/evoshell/player"
fail=0

check() {
  if ! "$@"; then
    echo "failed: $*" >&2
    fail=1
  fi
}

check test -x "${bin}/evo-player"
check test -f "${lib}/history-report.py"

# playlist validation
check bash -c '"'"${bin}/evo-player"'" playlist create "bad/name" --json >/dev/null 2>&1 && exit 1 || exit 0'

tmp_name="evo-test-$$"
check bash -c '"'"${bin}/evo-player"'" playlist create "'"${tmp_name}"'" --json | jq -e .ok'
check bash -c '"'"${bin}/evo-player"'" playlist delete "'"${tmp_name}"'" --json | jq -e .ok'

# history report (local fallback allowed)
out="$("${bin}/evo-player" history report --json 2>/dev/null || true)"
if [[ -n "$out" ]]; then
  echo "$out" | jq -e '.totals.scrobbles != null' >/dev/null || {
    echo "history report missing totals" >&2
    fail=1
  }
else
  echo "history report returned empty output" >&2
  fail=1
fi

# queue up-next json
check bash -c '"'"${bin}/evo-player"'" queue up-next --json | jq -e "type == \"array\""'

exit "$fail"
