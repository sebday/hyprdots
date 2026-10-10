# Weather

Bar widget for current conditions, a 3-day forecast, and a small RainViewer pixel radar centred on your saved location.

Click the location name to search. The arrows under the radar step through the forecast one frame at a time. Middle-click the bar icon to refresh.

This module ships with evoshell. The plugin id is `evo.weather`.

## Requirements

- `python3`, `curl`, `jq`, `bash`, and ImageMagick (`magick`) on PATH

Location is `$EVOSHELL_STATE/weather/location.json` (`~/.local/state/evoshell/weather/location.json`).

## Settings

Widget options live on the `evo.weather` bar entry in `shell.json`.

| Key | Default | What it does |
|---|---|---|
| `refreshMinutes` | `15` | Background refresh for conditions and radar |
| `unit` | unset | `metric` or `imperial`; otherwise inferred from locale |

## IPC

```bash
evo ipc evo.weather toggle
evo ipc evo.weather refresh
evo ipc shell toggle evo.weather
```

| Call | Action |
|---|---|
| `open` / `show` | Open the panel |
| `close` / `hide` | Close the panel |
| `toggle` | Toggle the panel |
| `edit` | Open the panel and start editing the location |

Removing the module does not delete:

- `~/.local/state/evoshell/weather/location.json`
- `~/.cache/evoshell/weather-radar.json`
- `~/.cache/evoshell/weather-radar-play.json`
- `refreshMinutes` or `unit` on the bar entry in `shell.json`

Network: https://api.rainviewer.com, https://tilecache.rainviewer.com, https://api.open-meteo.com, https://geocoding-api.open-meteo.com, https://wttr.in.
