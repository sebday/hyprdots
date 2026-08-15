-- Save persistence sessions only for ~ and ~/projects/*. Restore via <leader>fp projects picker.
return {
  {
    "folke/persistence.nvim",
    init = function()
      local policy = require("config.session-restore")
      policy.setup_autocmds()
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        once = true,
        callback = function()
          policy.sync_persistence()
        end,
      })
    end,
  },
}
