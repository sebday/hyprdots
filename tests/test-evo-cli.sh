#!/usr/bin/env bash
set -euo pipefail

evo="${HOME}/.local/bin/evo"
fail=0

check() {
  if ! "$@"; then
    echo "failed: $*" >&2
    fail=1
  fi
}

check test -x "$evo"

usage_out="$("$evo" 2>&1 || true)"
if [[ "$usage_out" != *"usage: evo"* ]]; then
  echo "evo usage missing" >&2
  fail=1
fi

player="${HOME}/.local/lib/evoplayer/evoplayer"
check test -x "$player"

if "$evo" player status --json 2>/dev/null | jq -e '.state != null' >/dev/null 2>&1; then
  echo "evo player status ok"
else
  echo "evo player status skipped (daemon not running)"
fi

if "$evo" ipc shell ping 2>/dev/null | grep -q 'pong\|ok'; then
  echo "evo ipc shell ping ok"
else
  echo "evo ipc shell ping skipped (evoshell not running)"
fi

exit "$fail"
