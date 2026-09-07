local function projects_root()
	local home = vim.fn.expand("~")
	return home .. "/projects"
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
			opts.dashboard = opts.dashboard or {}
			opts.dashboard.enabled = false
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
			local group = vim.api.nvim_create_augroup("hyprdots_projects_picker", { clear = true })
			vim.api.nvim_create_autocmd("StdinReadPre", {
				group = group,
				callback = function()
					vim.g.hyprdots_started_with_stdin = true
				end,
			})
			vim.api.nvim_create_autocmd("VimEnter", {
				group = group,
				callback = function()
					if vim.fn.argc(-1) > 0 or vim.g.hyprdots_started_with_stdin then
						return
					end
					vim.schedule(function()
						Snacks.picker.projects()
					end)
				end,
			})
		end,
	},
}
