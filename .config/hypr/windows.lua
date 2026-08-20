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
	name = "tag-floating-window-class",
	match = {
		class = "(TUI.float|floating-window)",
	},
	tag = "+floating-window",
})

hl.window_rule({
	name = "tag-floating-window-title-signin",
	match = { title = "^(.*Sign in.*|Untitled.*)" },
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
	name = "satty",
	match = { initial_title = "^satty$" },
	float = true,
	center = true,
	monitor = "DP-1",
	size = { 1280, 720 },
})

hl.window_rule({
	name = "opacity-media-players",
	match = { class = "^(mpv|imv|imv-dir)$" },
	opacity = "1 override 1 override",
})

hl.window_rule({
	name = "dashboard-no-initial-focus-shopify",
	match = {
		class = "^(org%.quickshell)$",
		title = "^evo%.shopify",
	},
	no_initial_focus = true,
})

hl.window_rule({
	name = "dashboard-no-initial-focus-player",
	match = {
		class = "^(org%.quickshell)$",
		title = "^evo%.player$",
	},
	no_initial_focus = true,
})

local FLOAT_WIDTH = 1600
local FLOAT_HEIGHT = 900

local function layout_floating_window(win)
	if not win then
		return
	end

	hl.timer(function()
		hl.dispatch(hl.dsp.window.tag({ tag = "+floating-window", window = win }))
		hl.dispatch(hl.dsp.window.float({ action = "set", window = win }))
		hl.dispatch(hl.dsp.window.resize({ window = win, x = FLOAT_WIDTH, y = FLOAT_HEIGHT }))
		local mon = win.monitor
		if mon then
			local at_x = mon.x + math.floor((mon.width - FLOAT_WIDTH) / 2)
			local at_y = mon.y + math.floor((mon.height - FLOAT_HEIGHT) / 2)
			hl.dispatch(hl.dsp.window.move({ window = win, x = at_x, y = at_y, relative = false }))
		end
	end, { timeout = 1, type = "oneshot" })
end

local function brave_app_to_floating(win)
	if not win or not win.class then
		return
	end
	if win.class:match("^brave%-.-__") then
		layout_floating_window(win)
	end
end

local function dashboard_to_ws10(win)
	local title = win and win.title or ""
	if win and win.class == "org.quickshell" and (title:match("^evo%.shopify") or title == "evo.player") then
		hl.dispatch(hl.dsp.window.move({ workspace = "10", window = win, follow = false }))
	end
end

local function on_window_open(win)
	dashboard_to_ws10(win)
	brave_app_to_floating(win)
end

hl.on("window.open", on_window_open)
hl.on("window.title", dashboard_to_ws10)
