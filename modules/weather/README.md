# Omarchy weather plugin

Bar widget for current conditions, a 3-day forecast, and a small RainViewer pixel radar centred on your saved location.

Click the location name to search. The arrows under the radar step through the forecast one frame at a time. Middle-click the bar icon to refresh.

## Install

```bash
omarchy plugin add /path/to/omarchy-weather --enable
```

A git URL works the same way. Plugins run as unsandboxed code inside `omarchy-shell`. Review the files before enabling.

## Requirements

- `python3`, `curl`, `jq`, `bash`, and ImageMagick (`magick`) on PATH

Location is the same file stock weather uses: `omarchy weather location` / `~/.local/state/omarchy/settings/weather.json`.

## Settings

```bash
omarchy bar set evo.weather refreshMinutes 15 --json
```

| Key | Default | What it does |
|---|---|---|
| `refreshMinutes` | `15` | Background refresh for conditions and radar |
| `unit` | unset | `metric` or `imperial`; otherwise inferred from locale |

## IPC

```bash
omarchy-shell evo.weather toggle
omarchy-shell evo.weather refresh
omarchy-shell shell toggle evo.weather
```

| Call | Action |
|---|---|
| `open` / `show` | Open the panel |
| `close` / `hide` | Close the panel |
| `toggle` | Toggle the panel |
| `edit` | Open the panel and start editing the location |

## Removing

```bash
omarchy plugin remove evo.weather
```

That deletes the plugin directory. It does not delete:

- `~/.local/state/omarchy/settings/weather.json`
- `~/.cache/omarchy/bar/weather-radar.json`
- `~/.cache/omarchy/bar/weather-radar-play.json`
- `refreshMinutes` or `unit` on the bar entry in `~/.config/omarchy/shell.json`

Network: https://api.rainviewer.com, https://tilecache.rainviewer.com, https://api.open-meteo.com, https://geocoding-api.open-meteo.com, https://wttr.in.
