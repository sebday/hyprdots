#!/usr/bin/env bash
# qconsole special workspace and top-half dashboard layout.

set -euo pipefail

root="${EVOSHELL_ROOT:-$HOME/projects/evoshell}"

if ! command -v lua >/dev/null 2>&1; then
  echo "skip: lua not installed"
  exit 0
fi

EVOSHELL_ROOT="$root" lua - <<'LUA' || { echo "qconsole layout failed" >&2; exit 1; }
local rules = {}
local monitor = nil

hl = {
  layout = {
    register = function(name, spec)
      _G._layout_name = name
      _G._layout_spec = spec
    end,
  },
  workspace_rule = function(rule) table.insert(rules, rule) end,
  window_rule = function() end,
  on = function(event, callback) _G._handlers = _G._handlers or {}; _G._handlers[event] = callback end,
  config = function() end,
  curve = function() end,
  animation = function() end,
  get_active_monitor = function() return monitor end,
  get_windows = function() return {} end,
  exec_cmd = function() end,
  timer = function(fn) fn() end,
  dispatch = function() end,
}

package.path = os.getenv("EVOSHELL_ROOT") .. "/?.lua;" .. package.path

local top = dofile(os.getenv("EVOSHELL_ROOT") .. "/hypr/dashboard-top-layout.lua")
assert(top.layout == "dashboard_top", "top layout id")
assert(top.layout_lua == "lua:dashboard_top", "top layout lua id")
assert(_G._layout_spec and type(_G._layout_spec.recalculate) == "function", "top layout recalculate registered")

-- layout places every tiled target in the band (not dashboard-only)
_G._layout_spec.recalculate({
  area = { x = 0, y = 0, w = 2560, h = 720 },
  targets = {
    { place = function() _G._placed = true end, window = { title = "ghostty" } },
  },
})
assert(_G._placed == true, "layout places non-dashboard targets")

local qconsole = dofile(os.getenv("EVOSHELL_ROOT") .. "/hypr/qconsole.lua")
assert(qconsole.special_workspace == "special:qconsole", "qconsole workspace id")
assert(qconsole.layout == "lua:dashboard_top", "qconsole uses top layout")
assert(type(qconsole.toggle) == "function", "qconsole toggle export")

monitor = { height = 1440, scale = 1, reserved = { top = 40, bottom = 0, left = 0, right = 0 } }
_G._handlers["monitor.layout_changed"]()

local rule = rules[#rules]
assert(rule.workspace == "special:qconsole", "rule targets qconsole")
assert(rule.layout == "lua:dashboard_top", "qconsole keeps top layout")
assert(rule.gaps_in == 0, "qconsole has no inner gaps")
assert(rule.gaps_out.bottom == 700, "top-half gap on 1440p with bar")
LUA

echo "qconsole layout ok"
