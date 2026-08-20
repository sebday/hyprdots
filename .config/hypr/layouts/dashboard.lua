hl.layout.register("dashboard_2x2", {
	recalculate = function(ctx)
		local slots = {}
		local next_free = 1

		for _, target in ipairs(ctx.targets) do
			local title = target.window and target.window.title or ""
			local slot
			if title:match("^evo.panel.shopify") then
				slot = 3
			elseif title == "evo.panel.player" then
				slot = 4
			else
				slot = next_free
				next_free = next_free + 1
			end
			if slot <= 4 then
				slots[slot] = target
			end
		end

		for slot = 1, 4 do
			local target = slots[slot]
			if target then
				target:place(ctx:grid_cell(slot, 2))
			end
		end
	end,
})

hl.workspace_rule({ workspace = "10", layout = "lua:dashboard_2x2" })
