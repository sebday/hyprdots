return {
	{
		"Mofiqul/dracula.nvim",
		name = "dracula",
		priority = 1000,
		config = function()
			require("dracula").setup({
				colors = { bg = "#0a0e19" },
			})
		end,
	},
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "dracula",
		},
	},
}
