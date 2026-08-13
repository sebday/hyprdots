return {
  {
    "nvim-mini/mini.icons",
    opts = function(_, opts)
      -- Load theme-specific icon colors
      local theme_icons_file = vim.fn.expand("~/.config/nvim/lua/theme-icons.lua")
      if vim.fn.filereadable(theme_icons_file) == 1 then
        local ok, theme_icons = pcall(require, "theme-icons")
        if ok and theme_icons.setup then
          theme_icons.setup()
        end
      end
    end,
  },
}
