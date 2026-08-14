local mfact_wide_by_workspace = {}

local function toggle_workspace_split()
	local ws = hl.get_active_workspace()
	if not ws then
		return
	end

	local wide = not mfact_wide_by_workspace[ws.id]
	mfact_wide_by_workspace[ws.id] = wide

	if ws.tiled_layout == "master" then
		local mfact = wide and 0.66 or 0.5
		hl.dispatch(hl.dsp.layout("mfact exact " .. mfact))
	elseif ws.tiled_layout == "dwindle" then
		local ratio = wide and 1.32 or 1.0
		hl.dispatch(hl.dsp.layout("splitratio " .. ratio .. " exact"))
	end
end

hl.bind("SUPER + S", toggle_workspace_split, { description = "Toggle split ratio 50/66" })
