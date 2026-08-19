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
		class = "(insync|brave-calendar.*|brave-mail.*|brave-weather|brave-cursor|brave-github|steam|TUI.float|floating-window)",
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

hl.workspace_rule({
	workspace = "10",
	monitor = "HDMI-A-1",
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

local function dashboard_to_ws10(win)
	local title = win and win.title or ""
	if win and win.class == "org.quickshell"
		and (title:match("^evo%.shopify") or title == "evo.player") then
		hl.dispatch(hl.dsp.window.move({ workspace = "10", window = win }))
	end
end

hl.on("window.open", dashboard_to_ws10)
hl.on("window.title", dashboard_to_ws10)
