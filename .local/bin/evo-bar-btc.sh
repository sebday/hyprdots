#!/bin/bash
# Evo stats panel: Kraken BTC/USD price + unrealized P/L % on XXBT holdings.
# Persists daily closes (seeded from Kraken OHLC) for stats-panel charts.
#
# Credentials: ~/.local/share/evo-shell/secrets.env (KRAKEN_API_KEY, KRAKEN_SECRET)

source "${HOME}/.local/bin/evo-bar-common.sh"

if cached=$(evo_bar_cache_read "btc" 60 2>/dev/null); then
    printf '%s\n' "$cached"
    exit 0
fi

SECRETS_FILE="$EVO_SECRETS_FILE"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/evo-shell"
HISTORY_FILE="${STATE_DIR}/btc-history.json"
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

fetch_ohlc_rows() {
    local ohlc
    ohlc=$(curl -sf --max-time 10 \
        'https://api.kraken.com/0/public/OHLC?pair=XBTUSD&interval=1440' 2>/dev/null) || ohlc=""
    if [[ -z "$ohlc" ]]; then
        return 0
    fi
    echo "$ohlc" | jq -r '
        (.result | to_entries[0].value) // []
        | .[-30:]
        | .[]
        | ((.[0] | tonumber | strftime("%Y-%m-%d")) + "|" + (.[4] | tonumber | tostring))
    ' 2>/dev/null || true
}

build_bars() {
    local price="$1"
    local today rows=()
    today=$(date -u +%Y-%m-%d)
    mkdir -p "$STATE_DIR"
    evo_bar_load_heatmap_colors || true

    mapfile -t rows < <({
        fetch_ohlc_rows
        printf '%s|%s\n' "$today" "$price"
    } | evo_bar_merge_history "$HISTORY_FILE" "$HISTORY_KEEP")

    # Prefer last 14 days for the chart (Shopify-length window).
    if ((${#rows[@]} > 14)); then
        rows=("${rows[@]: -14}")
    fi
    if ((${#rows[@]} == 0)); then
        printf '[]'
        return
    fi
    evo_bar_build_bars_json "${rows[@]}"
}

# --- Kraken public ticker ---
TICKER=$(curl -sf --max-time 8 'https://api.kraken.com/0/public/Ticker?pair=XBTUSD' 2>/dev/null) || TICKER=""

if [[ -z "$TICKER" ]] || ! echo "$TICKER" | jq -e '.result | length > 0' >/dev/null 2>&1; then
    # Still try to render from cached history.
    evo_bar_load_heatmap_colors || true
    if [[ -f "$HISTORY_FILE" ]]; then
        mapfile -t rows < <(jq -r '.[] | "\(.date)|\(.value)"' "$HISTORY_FILE" 2>/dev/null | tail -n 14)
        if ((${#rows[@]} > 0)); then
            BARS_JSON=$(evo_bar_build_bars_json "${rows[@]}")
            json_out "₿ —" "Kraken ticker unavailable" "" "$BARS_JSON"
            exit 0
        fi
    fi
    json_out "₿ —" "Kraken ticker unavailable" "" "[]"
    exit 0
fi

LAST=$(echo "$TICKER" | jq -r '.result | to_entries[0].value.c[0]')
PRICE_S=$(fmt_price "$LAST")
BARS_JSON=$(build_bars "$LAST")

kraken_private() {
    local api_path="$1"
    local extra_data="${2:-}"
    local nonce postdata sha256_bin message sig secret_hex
    nonce=$(date +%s%3N)
    postdata="nonce=${nonce}"
    [[ -n "$extra_data" ]] && postdata="${postdata}&${extra_data}"
    secret_hex=$(printf '%s' "$KRAKEN_SECRET" | base64 -d | xxd -p -c 256)
    sha256_bin=$(printf '%s%s' "$nonce" "$postdata" | openssl dgst -sha256 -binary)
    message=$(printf '%s' "$api_path"; printf '%s' "$sha256_bin")
    sig=$(printf '%s' "$message" | openssl dgst -sha512 -mac HMAC -macopt "hexkey:${secret_hex}" -binary | base64 -w0 2>/dev/null \
        || printf '%s' "$message" | openssl dgst -sha512 -mac HMAC -macopt "hexkey:${secret_hex}" -binary | base64)
    curl -sf --max-time 15 -X POST "https://api.kraken.com${api_path}" \
        -d "$postdata" \
        -H "API-Key: ${KRAKEN_API_KEY}" \
        -H "API-Sign: ${sig}"
}

kraken_upnl_pct() {
    local price bal_resp bal trades_resp buy_vol buy_cost
    price=$(curl -sf --max-time 10 'https://api.kraken.com/0/public/Ticker?pair=XBTUSD' | jq -r '.result | to_entries[0].value.c[0]')
    [[ -n "$price" && "$price" != "null" ]] || return 1
    bal_resp=$(kraken_private "/0/private/Balance") || return 1
    bal=$(jq -r '.result.XXBT // 0' <<<"$bal_resp")
    awk -v b="$bal" 'BEGIN { exit (b > 0) ? 0 : 1 }' || {
        echo 0
        return 0
    }
    trades_resp=$(kraken_private "/0/private/TradesHistory" "trades=true") || return 1
    buy_vol=$(jq -r '
        [.result.trades // {} | to_entries[].value
         | select((.pair | test("XBT")) and (.pair | test("USD|ZUSD")))
         | select(.type == "buy")
         | .vol | tonumber] | add // 0
    ' <<<"$trades_resp")
    buy_cost=$(jq -r '
        [.result.trades // {} | to_entries[].value
         | select((.pair | test("XBT")) and (.pair | test("USD|ZUSD")))
         | select(.type == "buy")
         | .cost | tonumber] | add // 0
    ' <<<"$trades_resp")
    awk -v v="$buy_vol" 'BEGIN { exit (v > 0) ? 0 : 1 }' || {
        echo 0
        return 0
    }
    awk -v price="$price" -v buy_cost="$buy_cost" -v buy_vol="$buy_vol" 'BEGIN {
        avg = buy_cost / buy_vol
        printf "%.2f", (price - avg) / avg * 100
    }'
}

# --- Unrealized P/L % (Kraken private API) ---
if [[ -z "${KRAKEN_API_KEY:-}" || -z "${KRAKEN_SECRET:-}" ]]; then
    KRAKEN_ERR="set KRAKEN_API_KEY and KRAKEN_SECRET in secrets.env"
else
    KRAKEN_ERR=""
    export KRAKEN_API_KEY KRAKEN_SECRET
    UPNL_PCT=$(kraken_upnl_pct 2>/dev/null) || KRAKEN_ERR="kraken api request failed"
fi

if [[ -n "${UPNL_PCT:-}" && "$UPNL_PCT" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
    PCT_S=$(awk -v p="$UPNL_PCT" 'BEGIN { printf "%+.2f", p }')
    TEXT="₿ ${PRICE_S}"
    DETAIL="${PRICE_S} · ${PCT_S}%"
    TIP="BTC/USD · Kraken
Price: $(fmt_price "$LAST")
Unrealized P/L: ${PCT_S}%"
elif [[ -n "$KRAKEN_ERR" ]]; then
    TEXT="₿ ${PRICE_S} —"
    DETAIL="${PRICE_S} · —"
    TIP="BTC/USD · Kraken
Price: $(fmt_price "$LAST")
Unrealized P/L: unavailable (${KRAKEN_ERR})"
else
    TEXT="₿ ${PRICE_S} —"
    DETAIL="${PRICE_S} · —"
    TIP="BTC/USD · Kraken
Price: $(fmt_price "$LAST")
Unrealized P/L: unavailable"
fi

output=$(json_out "$TEXT" "$TIP" "$DETAIL" "$BARS_JSON")
printf '%s\n' "$output" | evo_bar_cache_write "btc"
printf '%s\n' "$output"
