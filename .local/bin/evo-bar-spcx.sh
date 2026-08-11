#!/bin/bash
# Evo bar: SPCX USD price + Trading 212 unrealized P/L %.
#
# Credentials: ~/.local/share/evo-shell/secrets.env (T212_API_KEY, T212_API_SECRET)
# App: Settings → API (Beta) → account + portfolio read permissions

source "${HOME}/.local/bin/evo-bar-common.sh"

SECRETS_FILE="$EVO_SECRETS_FILE"
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
    jq -cn --arg text "$1" --arg tooltip "$2" '{text: $text, tooltip: $tooltip}'
}

if [[ -z "${T212_API_KEY:-}" || -z "${T212_API_SECRET:-}" ]]; then
    json_out "SPCX —" "Set T212_API_KEY and T212_API_SECRET in ~/.local/share/evo-shell/secrets.env"
    exit 0
fi

BASE_URL="${T212_BASE_URL:-https://live.trading212.com}"
POSITION=$(curl -sf --max-time 15 \
    -u "${T212_API_KEY}:${T212_API_SECRET}" \
    "${BASE_URL}/api/v0/equity/positions?ticker=SPCX_US_EQ" 2>/dev/null) || POSITION=""

if [[ -z "$POSITION" ]]; then
    json_out "SPCX —" "Trading 212 SPCX position unavailable"
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
    json_out "SPCX —" "No SPCX position found on Trading 212"
    exit 0
fi

PRICE_S=$(fmt_price "$LAST")

if ! awk -v c="$TOTAL_COST" 'BEGIN { exit !(c + 0 > 0) }'; then
    TEXT="SPCX ${PRICE_S} —"
    TIP="SPCX/USD · Trading 212
Price: ${PRICE_S}
Unrealized P/L: unavailable (cost basis is zero)"
else
    PCT_S=$(awk -v upnl="$UPNL" -v cost="$TOTAL_COST" 'BEGIN {
        printf "%+.2f", (upnl / cost) * 100
    }')
    TEXT="SPCX ${PRICE_S}"
    TIP="SPCX/USD · Trading 212
Price: ${PRICE_S}
Unrealized P/L: ${PCT_S}%"
fi

json_out "$TEXT" "$TIP"
