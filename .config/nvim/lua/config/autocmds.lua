-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

-- Hot-reload colorscheme when ~/.themes/current symlink changes (themes-switch.sh)
local theme_file = vim.fn.expand("~/.themes/current/neovim.lua")
local themes_dir = vim.fn.expand("~/.themes")

local function apply_colorscheme()
  local f = io.open(theme_file, "r")
  if f then
    local content = f:read("*a")
    f:close()
    local name = content:match('colorscheme%s*=%s*"([^"]+)"')
    if name and name ~= "" then
      vim.schedule(function()
        pcall(vim.cmd.colorscheme, name)
      end)
    end
  end
end

local function start_watcher()
  local w = vim.uv.new_fs_event()
  if not w then return end
  w:start(themes_dir, {}, function(err)
    if err then
      w:stop()
      return
    end
    apply_colorscheme()
    w:stop()
    vim.defer_fn(start_watcher, 100)
  end)
end

if vim.fn.isdirectory(themes_dir) == 1 then
  start_watcher()
end

vim.api.nvim_create_autocmd("FocusGained", {
  group = vim.api.nvim_create_augroup("theme_reload", { clear = true }),
  callback = apply_colorscheme,
})
