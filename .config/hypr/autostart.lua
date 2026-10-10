local home = os.getenv("HOME") or ""
local evoshell_bin = os.getenv("EVOSHELL_BIN") or (home .. "/.local/lib/evoshell/bin")

hl.on("hyprland.start", function()
	hl.exec_cmd("systemctl --user start evoshell.service")
	hl.exec_cmd("bash -c 'sleep 5 && " .. evoshell_bin .. "/evo-panel-hypr restore-dashboards'")
	hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
	hl.exec_cmd("gsettings set org.gnome.desktop.wm.keybindings switch-input-source \"['XF86Keyboard']\"")
	hl.exec_cmd("xrandr --output DP-1 --primary")
	hl.dispatch(hl.dsp.exec_cmd("obsidian", { workspace = "1 silent" }))
	hl.dispatch(hl.dsp.exec_cmd(evoshell_bin .. "/evo-brave-launch", { workspace = "2" }))
	hl.exec_cmd("bash -c 'sleep 20 && insync start --qt-qpa-platform=xcb'")
end)
