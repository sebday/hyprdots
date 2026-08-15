return {
  {
    "folke/which-key.nvim",
    opts = {
      -- Don't auto-open the keymap panel in visual mode (session restore can land there).
      triggers = {
        { "<auto>", mode = "nsoc" },
      },
    },
  },
}
