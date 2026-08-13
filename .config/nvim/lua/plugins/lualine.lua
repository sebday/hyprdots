return {
  {
    "akinsho/bufferline.nvim",
    enabled = false,
  },
  {
    "nvim-lualine/lualine.nvim",
    keys = {
      { "<S-h>", "<cmd>bprevious<cr>", desc = "Prev Buffer" },
      { "<S-l>", "<cmd>bnext<cr>", desc = "Next Buffer" },
      { "[b", "<cmd>bprevious<cr>", desc = "Prev Buffer" },
      { "]b", "<cmd>bnext<cr>", desc = "Next Buffer" },
    },
    opts = function(_, opts)
      opts.tabline = opts.sections
      opts.sections = {}
      opts.inactive_sections = {}
      opts.winbar = {}
      opts.inactive_winbar = {}
      opts.options = opts.options or {}
      opts.options.always_show_tabline = true
      opts.options.disabled_filetypes = opts.options.disabled_filetypes or {}
      local hidden = vim.deepcopy(opts.options.disabled_filetypes.statusline or {})
      table.insert(hidden, "editor_chrome")
      opts.options.disabled_filetypes.statusline = hidden
      opts.options.disabled_filetypes.winbar = vim.deepcopy(hidden)
      opts.options.disabled_filetypes.tabline = vim.deepcopy(hidden)

      vim.o.laststatus = 0
      vim.o.showtabline = 2
      vim.o.winbar = ""

      return opts
    end,
    config = function(_, opts)
      require("lualine").setup(opts)
      vim.o.laststatus = 0
      vim.o.winbar = ""
      local chrome = require("config.editor-chrome")
      chrome.setup()
      chrome.hook_lualine()
    end,
  },
}
