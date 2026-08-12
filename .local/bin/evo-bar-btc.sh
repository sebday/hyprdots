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

# --- Unrealized P/L % (Kraken private API) ---
if [[ -z "${KRAKEN_API_KEY:-}" || -z "${KRAKEN_SECRET:-}" ]]; then
    KRAKEN_ERR="set KRAKEN_API_KEY and KRAKEN_SECRET in secrets.env"
else
    KRAKEN_ERR=""
    export KRAKEN_API_KEY KRAKEN_SECRET
    UPNL_PCT=$(python3 - 2>/dev/null <<'PY'
import base64, hashlib, hmac, json, os, time, urllib.parse, urllib.request


def kraken_private(path, data=None):
    api_key = os.environ["KRAKEN_API_KEY"]
    secret = base64.b64decode(os.environ["KRAKEN_SECRET"])
    data = dict(data or {})
    data["nonce"] = str(int(time.time() * 1000))
    postdata = urllib.parse.urlencode(data)
    encoded = (str(data["nonce"]) + postdata).encode()
    message = path.encode() + hashlib.sha256(encoded).digest()
    sig = hmac.new(secret, message, hashlib.sha512)
    req = urllib.request.Request(
        "https://api.kraken.com" + path,
        data=postdata.encode(),
        headers={
            "API-Key": api_key,
            "API-Sign": base64.b64encode(sig.digest()).decode(),
        },
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.load(resp)


def main():
    pub = json.load(
        urllib.request.urlopen(
            "https://api.kraken.com/0/public/Ticker?pair=XBTUSD", timeout=10
        )
    )
    price = float(next(iter(pub["result"].values()))["c"][0])

    bal = float(kraken_private("/0/private/Balance")["result"].get("XXBT", 0) or 0)
    if bal <= 0:
        print("0")
        return

    trades = kraken_private("/0/private/TradesHistory", {"trades": True})
    buy_cost = buy_vol = 0.0
    for t in trades.get("result", {}).get("trades", {}).values():
        pair = t.get("pair", "")
        if "XBT" not in pair or ("USD" not in pair and "ZUSD" not in pair):
            continue
        if t.get("type") != "buy":
            continue
        buy_vol += float(t["vol"])
        buy_cost += float(t["cost"])

    if buy_vol <= 0:
        print("0")
        return

    avg_entry = buy_cost / buy_vol
    upnl = (price - avg_entry) / avg_entry * 100.0
    print(f"{upnl:.2f}")


if __name__ == "__main__":
    main()
PY
    ) || KRAKEN_ERR="kraken api request failed"
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
