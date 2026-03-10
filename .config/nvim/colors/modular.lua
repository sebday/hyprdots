-- Modular colorscheme entry point (runs on :colorscheme modular)
local modular = require("modular")
local highlights = require("modular.highlights")

highlights.apply_all(modular.get_palette())
modular.set_baseline_mtime()

vim.api.nvim_create_autocmd("FocusGained", {
  group = vim.api.nvim_create_augroup("ModularThemeReload", { clear = true }),
  callback = function()
    pcall(modular.reload_if_changed)
  end,
})
