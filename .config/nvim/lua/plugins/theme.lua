-- Load plugin specs directly from ~/.themes/current/neovim.lua (symlink swaps on theme change)
local theme_file = vim.fn.expand("~/.themes/current/neovim.lua")
local theme_spec = loadfile(theme_file)
if theme_spec then
  return theme_spec()
end
