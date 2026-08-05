#!/bin/bash
# Waybar: SpaceX (SPCX) NASDAQ price in USD.

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

QUOTE=$(curl -sf --max-time 8 \
    'https://api.nasdaq.com/api/quote/SPCX/info?assetclass=stocks' \
    -H 'User-Agent: Mozilla/5.0' \
    -H 'Accept: application/json' 2>/dev/null) || QUOTE=""

if [[ -z "$QUOTE" ]] || ! echo "$QUOTE" | jq -e '.data.primaryData.lastSalePrice' >/dev/null 2>&1; then
    json_out "SPCX —" "SpaceX (SPCX) quote unavailable"
    exit 0
fi

LAST_S=$(echo "$QUOTE" | jq -r '.data.primaryData.lastSalePrice')
CHANGE_S=$(echo "$QUOTE" | jq -r '.data.primaryData.percentageChange // "—"')
TRADED_S=$(echo "$QUOTE" | jq -r '.data.primaryData.lastTradeTimestamp // "—"')
LAST=$(echo "$LAST_S" | tr -d '$,')

PRICE_S=$(fmt_price "$LAST")
TEXT="SPCX ${PRICE_S}"
TIP="SpaceX (SPCX) · NASDAQ
Price: ${PRICE_S}
Day change: ${CHANGE_S}
As of: ${TRADED_S}"

json_out "$TEXT" "$TIP"
