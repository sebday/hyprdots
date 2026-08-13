-- Load theme from ~/.themes/current/neovim.lua (atomic swap on theme change)
local load_fn = loadfile(vim.fn.expand("~/.themes/current/neovim.lua"))
if load_fn then
  local data = load_fn()
  if data and data.palette then
    require("modular").set_palette(data.palette)
  end
  if data and data.spec then
    return data.spec
  end
end

return {
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "modular" },
  },
}
