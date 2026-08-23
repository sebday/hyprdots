local home = os.getenv("HOME") or ""
local evoshell_bin = os.getenv("EVOSHELL_BIN") or (home .. "/.local/lib/evoshell/bin")

hl.on("hyprland.start", function()
	hl.exec_cmd("gsettings set org.gnome.desktop.wm.keybindings switch-input-source \"['XF86Keyboard']\"")
	hl.exec_cmd("xrandr --output DP-1 --primary")
	hl.dispatch(hl.dsp.exec_cmd("brave", { workspace = "2" }))
	hl.dispatch(hl.dsp.exec_cmd("obsidian", { workspace = "6 silent" }))
	hl.exec_cmd("bash -c 'sleep 5 && " .. evoshell_bin .. "/evo-panel-hypr restore-dashboards evo.panels.shopify evo.panels.player'")
	hl.exec_cmd("bash -c 'sleep 20 && insync start --qt-qpa-platform=xcb'")
end)
