-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

-- Hot-reload colorscheme when evo-theme swaps ~/.themes/current
local themes_dir = vim.fn.expand("~/.themes")

local function apply_colorscheme()
  vim.schedule(function()
    pcall(function()
      require("modular").reload_from_theme_file()
    end)
  end)
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

-- LazyVim enables spell + wrap for filetype "text" (.txt). Package lists are not prose.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("no_spell_text", { clear = true }),
  pattern = "text",
  callback = function()
    vim.opt_local.spell = false
    vim.opt_local.wrap = false
  end,
})
