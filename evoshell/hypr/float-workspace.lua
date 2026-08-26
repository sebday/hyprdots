-- Per-workspace float mode: float existing windows and auto-float new ones.
-- First-time floats use half work-area width × height (quarter area), centered.
-- Float position/size is snapshotted when leaving float mode and restored on re-enter.

local float_workspaces = {}
local saved_geometry = {}

local SIZE_TOLERANCE = 8

local function window_stable_id(win)
	return win and win.stable_id
end

local function sizes_close(a, b)
	return math.abs(a - b) <= SIZE_TOLERANCE
end

local function float_mode_enabled(ws)
	return ws and float_workspaces[ws.id] == true
end

local function workspace_geometry(ws_id)
	local ws_geom = saved_geometry[ws_id]
	if not ws_geom then
		ws_geom = {}
		saved_geometry[ws_id] = ws_geom
	end
	return ws_geom
end

local function snapshot_float_geometry(ws, win)
	if not ws or not win or not win.floating then
		return
	end
	local sid = window_stable_id(win)
	if not sid or not win.at or not win.size then
		return
	end
	workspace_geometry(ws.id)[sid] = {
		x = win.at.x,
		y = win.at.y,
		w = win.size.x,
		h = win.size.y,
	}
end

local function get_saved_geometry(ws, win)
	if not ws or not win then
		return nil
	end
	local sid = window_stable_id(win)
	if not sid then
		return nil
	end
	local ws_geom = saved_geometry[ws.id]
	if not ws_geom then
		return nil
	end
	return ws_geom[sid]
end

local function clear_saved_geometry(stable_id)
	if not stable_id then
		return
	end
	for _, ws_geom in pairs(saved_geometry) do
		ws_geom[stable_id] = nil
	end
end

local function work_area_for_window(win)
	local mon = win and win.monitor
	if not mon then
		mon = hl.get_active_monitor()
	end
	if not mon then
		return nil
	end

	local reserved = mon.reserved or {}
	local top = reserved.top or 0
	local right = reserved.right or 0
	local bottom = reserved.bottom or 0
	local left = reserved.left or 0

	return {
		width = mon.width - left - right,
		height = mon.height - top - bottom,
	}
end

local function apply_saved_float_geometry(win, geom)
	if not win or not geom then
		return
	end
	hl.dispatch(hl.dsp.window.resize({
		x = geom.w,
		y = geom.h,
		relative = false,
		window = win,
	}))
	hl.dispatch(hl.dsp.window.move({
		x = geom.x,
		y = geom.y,
		relative = false,
		window = win,
	}))
end

local function apply_quarter_float_geometry(win)
	local area = work_area_for_window(win)
	if not area then
		return
	end

	local w = math.max(1, math.floor(area.width / 2))
	local h = math.max(1, math.floor(area.height / 2))

	hl.dispatch(hl.dsp.window.resize({
		x = w,
		y = h,
		relative = false,
		window = win,
	}))
	hl.dispatch(hl.dsp.window.center({ window = win }))
end

local function hyprland_restored_float_geometry(win, tiled_w, tiled_h)
	if not win.size or not tiled_w or not tiled_h then
		return false
	end
	-- Hyprland restored a size different from the pre-float tiled rect.
	return not sizes_close(win.size.x, tiled_w) or not sizes_close(win.size.y, tiled_h)
end

local function set_window_float(win, floating, ws)
	if not win then
		return
	end

	if not floating then
		hl.timer(function()
			hl.dispatch(hl.dsp.window.float({
				action = "unset",
				window = win,
			}))
		end, { timeout = 1, type = "oneshot" })
		return
	end

	if win.floating then
		return
	end

	local workspace = ws or win.workspace
	local tiled_w, tiled_h
	if win.size then
		tiled_w = win.size.x
		tiled_h = win.size.y
	end

	hl.timer(function()
		hl.dispatch(hl.dsp.window.float({
			action = "set",
			window = win,
		}))
		hl.timer(function()
			if not win.mapped then
				return
			end
			local saved = get_saved_geometry(workspace, win)
			if saved then
				apply_saved_float_geometry(win, saved)
				return
			end
			if hyprland_restored_float_geometry(win, tiled_w, tiled_h) then
				return
			end
			apply_quarter_float_geometry(win)
		end, { timeout = 1, type = "oneshot" })
	end, { timeout = 1, type = "oneshot" })
end

local function for_each_workspace_window(ws, fn)
	if not ws or not ws.get_windows then
		return
	end
	for _, win in ipairs(ws:get_windows()) do
		fn(win)
	end
end

local function maybe_float_window(win)
	if not win then
		return
	end
	local ws = win.workspace
	if float_mode_enabled(ws) then
		set_window_float(win, true, ws)
	end
end

local function toggle_float_mode()
	local ws = hl.get_active_workspace()
	if not ws then
		return
	end
	if float_mode_enabled(ws) then
		float_workspaces[ws.id] = nil
		for_each_workspace_window(ws, function(win)
			snapshot_float_geometry(ws, win)
			set_window_float(win, false, ws)
		end)
	else
		float_workspaces[ws.id] = true
		for_each_workspace_window(ws, function(win)
			set_window_float(win, true, ws)
		end)
	end
end

local function on_move_to_workspace(win, ws)
	if not win or not ws then
		return
	end
	if float_mode_enabled(ws) then
		set_window_float(win, true, ws)
	end
end

hl.on("window.open", maybe_float_window)
hl.on("window.move_to_workspace", on_move_to_workspace)
hl.on("window.destroy", function(win)
	clear_saved_geometry(window_stable_id(win))
end)

return {
	toggle = toggle_float_mode,
}
