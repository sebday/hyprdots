#!/bin/bash
# Waybar: Derby weather — today and tomorrow (Open-Meteo, no API key).
#
# Environment:
#   WAYBAR_WEATHER_LAT / WAYBAR_WEATHER_LON — default Derby, UK

set -euo pipefail

LAT="${WAYBAR_WEATHER_LAT:-52.9219}"
LON="${WAYBAR_WEATHER_LON:--1.4746}"

json_out() {
    jq -cn --arg text "$1" --arg tooltip "$2" '{text: $text, tooltip: $tooltip}'
}

weather_icon() {
    case "$1" in
        0) printf '%s' '󰖙' ;;  # clear
        1) printf '%s' '󰖔' ;;  # mainly clear
        2 | 3) printf '%s' '󰖕' ;;  # partly cloudy
        45 | 48) printf '%s' '󰖑' ;;  # fog
        51 | 53 | 55 | 56 | 57) printf '%s' '󰖗' ;;  # drizzle
        61 | 63 | 65 | 66 | 67 | 80 | 81 | 82) printf '%s' '󰖖' ;;  # rain
        71 | 73 | 75 | 77 | 85 | 86) printf '%s' '󰖘' ;;  # snow
        95 | 96 | 99) printf '%s' '󰙾' ;;  # thunder
        *) printf '%s' '󰖐' ;;
    esac
}

weather_label() {
    case "$1" in
        0) printf '%s' 'Clear' ;;
        1) printf '%s' 'Mainly clear' ;;
        2) printf '%s' 'Partly cloudy' ;;
        3) printf '%s' 'Overcast' ;;
        45 | 48) printf '%s' 'Fog' ;;
        51 | 53 | 55) printf '%s' 'Drizzle' ;;
        56 | 57) printf '%s' 'Freezing drizzle' ;;
        61) printf '%s' 'Light rain' ;;
        63) printf '%s' 'Rain' ;;
        65) printf '%s' 'Heavy rain' ;;
        66 | 67) printf '%s' 'Freezing rain' ;;
        71) printf '%s' 'Light snow' ;;
        73) printf '%s' 'Snow' ;;
        75) printf '%s' 'Heavy snow' ;;
        77) printf '%s' 'Snow grains' ;;
        80 | 81 | 82) printf '%s' 'Showers' ;;
        85 | 86) printf '%s' 'Snow showers' ;;
        95) printf '%s' 'Thunderstorm' ;;
        96 | 99) printf '%s' 'Thunderstorm with hail' ;;
        *) printf '%s' 'Unknown' ;;
    esac
}

fmt_temp() {
    awk -v t="$1" 'BEGIN { printf "%.0f", t + 0 }'
}

API_URL="https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&timezone=Europe%2FLondon&forecast_days=2&current=temperature_2m,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min&hourly=temperature_2m,weather_code"

DATA=$(curl -sf --max-time 12 "$API_URL" 2>/dev/null) || DATA=""

if [[ -z "$DATA" ]] || ! echo "$DATA" | jq -e '.daily.time | length >= 2' >/dev/null 2>&1; then
    json_out "󰖐 —" "Derby weather unavailable"
    exit 0
fi

NOW_C=$(echo "$DATA" | jq -r '.current.temperature_2m // empty')
NOW_CODE=$(echo "$DATA" | jq -r '.current.weather_code // 0')

TODAY_CODE=$(echo "$DATA" | jq -r '.daily.weather_code[0]')
TODAY_MAX=$(echo "$DATA" | jq -r '.daily.temperature_2m_max[0]')
TODAY_MIN=$(echo "$DATA" | jq -r '.daily.temperature_2m_min[0]')
TODAY_DATE=$(echo "$DATA" | jq -r '.daily.time[0]')

TOM_CODE=$(echo "$DATA" | jq -r '.daily.weather_code[1]')
TOM_MAX=$(echo "$DATA" | jq -r '.daily.temperature_2m_max[1]')
TOM_MIN=$(echo "$DATA" | jq -r '.daily.temperature_2m_min[1]')
TOM_DATE=$(echo "$DATA" | jq -r '.daily.time[1]')

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

TEXT="${ICON_TODAY} $(fmt_temp "${NOW_C:-0}")° ${ICON_TOM} $(fmt_temp "$TOM_C")°"

TODAY_DOW=$(date -d "$TODAY_DATE" +%a 2>/dev/null || echo "today")
TOM_DOW=$(date -d "$TOM_DATE" +%a 2>/dev/null || echo "tomorrow")

TIP="Derby
${TODAY_DOW} (now): $(fmt_temp "${NOW_C:-0}")°C · $(weather_label "$NOW_CODE")
${TOM_DOW} (~${CURRENT_HOUR}:00): $(fmt_temp "$TOM_C")°C · $(weather_label "${TOM_HOURLY_CODE:-$TOM_CODE}")
Forecast range today: $(fmt_temp "$TODAY_MIN")–$(fmt_temp "$TODAY_MAX")°C
Forecast range tomorrow: $(fmt_temp "$TOM_MIN")–$(fmt_temp "$TOM_MAX")°C"

json_out "$TEXT" "$TIP"
