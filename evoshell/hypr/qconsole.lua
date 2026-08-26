-- Quake-style console: dimmed special workspace over the active monitor.

local dashboard = require("hypr.dashboard-lib")

local SPECIAL_WS = "special:qconsole"
local PINNED_DASHBOARD_WS = "10"
local SHARE = 0.50
local LAYOUT = "lua:dashboard_top"
local terminal = os.getenv("EVOSHELL_TERMINAL") or "ghostty"
local seed = "[workspace special:qconsole silent] " .. terminal

local active = false
local host_monitor = nil
local reflow_pending = false
local covering = nil
local open_generation = 0

hl.config({
	decoration = {
		dim_special = 0.6,
	},
	misc = {
		initial_workspace_tracking = 0,
	},
})

hl.window_rule({
	name = "qconsole-tile",
	match = { workspace = "special:qconsole" },
	float = false,
})

local function qconsole_monitor()
	if host_monitor and host_monitor.name then
		return host_monitor
	end
	return hl.get_active_monitor()
end

local function qconsole_windows()
	local wins = {}
	for _, win in ipairs(hl.get_windows()) do
		if win.workspace and win.workspace.name == SPECIAL_WS then
			table.insert(wins, win)
		end
	end
	return wins
end

local function focus_qconsole()
	local monitor = qconsole_monitor()
	if monitor then
		hl.dispatch(hl.dsp.focus({ monitor = monitor.name }))
	end
	hl.dispatch(hl.dsp.focus({ workspace = SPECIAL_WS }))
end

local function dedupe_qconsole_windows()
	local wins = qconsole_windows()
	if #wins <= 1 then
		return
	end
	for index = 2, #wins do
		hl.dispatch(hl.dsp.window.close({ window = wins[index] }))
	end
end

local function special_visible_on_active_monitor()
	local monitor = hl.get_active_monitor()
	if not monitor or not monitor.specialWorkspace then
		return false
	end
	return monitor.specialWorkspace.name == SPECIAL_WS
end

local function reflow_qconsole()
	if not active or not special_visible_on_active_monitor() then
		return
	end
	if reflow_pending then
		return
	end
	reflow_pending = true
	local generation = open_generation
	hl.timer(function()
		reflow_pending = false
		if not active or generation ~= open_generation or not special_visible_on_active_monitor() then
			return
		end
		focus_qconsole()
		hl.dispatch(hl.dsp.layout("name " .. LAYOUT))
	end, { timeout = 200, type = "oneshot" })
end

local function cover(bottom)
	if covering == bottom then
		return
	end
	covering = bottom

	hl.workspace_rule({
		workspace = SPECIAL_WS,
		gaps_in = 0,
		gaps_out = { top = 0, right = 0, bottom = bottom, left = 0 },
		no_border = true,
		layout = LAYOUT,
		on_created_empty = seed,
	})
end

local function fit()
	local monitor = qconsole_monitor()
	if not monitor or not monitor.scale or monitor.scale <= 0 then
		return
	end

	local reserved = monitor.reserved
	local usable = monitor.height / monitor.scale - reserved.top - reserved.bottom
	cover(math.max(0, math.floor(usable * (1 - SHARE))))
end

local function return_pinned_dashboards()
	dashboard.foreach_dashboard_window(function(win)
		if not dashboard.is_pinned_dashboard_window(win) then
			return
		end
		if not win.workspace or win.workspace.name ~= SPECIAL_WS then
			return
		end
		hl.dispatch(hl.dsp.window.move({
			workspace = PINNED_DASHBOARD_WS,
			window = win,
			follow = false,
		}))
	end)
end

local function attach_to_host_monitor()
	local monitor = qconsole_monitor()
	if not monitor then
		return
	end

	hl.dispatch(hl.dsp.focus({ monitor = monitor.name }))
	hl.dispatch(hl.dsp.focus({ workspace = SPECIAL_WS }))

	for _, win in ipairs(qconsole_windows()) do
		hl.dispatch(hl.dsp.window.move({ workspace = SPECIAL_WS, window = win, follow = false }))
	end
end

local function sync_active_monitor()
	if not active then
		return
	end
	fit()
	attach_to_host_monitor()
	return_pinned_dashboards()
	dedupe_qconsole_windows()
	reflow_qconsole()
end

local function on_open()
	local generation = open_generation
	hl.timer(function()
		if not active or generation ~= open_generation or not special_visible_on_active_monitor() then
			return
		end
		return_pinned_dashboards()
		attach_to_host_monitor()
		dedupe_qconsole_windows()
		reflow_qconsole()
	end, { timeout = 300, type = "oneshot" })
end

local function on_close()
	open_generation = open_generation + 1
	return_pinned_dashboards()
	active = false
	host_monitor = nil
end

local function toggle()
	host_monitor = hl.get_active_monitor()

	if special_visible_on_active_monitor() then
		on_close()
		hl.dispatch(hl.dsp.workspace.toggle_special("qconsole"))
		return
	end

	if active then
		sync_active_monitor()
		hl.dispatch(hl.dsp.workspace.toggle_special("qconsole"))
		return
	end

	hl.dispatch(hl.dsp.workspace.toggle_special("qconsole"))
end

cover(0)
fit()

hl.on("monitor.layout_changed", function()
	fit()
	if active then
		sync_active_monitor()
	end
end)
hl.on("monitor.focused", function(mon)
	host_monitor = mon
	fit()
	if active and special_visible_on_active_monitor() then
		reflow_qconsole()
	end
end)

hl.on("workspace.special_active", function(ws)
	if ws and ws.name == SPECIAL_WS then
		active = true
		open_generation = open_generation + 1
		if not host_monitor then
			host_monitor = hl.get_active_monitor()
		end
		on_open()
		return
	end

	if active then
		on_close()
		return
	end
	active = false
	host_monitor = nil
end)

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })

hl.animation({
	leaf = "specialWorkspaceIn",
	enabled = true,
	speed = 3,
	bezier = "easeOutQuint",
	style = "slide top",
})
hl.animation({
	leaf = "specialWorkspaceOut",
	enabled = true,
	speed = 2,
	bezier = "easeInOutCubic",
	style = "slide bottom",
})

return {
	special_workspace = SPECIAL_WS,
	layout = LAYOUT,
	toggle = toggle,
}
