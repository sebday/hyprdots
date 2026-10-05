-- Change the default Omarchy look'n'feel.

-- Force software cursors. Default is auto (2), which still uses hardware
-- planes. After overnight AMD modeset recovery those planes stay dead, so
-- the pointer is gone on TTY1 even though Hyprland still tracks it.
-- https://wiki.hypr.land/Configuring/Basics/Variables/#cursor
hl.config({
  cursor = {
    no_hardware_cursors = 1,
  },
})

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
-- hl.config({
--   general = {
--     -- No gaps between windows or borders.
--     gaps_in = 0,
--     gaps_out = 0,
--     border_size = 0,
--
--     -- Change to niri-like side-scrolling layout.
--     layout = "scrolling",
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
-- hl.config({
--   decoration = {
--     -- Use round window corners.
--     rounding = 8,
--
--     -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
--     dim_inactive = true,
--     dim_strength = 0.15,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     -- Avoid overly wide single-window layouts on wide screens.
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- hl.config({
--   scrolling = {
--     -- See only one column per screen instead of two.
--     column_width = 0.97,
--   },
-- })

-- Quake console (special:scratchpad) is boxed to twice its height when it
-- holds one window. Keep the half-height drop, but span the full monitor width.
-- qconsole.lua looks up hl.workspace_rule at call time, so later refits go
-- through this wrapper. The one-shot below replaces the boxed rule it already
-- wrote at startup; that cache will not rewrite until the geometry changes.
local SCRATCHPAD = "special:scratchpad"
local share = 0.5
local seed = "[workspace special:scratchpad silent] omarchy-agent"

local apply_workspace_rule = hl.workspace_rule

function hl.workspace_rule(rule)
  local gaps = rule and rule.gaps_out
  if rule and rule.workspace == SCRATCHPAD and type(gaps) == "table" then
    gaps.left = 0
    gaps.right = 0
  end
  return apply_workspace_rule(rule)
end

local function console_monitor()
  local ws = hl.get_workspace(SCRATCHPAD)
  local mon = ws and ws.visible and ws.monitor

  if mon and mon.scale and mon.scale > 0 then
    return mon
  end

  return hl.get_active_monitor()
end

local function full_width(monitor)
  if not monitor or not monitor.scale or monitor.scale <= 0 then
    return
  end

  local height = monitor.height
  if monitor.transform % 2 == 1 then
    height = monitor.width
  end

  local reserved = monitor.reserved
  height = height / monitor.scale - reserved.top - reserved.bottom

  local tall = math.floor(height * share)
  hl.workspace_rule({
    workspace = SCRATCHPAD,
    gaps_in = 0,
    gaps_out = { top = 0, right = 0, bottom = math.floor(height - tall), left = 0 },
    no_border = true,
    on_created_empty = seed,
  })
  hl.exec_scheduled_prop_refresh_immediately()
end

full_width(console_monitor())
