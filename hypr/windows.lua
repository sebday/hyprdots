hl.window_rule({
	name = "dashboard-no-initial-focus",
	match = {
		class = "^(org%.quickshell)$",
		title = "^evo%.panels%.[^%.]+$",
	},
	no_initial_focus = true,
})

local function dashboard_to_ws10(win)
	local title = win and win.title or ""
	if win and win.class == "org.quickshell" and title:match("^evo%.panels%.") then
		hl.dispatch(hl.dsp.window.move({ workspace = "10", window = win, follow = false }))
	end
end

local function on_window_open(win)
	dashboard_to_ws10(win)
end

hl.on("window.open", on_window_open)
hl.on("window.title", dashboard_to_ws10)
