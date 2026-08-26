-- Full-bleed top band for special:qconsole (viewport height set via gaps_out).

hl.layout.register("dashboard_top", {
	recalculate = function(ctx)
		local targets = ctx.targets
		local count = #targets
		if count == 0 then
			return
		end

		if count == 1 then
			targets[1]:place(ctx.area)
			return
		end

		for index, target in ipairs(targets) do
			target:place(ctx:column(index, count))
		end
	end,
})

return {
	layout = "dashboard_top",
	layout_lua = "lua:dashboard_top",
}
