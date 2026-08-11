#!/bin/bash
# Shared Open-Meteo weather helpers for evo bar and panel scripts.

EVO_WEATHER_LAT="${EVO_WEATHER_LAT:-${WAYBAR_WEATHER_LAT:-52.9219}}"
EVO_WEATHER_LON="${EVO_WEATHER_LON:-${WAYBAR_WEATHER_LON:--1.4746}}"
EVO_WEATHER_LOCATION="${EVO_WEATHER_LOCATION:-Derby}"

weather_icon() {
    case "$1" in
        0) printf '%s' '󰖙' ;;
        1) printf '%s' '󰖔' ;;
        2 | 3) printf '%s' '󰖕' ;;
        45 | 48) printf '%s' '󰖑' ;;
        51 | 53 | 55 | 56 | 57) printf '%s' '󰖗' ;;
        61 | 63 | 65 | 66 | 67 | 80 | 81 | 82) printf '%s' '󰖖' ;;
        71 | 73 | 75 | 77 | 85 | 86) printf '%s' '󰖘' ;;
        95 | 96 | 99) printf '%s' '󰙾' ;;
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

weather_fmt_temp() {
    awk -v t="$1" 'BEGIN { printf "%.0f", t + 0 }'
}

weather_fetch_open_meteo() {
    local lat="${1:-$EVO_WEATHER_LAT}"
    local lon="${2:-$EVO_WEATHER_LON}"
    local extra="${3:-}"
    local url="https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&timezone=Europe%2FLondon&forecast_days=2&current=temperature_2m,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min&hourly=temperature_2m,weather_code${extra}"
    curl -sf --max-time 12 "$url" 2>/dev/null || true
}
