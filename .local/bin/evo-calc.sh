#!/usr/bin/env bash
# Calculator eval + history for evo-shell calc panel.

set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/evo-shell"
HISTORY_FILE="${STATE_DIR}/calc-history.json"
MAX_ITEMS=100
HISTORY_LIMIT=50

mkdir -p "$STATE_DIR"

normalize_expr() {
    local expr="${1:-}"
    expr="${expr//×/*}"
    expr=$(printf '%s' "$expr" | sed -E 's/([0-9.)])[xX]([0-9.(])/\1*\2/g')
    printf '%s' "$expr"
}

eval_expr() {
    local expr="${1:-}"
    [[ -n "$expr" ]] || return 1
    if [[ ! "$expr" =~ ^[0-9+*/().[:space:]xX×-]+$ ]]; then
        printf 'error\n'
        return 1
    fi
    local normalized result
    normalized=$(normalize_expr "$expr")
    if ! result=$(printf 'scale=10\n%s\n' "$normalized" | bc 2>/dev/null); then
        printf 'error\n'
        return 1
    fi
    result="${result//$'\n'/}"
    result=$(printf '%s' "$result" | sed -E 's/\.?0+$//; s/\.$//')
    [[ -n "$result" ]] || {
        printf 'error\n'
        return 1
    }
    printf '%s\n' "$result"
}

history_list() {
    python3 - "$HISTORY_FILE" "$HISTORY_LIMIT" <<'PY'
import json
import sys

path, limit = sys.argv[1], int(sys.argv[2])
try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = []

if not isinstance(data, list):
    data = []

for entry in data[-limit:]:
    if not isinstance(entry, dict):
        continue
    expr = str(entry.get("expr", ""))
    result = str(entry.get("result", ""))
    if expr:
        print(f"{expr}\t{result}")
PY
}

add_history() {
    local expr="${1:-}" result="${2:-}"
    [[ -n "$expr" && -n "$result" ]] || return 1
    python3 - "$HISTORY_FILE" "$MAX_ITEMS" "$expr" "$result" <<'PY'
import json
import sys

path, max_items, expr, result = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = []

if not isinstance(data, list):
    data = []

data.append({"expr": expr, "result": result})
data = data[-max_items:]

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False)
    f.write("\n")
PY
}

case "${1:-}" in
eval) eval_expr "${2:-}" ;;
history) history_list ;;
add) add_history "${2:-}" "${3:-}" ;;
*)
    echo "usage: evo-calc.sh eval <expr>|history|add <expr> <result>" >&2
    exit 1
    ;;
esac
