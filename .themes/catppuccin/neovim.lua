return {
	{
		"catppuccin/nvim",
		name = "catppuccin",
		priority = 1000,
		opts = {
			integrations = {
				snacks = { enabled = true },
			},
			custom_highlights = function(colors)
				return {
					StatusLine = { fg = colors.text, bg = colors.base },
					StatusLineNC = { fg = colors.surface1, bg = colors.base },
					NormalSB = { fg = colors.text, bg = colors.base },
					SnacksNormalNC = { fg = colors.text, bg = colors.base },
					SnacksPicker = { fg = colors.text, bg = colors.base },
					SnacksPickerInput = { fg = colors.text, bg = colors.base },
					SnacksPickerInputBorder = { fg = colors.surface1, bg = colors.base },
				}
			end,
		},
	},
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "catppuccin",
		},
	},
}
