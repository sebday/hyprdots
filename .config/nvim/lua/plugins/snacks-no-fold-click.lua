return {
	"folke/snacks.nvim",
	opts = {
		statuscolumn = {
			right = { "git" }, -- drop fold chevrons from the gutter
		},
	},
	config = function()
		-- Snacks wraps the whole gutter in click_fold; disable click-to-toggle.
		require("snacks.statuscolumn").click_fold = function() end
	end,
}
