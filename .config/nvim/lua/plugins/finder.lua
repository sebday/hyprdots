local function projects_root()
	local home = vim.fn.expand("~")
	for _, name in ipairs({ "Projects", "projects" }) do
		local path = home .. "/" .. name
		if vim.fn.isdirectory(path) == 1 then
			return path
		end
	end
	return home .. "/Projects"
end

local function list_projects()
	local root = projects_root()
	local dirs = {}
	for _, path in ipairs(vim.fn.glob(root .. "/*", false, true)) do
		if vim.fn.isdirectory(path) == 1 then
			dirs[#dirs + 1] = path
		end
	end
	table.sort(dirs, function(a, b)
		return a:lower() < b:lower()
	end)
	return dirs
end

return {
	{
		"folke/snacks.nvim",
		opts = function(_, opts)
			opts.picker = opts.picker or {}
			opts.picker.sources = opts.picker.sources or {}
			opts.picker.sources.projects = vim.tbl_deep_extend("force", opts.picker.sources.projects or {}, {
				dev = {},
				projects = list_projects(),
				recent = false,
				matcher = {
					frecency = false,
					sort_empty = true,
					cwd_bonus = false,
				},
				confirm = function(picker, item)
					if not item or not item.file then
						return
					end
					picker:close()
					vim.fn.chdir(item.file)
				end,
			})
		end,
		init = function()
			vim.api.nvim_create_autocmd("User", {
				pattern = "VeryLazy",
				once = true,
				callback = function()
					vim.defer_fn(function()
						if vim.fn.argc() > 0 then
							return
						end
						local ok, Snacks = pcall(require, "snacks")
						if ok then
							Snacks.picker.projects()
						end
					end, 80)
				end,
			})
		end,
	},
}
