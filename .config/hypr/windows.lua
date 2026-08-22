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

local function window_size(win)
	if not win then
		return 0, 0
	end
	local w = win.width or (win.size and win.size.w) or 0
	local h = win.height or (win.size and win.size.h) or 0
	return w, h
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
end

hl.on("window.open", on_window_open)
