local home = os.getenv("HOME") or ""
local evoshell_bin = os.getenv("EVOSHELL_BIN") or (home .. "/.local/lib/evoshell/bin")

hl.on("hyprland.start", function()
	hl.exec_cmd("systemctl --user set-environment XCURSOR_THEME=Vimix-cursors XCURSOR_SIZE=24")
	hl.exec_cmd("systemctl --user start evoshell.service")
	hl.exec_cmd("bash -c 'sleep 5 && " .. evoshell_bin .. "/evo-panel-hypr restore-dashboards'")
	hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
	hl.exec_cmd("gsettings set org.gnome.desktop.wm.keybindings switch-input-source \"['XF86Keyboard']\"")
	-- Xwayland is not up yet at hyprland.start. Retry until DP-1 is the X primary,
	-- so games pick its 3840x2160 mode instead of HDMI-A-1's 2560x1440.
	hl.exec_cmd("bash -c 'for i in $(seq 1 15); do xrandr --output DP-1 --primary 2>/dev/null && xrandr --query | grep -q \"DP-1 connected primary\" && exit 0; sleep 1; done'")
	hl.dispatch(hl.dsp.exec_cmd(evoshell_bin .. "/evo-brave-launch", { workspace = "2" }))
	hl.dispatch(hl.dsp.exec_cmd("ghostty -e btop", { workspace = "10 silent" }))
	hl.exec_cmd("bash -c 'sleep 20 && insync start --qt-qpa-platform=xcb'")
end)
