return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.winbar = vim.deepcopy(opts.sections)
      opts.inactive_winbar = vim.deepcopy(opts.inactive_sections or {})
      opts.sections = {}
      opts.inactive_sections = {}

      opts.options = opts.options or {}
      opts.options.globalstatus = false

      local disabled = opts.options.disabled_filetypes or {}
      if type(disabled.statusline) == "table" then
        disabled.winbar = vim.list_extend(vim.deepcopy(disabled.winbar or {}), disabled.statusline)
      end
      opts.options.disabled_filetypes = disabled

      vim.o.laststatus = 0
      return opts
    end,
    config = function(_, opts)
      require("lualine").setup(opts)
      require("config.winbar-gap").setup()
    end,
  },
}
