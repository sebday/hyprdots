-- System menu backdrop: empty special workspace on the active monitor (Hyprland dim_special).

local SPECIAL_WS = "special:evomenu"

hl.workspace_rule({
	workspace = SPECIAL_WS,
	gaps_in = 0,
	gaps_out = { top = 0, right = 0, bottom = 0, left = 0 },
	no_border = true,
})

return {
	special_workspace = SPECIAL_WS,
}
