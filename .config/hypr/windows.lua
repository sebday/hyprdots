hl.window_rule({
	name = "tag-floating-window-class",
	match = {
		class = "(TUI.float|floating-window)",
	},
	tag = "+floating-window",
})

hl.window_rule({
	name = "tag-floating-window-title-signin",
	match = { title = "^(.*Sign in.*)" },
	tag = "+floating-window",
})

hl.window_rule({
	name = "tag-floating-window-title-dialogs",
	match = {
		title = "^(Rename.*|Open.*Files?|Save.*Files?|Save.*As|.*wants to save.*|.*wants to open.*|Export Image.*|Select.*)",
	},
	tag = "+floating-window",
})

hl.window_rule({
	name = "tag-floating-window-thunar-progress",
	match = {
		class = "^Thunar$",
		title = "^File Operation Progress$",
	},
	tag = "+floating-window",
})

hl.window_rule({
	name = "tag-floating-window-satty",
	match = { initial_title = "^satty$" },
	tag = "+floating-window",
})

hl.window_rule({
	name = "floating-window-float",
	match = { tag = "floating-window" },
	float = true,
})

hl.window_rule({
	name = "floating-window-center",
	match = { tag = "floating-window" },
	center = true,
})

hl.window_rule({
	name = "floating-window-size",
	match = { tag = "floating-window" },
	size = { 1600, 900 },
})

hl.window_rule({
	name = "floating-window-monitor",
	match = { tag = "floating-window" },
})

hl.window_rule({
	name = "rename-window-size",
	match = {
		tag = "floating-window",
		title = "^Rename.*",
	},
	size = { 450, 150 },
	move = { "cursor_x-192", "cursor_y-75" },
})

hl.window_rule({
	name = "tag-main-window",
	match = { class = "^(TUI.main)$" },
	tag = "+main-window",
})

hl.window_rule({
	name = "main-window-float",
	match = { tag = "main-window" },
	float = true,
})

hl.window_rule({
	name = "main-window-center",
	match = { tag = "main-window" },
	center = true,
})

hl.window_rule({
	name = "main-window-size",
	match = { tag = "main-window" },
	size = { 1600, 900 },
})

hl.window_rule({
	name = "main-window-monitor",
	match = { tag = "main-window" },
})

hl.window_rule({
	name = "opacity-media-players",
	match = { class = "^(mpv|imv|imv-dir)$" },
	opacity = "1 override 1 override",
})

-- Dashboard windows on workspace 10 (HDMI-A-1).

local DASHBOARD_WS = "10"
local EVICT_WS = "5"
local DASHBOARD_LAYOUT = "lua:dashboard_2x2"

hl.window_rule({
	name = "dashboard-no-initial-focus",
	match = {
		class = "^(org%.quickshell)$",
		title = "^evo%.panels%.[^%.]+$",
	},
	no_initial_focus = true,
})

hl.window_rule({
	name = "dashboard-pinned-shopify-ws10",
	match = {
		class = "^(org%.quickshell)$",
		title = "^evo%.panels%.shopify",
	},
	workspace = DASHBOARD_WS,
})

hl.window_rule({
	name = "dashboard-pinned-player-ws10",
	match = {
		class = "^(org%.quickshell)$",
		title = "^evo%.panels%.player$",
	},
	workspace = DASHBOARD_WS,
})

local dashboard_reflow_pending = false

local function window_size(win)
	if not win then
		return 0, 0
	end
	local w = win.width or (win.size and win.size.w) or 0
	local h = win.height or (win.size and win.size.h) or 0
	return w, h
end

local function is_dashboard_window(win)
	if not win or win.class ~= "org.quickshell" then
		return false
	end
	local title = win.title or ""
	return title:match("^evo%.panels%.[^%.]+$") ~= nil
		or title:match("^evo%.panels%.shopify") ~= nil
end

local function reflow_dashboard_workspace()
	if dashboard_reflow_pending then
		return
	end
	dashboard_reflow_pending = true
	hl.timer(function()
		dashboard_reflow_pending = false
		hl.dispatch(hl.dsp.focus({ workspace = DASHBOARD_WS }))
		hl.dispatch(hl.dsp.layout("name " .. DASHBOARD_LAYOUT))
	end, { timeout = 200, type = "oneshot" })
end

local function evict_non_dashboard_from_ws10(win)
	if not win or not win.workspace or win.workspace.name ~= DASHBOARD_WS then
		return
	end
	if is_dashboard_window(win) then
		return
	end
	hl.dispatch(hl.dsp.window.move({ workspace = EVICT_WS, window = win, follow = false }))
end

local function route_dashboard_window(win)
	if not is_dashboard_window(win) then
		return
	end

	if win.workspace and win.workspace.name == DASHBOARD_WS then
		reflow_dashboard_workspace()
		return
	end

	hl.dispatch(hl.dsp.window.move({ workspace = DASHBOARD_WS, window = win, follow = false }))
	reflow_dashboard_workspace()
end

local function is_preserved_tui(win)
	local class = win and win.class or ""
	local title = win and win.title or ""
	if class:match("^TUI%.") then
		return true
	end
	if class == "com.mitchellh.ghostty" and title:match("^btop") then
		return true
	end
	return false
end

local function is_brave_window(win)
	if not win or not win.class then
		return false
	end
	local class = win.class
	return class == "brave-browser" or class:match("^brave%-.-__") ~= nil
end

local function is_brave_notification_popup(win)
	if is_preserved_tui(win) or not is_brave_window(win) then
		return false
	end
	local class = win.class
	local w, h = window_size(win)
	if w <= 0 or h <= 0 then
		return false
	end

	if class == "brave-browser" and w <= 900 and h <= 500 then
		return true
	end

	if class:match("^brave%-.-__") and w <= 700 and h <= 500 then
		return true
	end

	return false
end

local function close_brave_notification_popup(win)
	if is_preserved_tui(win) or not is_brave_notification_popup(win) then
		return
	end
	hl.timer(function()
		hl.dispatch(hl.dsp.window.close({ window = win }))
	end, { timeout = 1, type = "oneshot" })
end

local function brave_app_to_floating(win)
	if is_preserved_tui(win) then
		return
	end
	if is_brave_notification_popup(win) then
		close_brave_notification_popup(win)
		return
	end
	if not is_brave_window(win) or not win.class:match("^brave%-.-__") then
		return
	end
	hl.timer(function()
		hl.dispatch(hl.dsp.window.tag({ tag = "+floating-window", window = win }))
		hl.dispatch(hl.dsp.window.float({ action = "set", window = win }))
		hl.dispatch(hl.dsp.window.resize({ window = win, x = 1600, y = 900 }))
	end, { timeout = 1, type = "oneshot" })
end

local function on_window_open(win)
	brave_app_to_floating(win)
	evict_non_dashboard_from_ws10(win)
	route_dashboard_window(win)
end

hl.on("window.open", on_window_open)
hl.on("window.title", function(win)
	evict_non_dashboard_from_ws10(win)
	route_dashboard_window(win)
end)
