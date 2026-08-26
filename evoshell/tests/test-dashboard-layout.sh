#!/usr/bin/env bash
# Workspace 10 dashboard grid (hyprdots 2x2 slots).

set -euo pipefail

root="${EVOSHELL_ROOT:-$HOME/projects/evoshell}"

if ! command -v lua >/dev/null 2>&1; then
  echo "skip: lua not installed"
  exit 0
fi

EVOSHELL_ROOT="$root" lua - <<'LUA' || { echo "dashboard layout failed" >&2; exit 1; }
hl = {
  layout = {
    register = function(name, spec)
      _G._layout_name = name
      _G._layout_spec = spec
    end,
  },
}

local grid = dofile(os.getenv("EVOSHELL_ROOT") .. "/hypr/dashboard-layout.lua")
assert(grid.layout == "dashboard_2x2", "layout id")
assert(grid.layout_lua == "lua:dashboard_2x2", "layout lua id")
assert(_G._layout_spec and type(_G._layout_spec.recalculate) == "function", "layout recalculate registered")
LUA

echo "dashboard layout ok"
