#!/usr/bin/env bash
# Persist launch/pick counts for frecency sorting in evo-shell menus.

set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/evo-shell"
STATE_FILE="${STATE_DIR}/usage.json"

usage_python() {
    python3 - "$STATE_FILE" "$@" <<'PY'
import json
import os
import sys

path = sys.argv[1]
cmd = sys.argv[2]

def load():
    if not os.path.isfile(path):
        return {"apps": {}}
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
    data.setdefault("apps", {})
    return data

def save(data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, separators=(",", ":"))

if cmd == "bump":
    bucket = sys.argv[3]
    key = sys.argv[4]
    if bucket != "apps" or not key:
        sys.exit(1)
    data = load()
    data[bucket][key] = int(data[bucket].get(key, 0)) + 1
    save(data)
elif cmd == "dump":
    print(json.dumps(load(), ensure_ascii=False))
else:
    sys.exit(1)
PY
}

case "${1:-}" in
bump)
    [[ -n "${2:-}" && -n "${3:-}" ]] || exit 1
    usage_python bump "$2" "$3"
    ;;
dump) usage_python dump ;;
*)
    echo "usage: evo-usage.sh bump apps <key>|dump" >&2
    exit 1
    ;;
esac
