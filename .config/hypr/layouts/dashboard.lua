local last_active_slot = 1

local function place_overflows(ctx, area, targets)
	if #targets == 0 then
		return
	end
	if #targets == 1 then
		targets[1]:place(area)
		return
	end
	targets[1]:place(ctx:split(area, "top", 0.5))
	place_overflows(ctx, ctx:split(area, "bottom", 0.5), { table.unpack(targets, 2) })
end

hl.layout.register("dashboard_2x2", {
	recalculate = function(ctx)
		local slots = {}
		local overflow = {}
		local next_free = 1

		for _, target in ipairs(ctx.targets) do
			local title = target.window and target.window.title or ""
			local slot
			if title:match("^evo%.panels%.shopify") then
				slot = 3
			elseif title:match("^evo%.panels%.player$") then
				slot = 4
			else
				slot = next_free
				next_free = next_free + 1
			end
			if slot <= 4 then
				if slots[slot] then
					table.insert(overflow, target)
				else
					slots[slot] = target
				end
			else
				table.insert(overflow, target)
			end
		end

		for slot = 1, 4 do
			local target = slots[slot]
			if target and target.window and target.window.active then
				last_active_slot = slot
			end
		end

		local split_slot = last_active_slot

		for slot = 1, 4 do
			local target = slots[slot]
			if not target then
				goto continue
			end

			local cell = ctx:grid_cell(slot, 2, 2)
			if slot == split_slot and #overflow > 0 then
				target:place(ctx:split(cell, "left", 0.5))
				place_overflows(ctx, ctx:split(cell, "right", 0.5), overflow)
			else
				target:place(cell)
			end

			::continue::
		end

		if #overflow > 0 and not slots[split_slot] then
			place_overflows(ctx, ctx:grid_cell(split_slot, 2, 2), overflow)
		end
	end,
})

hl.workspace_rule({ workspace = "10", layout = "lua:dashboard_2x2" })
