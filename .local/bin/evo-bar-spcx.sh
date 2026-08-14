#!/bin/bash
# Evo stats panel: SPCX USD price + Trading 212 unrealized P/L %.
# Seeds/persists daily closes (Yahoo chart + live T212 price) for stats-panel charts.
#
# Credentials: ~/.local/share/evoshell/secrets.env (T212_API_KEY, T212_API_SECRET)
# App: Settings → API (Beta) → account + portfolio read permissions

source "${HOME}/.local/bin/evo-bar-common.sh"

if cached=$(evo_bar_cache_read "spcx" 60 2>/dev/null); then
    printf '%s\n' "$cached"
    exit 0
fi

SECRETS_FILE="$EVO_SECRETS_FILE"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/evoshell"
HISTORY_FILE="${STATE_DIR}/spcx-history.json"
HISTORY_KEEP=30

if [[ -f "$SECRETS_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$SECRETS_FILE"
fi

fmt_price() {
  awk -v p="$1" '
    function comma(n, s, i, out, len) {
      s = sprintf("%.0f", n)
      len = length(s)
      for (i = 1; i <= len; i++) {
        if (i > 1 && (len - i + 1) % 3 == 0)
          out = out ","
        out = out substr(s, i, 1)
      }
      return out
    }
    BEGIN {
      if (p >= 10000)
        printf "$%s", comma(p)
      else
        printf "$%.2f", p
    }'
}

json_out() {
    local text="$1" tooltip="$2" detail="${3:-}" bars="${4:-[]}"
    jq -cn \
        --arg text "$text" \
        --arg tooltip "$tooltip" \
        --arg detail "$detail" \
        --argjson bars "$bars" \
        '{text: $text, tooltip: $tooltip, detail: $detail, bars: $bars}'
}

fetch_yahoo_rows() {
    local raw
    raw=$(curl -sf --max-time 12 \
        -A 'Mozilla/5.0' \
        'https://query1.finance.yahoo.com/v8/finance/chart/SPCX?interval=1d&range=1mo' 2>/dev/null) || raw=""
    if [[ -z "$raw" ]]; then
        return 0
    fi
    echo "$raw" | jq -r '
        .chart.result[0] as $r
        | ($r.timestamp // []) as $ts
        | ($r.indicators.quote[0].close // []) as $c
        | [range(0; ($ts|length))]
        | .[]
        | select($c[.] != null)
        | (($ts[.] | tonumber | strftime("%Y-%m-%d")) + "|" + ($c[.] | tonumber | tostring))
    ' 2>/dev/null || true
}

build_bars() {
    local price="$1"
    local today rows=()
    today=$(date +%Y-%m-%d)
    mkdir -p "$STATE_DIR"
    evo_bar_load_heatmap_colors || true

    mapfile -t rows < <({
        fetch_yahoo_rows
        printf '%s|%s\n' "$today" "$price"
    } | evo_bar_merge_history "$HISTORY_FILE" "$HISTORY_KEEP")

    if ((${#rows[@]} > 14)); then
        rows=("${rows[@]: -14}")
    fi
    if ((${#rows[@]} == 0)); then
        printf '[]'
        return
    fi
    evo_bar_build_bars_json "${rows[@]}"
}

bars_from_cache() {
    evo_bar_load_heatmap_colors || true
    if [[ ! -f "$HISTORY_FILE" ]]; then
        printf '[]'
        return
    fi
    local rows=()
    mapfile -t rows < <(jq -r '.[] | "\(.date)|\(.value)"' "$HISTORY_FILE" 2>/dev/null | tail -n 14)
    if ((${#rows[@]} == 0)); then
        printf '[]'
        return
    fi
    evo_bar_build_bars_json "${rows[@]}"
}

if [[ -z "${T212_API_KEY:-}" || -z "${T212_API_SECRET:-}" ]]; then
    json_out "SPCX —" "Set T212_API_KEY and T212_API_SECRET in ~/.local/share/evoshell/secrets.env" "" "$(bars_from_cache)"
    exit 0
fi

BASE_URL="${T212_BASE_URL:-https://live.trading212.com}"
POSITION=$(curl -sf --max-time 15 \
    -u "${T212_API_KEY}:${T212_API_SECRET}" \
    "${BASE_URL}/api/v0/equity/positions?ticker=SPCX_US_EQ" 2>/dev/null) || POSITION=""

if [[ -z "$POSITION" ]]; then
    json_out "SPCX —" "Trading 212 SPCX position unavailable" "" "$(bars_from_cache)"
    exit 0
fi

read -r LAST UPNL TOTAL_COST < <(
    echo "$POSITION" | jq -r '
        (if type == "array" then .[0] else . end) // empty
        | [
            (.currentPrice // empty),
            (.walletImpact.unrealizedProfitLoss // 0),
            (.walletImpact.totalCost // 0)
          ]
        | @tsv
    ' 2>/dev/null
)

if [[ -z "${LAST:-}" ]]; then
    json_out "SPCX —" "No SPCX position found on Trading 212" "" "$(bars_from_cache)"
    exit 0
fi

PRICE_S=$(fmt_price "$LAST")
BARS_JSON=$(build_bars "$LAST")

if ! awk -v c="$TOTAL_COST" 'BEGIN { exit !(c + 0 > 0) }'; then
    TEXT="SPCX ${PRICE_S} —"
    DETAIL="${PRICE_S} · —"
    TIP="SPCX/USD · Trading 212
Price: ${PRICE_S}
Unrealized P/L: unavailable (cost basis is zero)"
else
    PCT_S=$(awk -v upnl="$UPNL" -v cost="$TOTAL_COST" 'BEGIN {
        printf "%+.2f", (upnl / cost) * 100
    }')
    TEXT="SPCX ${PRICE_S}"
    DETAIL="${PRICE_S} · ${PCT_S}%"
    TIP="SPCX/USD · Trading 212
Price: ${PRICE_S}
Unrealized P/L: ${PCT_S}%"
fi

output=$(json_out "$TEXT" "$TIP" "$DETAIL" "$BARS_JSON")
printf '%s\n' "$output" | evo_bar_cache_write "spcx"
printf '%s\n' "$output"
