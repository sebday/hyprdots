#!/bin/bash
# Evo bar: Derby weather — today and tomorrow (Open-Meteo, no API key).
#
# Environment:
#   EVO_WEATHER_LAT / EVO_WEATHER_LON — default Derby, UK

set -euo pipefail

source "${HOME}/.local/bin/evo-bar-common.sh"
source "${HOME}/.local/bin/evo-weather-lib.sh"

if cached=$(evo_bar_cache_read "weather-bar" 1800 2>/dev/null); then
    printf '%s\n' "$cached"
    exit 0
fi

json_out() {
    jq -cn --arg text "$1" --arg tooltip "$2" '{text: $text, tooltip: $tooltip}'
}

DATA="$(weather_fetch_open_meteo)"

if [[ -z "$DATA" ]] || ! echo "$DATA" | jq -e '.daily.time | length >= 2' >/dev/null 2>&1; then
    json_out "󰖐 —" "${EVO_WEATHER_LOCATION} weather unavailable"
    exit 0
fi

NOW_C=$(echo "$DATA" | jq -r '.current.temperature_2m // empty')
NOW_CODE=$(echo "$DATA" | jq -r '.current.weather_code // 0')

TODAY_DATE=$(echo "$DATA" | jq -r '.daily.time[0]')
TOM_DATE=$(echo "$DATA" | jq -r '.daily.time[1]')
TODAY_MIN=$(echo "$DATA" | jq -r '.daily.temperature_2m_min[0]')
TODAY_MAX=$(echo "$DATA" | jq -r '.daily.temperature_2m_max[0]')
TOM_MIN=$(echo "$DATA" | jq -r '.daily.temperature_2m_min[1]')
TOM_MAX=$(echo "$DATA" | jq -r '.daily.temperature_2m_max[1]')
TOM_CODE=$(echo "$DATA" | jq -r '.daily.weather_code[1]')

CURRENT_TIME=$(echo "$DATA" | jq -r '.current.time // empty')
CURRENT_HOUR=$(date -d "${CURRENT_TIME:-now}" +%H 2>/dev/null || date +%H)
TOM_SLOT="${TOM_DATE}T${CURRENT_HOUR}:00"

read -r TOM_C TOM_HOURLY_CODE <<< "$(echo "$DATA" | jq -r --arg slot "$TOM_SLOT" '
    (.hourly.time | index($slot)) as $i |
    if $i == null then "", "" else
        (.hourly.temperature_2m[$i] | tostring) + " " + (.hourly.weather_code[$i] | tostring)
    end
')"

if [[ -z "$TOM_C" ]]; then
    TOM_C=$(awk -v max="$TOM_MAX" -v min="$TOM_MIN" 'BEGIN { printf "%.1f", (max + min) / 2 }')
    TOM_HOURLY_CODE="$TOM_CODE"
fi

ICON_TODAY=$(weather_icon "$NOW_CODE")
ICON_TOM=$(weather_icon "${TOM_HOURLY_CODE:-$TOM_CODE}")

TEXT="${ICON_TODAY} $(weather_fmt_temp "${NOW_C:-0}")° ${ICON_TOM} $(weather_fmt_temp "$TOM_C")°"

TODAY_DOW=$(date -d "$TODAY_DATE" +%a 2>/dev/null || echo "today")
TOM_DOW=$(date -d "$TOM_DATE" +%a 2>/dev/null || echo "tomorrow")

TIP="${EVO_WEATHER_LOCATION}
${TODAY_DOW} (now): $(weather_fmt_temp "${NOW_C:-0}")°C · $(weather_label "$NOW_CODE")
${TOM_DOW} (~${CURRENT_HOUR}:00): $(weather_fmt_temp "$TOM_C")°C · $(weather_label "${TOM_HOURLY_CODE:-$TOM_CODE}")
Forecast range today: $(weather_fmt_temp "$TODAY_MIN")–$(weather_fmt_temp "$TODAY_MAX")°C
Forecast range tomorrow: $(weather_fmt_temp "$TOM_MIN")–$(weather_fmt_temp "$TOM_MAX")°C"

output="$(json_out "$TEXT" "$TIP")"
printf '%s\n' "$output" | evo_bar_cache_write "weather-bar"
printf '%s\n' "$output"
