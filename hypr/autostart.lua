-- Start evoshell on Hyprland launch.

local home = os.getenv("HOME") or ""
local evoshell_bin = os.getenv("EVOSHELL_BIN") or (home .. "/.local/lib/evoshell/bin")

hl.on("hyprland.start", function()
	hl.exec_cmd("systemctl --user start evoshell.service")
	hl.exec_cmd("bash -c 'sleep 5 && " .. evoshell_bin .. "/evo-panel-hypr restore-dashboards evo.panels.shopify evo.panels.player'")
end)
