# Cursor

EvoShell bar widget for Cursor usage and billing cycle: included Cursor models, other API models, tokens by model, and the days left in the cycle.

## Install

EvoShell discovers `modules/cursor/manifest.json` at startup. Add `{ "id": "evo.cursor" }` to a bar layout section and run `evo system restart`.

## Requirements

- `curl`, `jq` and `/usr/bin/python3`
- Cursor CLI or the Cursor IDE signed in on this machine

## Auth

Uses the session Cursor already stores on this machine:

1. Cursor CLI: `~/.config/cursor/auth.json`
2. Cursor IDE: `~/.config/Cursor/User/globalStorage/state.vscdb`

The session cookie goes to `curl` on stdin, never in argv.

## How it collects

`bin/cursor-usage-collect [--force] [--limits-only]` fetches usage and prints one agent usage record (schema 1, the shape Omarchy's agents panel used, plus billing cycle fields). It caches for 5 minutes in `$EVOSHELL_CACHE/cursor/record.json`.

`bin/cursor-usage [--force]` runs the collector, publishes the record to `$EVOSHELL_STATE/cursor/usage.json`, and prints the panel payload. The panel calls it on load, when opened, every `refreshIntervalSec`, and with `--force` on right-click or IPC `refresh`. No systemd timer is needed.

## Bar

| Click | Action |
|---|---|
| Left | Toggle the panel |
| Middle | Open the Cursor spending dashboard |
| Right | Refresh now |

## Settings

| Key | Default | What it does |
|---|---|---|
| `refreshIntervalSec` | `300` | Refresh interval (30–3600) |

## IPC

```bash
evo ipc evo.cursor toggle
evo ipc evo.cursor refresh
```

## Data

- `$EVOSHELL_CACHE/cursor/record.json`
- `$EVOSHELL_STATE/cursor/usage.json`

Network: https://cursor.com/api/usage-summary and https://cursor.com/api/dashboard/get-aggregated-usage-events.
