return {
	{
		dir = "/home/seb/.config/nvim/lua/plugins/modular-loader",
		name = "modular-loader",
		priority = 1001,
		config = function(_, opts)
			require("modular").set_palette(opts.palette)
		end,
		opts = {
			palette = {
				base = "#2c2525",
				mantle = "#1e1a1a",
				crust = "#1e1a1a",
				surface0 = "#1e1a1a",
				surface1 = "#1e1a1a",
				surface2 = "#1e1a1a",
				text = "#e6d9db",
				subtext1 = "#e6d9db",
				subtext0 = "#e6d9db",
				overlay2 = "#e6d9db",
				overlay1 = "#e6d9db",
				overlay0 = "#e6d9db",
				rosewater = "#c3b7b8",
				flamingo = "#bebffd",
				pink = "#bebffd",
				mauve = "#f38d70",
				red = "#fd6883",
				maroon = "#fd6883",
				peach = "#f9cc6c",
				yellow = "#f9cc6c",
				green = "#adda78",
				teal = "#85dacc",
				sky = "#e6d9db",
				sapphire = "#9bf1e1",
				blue = "#f38d70",
				lavender = "#f8a788",
			},
		},
	},
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "modular",
		},
	},
}
