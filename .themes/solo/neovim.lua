return {
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      colors = {
        bg         = "#1a1721",
        dark_bg    = "#14111b",
        darker_bg  = "#0e0b15",
        lighter_bg = "#302a3a",

        fg         = "#d0cbd8",
        dark_fg    = "#928da0",
        light_fg   = "#bdb8cb",
        bright_fg  = "#e0dbea",
        muted      = "#4d465a",

        red        = "#e87b97",
        yellow     = "#d9b464",
        orange     = "#d4956e",
        green      = "#7cc9a0",
        cyan       = "#57bfb5",
        blue       = "#7ba5dd",
        purple     = "#c48ad5",
        brown      = "#8a7565",

        bright_red    = "#f09aae",
        bright_yellow = "#edc97a",
        bright_green  = "#96e0b8",
        bright_cyan   = "#6dd8ce",
        bright_blue   = "#96bef0",
        bright_purple = "#d8a0e8",

        accent               = "#e89bc1",
        cursor               = "#e0dbea",
        foreground           = "#d0cbd8",
        background           = "#1a1721",
        selection             = "#4d3a5a",
        selection_foreground = "#e0dbea",
        selection_background = "#4d3a5a",
      },
    },
    -- set up hot reload
    config = function(_, opts)
      require("aether").setup(opts)
      vim.cmd.colorscheme("aether")
      require("aether.hotreload").setup()
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "aether",
    },
  },
}
