#!/bin/bash
# Weather popup details — Derby (Open-Meteo, no API key).
#
# Environment:
#   EVO_WEATHER_LAT / EVO_WEATHER_LON — default Derby, UK

set -euo pipefail

source "${HOME}/.local/bin/evo-bar-common.sh"
source "${HOME}/.local/bin/evo-weather-lib.sh"

if cached=$(evo_bar_cache_read "weather" 600 2>/dev/null); then
    printf '%s\n' "$cached"
    exit 0
fi

LAT="$EVO_WEATHER_LAT"
LON="$EVO_WEATHER_LON"
LOCATION="$EVO_WEATHER_LOCATION"
MET_OFFICE_URL="https://weather.metoffice.gov.uk/forecast/gcqvn6pq4"

error_out() {
    jq -cn --arg location "$LOCATION" --arg error "$1" --arg url "$MET_OFFICE_URL" \
        '{ok:false, location:$location, error:$error, metOfficeUrl:$url, sunrise:"", sunset:"", current:null, daily:[], hourly:[]}'
}

API_URL="https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&timezone=Europe%2FLondon&forecast_days=2&current=temperature_2m,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset&hourly=temperature_2m,weather_code"

DATA=$(curl -sf --max-time 12 "$API_URL" 2>/dev/null) || DATA=""

if [[ -z "$DATA" ]] || ! echo "$DATA" | jq -e '.daily.time | length >= 2' >/dev/null 2>&1; then
    error_out "Weather unavailable"
    exit 0
fi

output="$(echo "$DATA" | jq -c \
    --arg location "$LOCATION" \
    --arg url "$MET_OFFICE_URL" '
def icon($c):
  if $c == 0 then "󰖙"
  elif $c == 1 then "󰖔"
  elif ($c == 2 or $c == 3) then "󰖕"
  elif ($c == 45 or $c == 48) then "󰖑"
  elif ($c == 51 or $c == 53 or $c == 55 or $c == 56 or $c == 57) then "󰖗"
  elif ($c == 61 or $c == 63 or $c == 65 or $c == 66 or $c == 67 or $c == 80 or $c == 81 or $c == 82) then "󰖖"
  elif ($c == 71 or $c == 73 or $c == 75 or $c == 77 or $c == 85 or $c == 86) then "󰖘"
  elif ($c == 95 or $c == 96 or $c == 99) then "󰙾"
  else "󰖐" end;

def wlabel($c):
  if $c == 0 then "Clear"
  elif $c == 1 then "Mainly clear"
  elif $c == 2 then "Partly cloudy"
  elif $c == 3 then "Overcast"
  elif ($c == 45 or $c == 48) then "Fog"
  elif ($c == 51 or $c == 53 or $c == 55) then "Drizzle"
  elif ($c == 56 or $c == 57) then "Freezing drizzle"
  elif $c == 61 then "Light rain"
  elif $c == 63 then "Rain"
  elif $c == 65 then "Heavy rain"
  elif ($c == 66 or $c == 67) then "Freezing rain"
  elif $c == 71 then "Light snow"
  elif $c == 73 then "Snow"
  elif $c == 75 then "Heavy snow"
  elif $c == 77 then "Snow grains"
  elif ($c == 80 or $c == 81 or $c == 82) then "Showers"
  elif ($c == 85 or $c == 86) then "Snow showers"
  elif $c == 95 then "Thunderstorm"
  elif ($c == 96 or $c == 99) then "Thunderstorm with hail"
  else "Unknown" end;

def temp($t): ($t // 0 | round);

def hour_label($iso):
  ($iso | split("T")[1] // "00:00")[0:5];

def clock($iso):
  if ($iso // "") == "" then ""
  else ($iso | split("T")[1] // "")[0:5]
  end;

def dow($date):
  ($date + "T12:00:00Z" | fromdateiso8601 | strftime("%a"));

(.daily.time[0]) as $today |
{
  ok: true,
  location: $location,
  error: "",
  metOfficeUrl: $url,
  sunrise: clock(.daily.sunrise[0]),
  sunset: clock(.daily.sunset[0]),
  current: (
    (.current.weather_code // 0) as $code |
    {
      temp: temp(.current.temperature_2m),
      code: $code,
      label: wlabel($code),
      icon: icon($code),
      time: (.current.time // "")
    }
  ),
  daily: [
    range(0; ([.daily.time | length, 2] | min)) as $i |
    (.daily.weather_code[$i] // 0) as $code |
    {
      date: .daily.time[$i],
      dow: dow(.daily.time[$i]),
      min: temp(.daily.temperature_2m_min[$i]),
      max: temp(.daily.temperature_2m_max[$i]),
      code: $code,
      label: wlabel($code),
      icon: icon($code)
    }
  ],
  hourly: [
    range(0; .hourly.time | length) as $i |
    select((.hourly.time[$i] | split("T")[0]) == $today) |
    (.hourly.weather_code[$i] // 0) as $code |
    {
      time: hour_label(.hourly.time[$i]),
      iso: .hourly.time[$i],
      temp: temp(.hourly.temperature_2m[$i]),
      code: $code,
      label: wlabel($code),
      icon: icon($code)
    }
  ]
}
')"

printf '%s\n' "$output" | evo_bar_cache_write "weather"
printf '%s\n' "$output"
