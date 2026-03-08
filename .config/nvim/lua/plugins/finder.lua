return {
  {
    "folke/snacks.nvim",
    opts = {
      explorer = {
        hidden = true,
        ignored = true,
        git_status = false,
        layout = {
          preset = "sidebar",
          preview = false,
        },
      },
      picker = {
        sources = {
          files = {
            hidden = true,
            ignored = true,
          },
          explorer = {
            hidden = true,
            ignored = true,
            git_status = false,
          },
        },
      },
    },
  },
}
