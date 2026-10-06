-- Evoshell Hyprland integration entrypoint.

require("hypr.layers")
require("hypr.bindings")
local user_bindings = (os.getenv("HOME") or "") .. "/.config/hypr/bindings.lua"
local user_bindings_file = io.open(user_bindings, "r")
if user_bindings_file then
	user_bindings_file:close()
	dofile(user_bindings)
end
require("hypr.autostart")
require("hypr.dashboard-layout")
require("hypr.dashboard-top-layout")
require("hypr.qconsole")
require("hypr.menu-special")
require("hypr.float-workspace")
require("hypr.looks")

-- Calculator is a normal toplevel so it can be dragged. Title is set by
-- modules/calculator/Calculator.qml. center applies once, on map.
hl.window_rule({
	name = "evo-calculator",
	match = { title = "^Calculator$" },
	float = true,
	center = true,
})
