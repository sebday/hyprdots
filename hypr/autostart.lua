-- Start evoshell on Hyprland launch.

hl.on("hyprland.start", function()
	hl.exec_cmd("systemctl --user start evoshell.service")
end)
