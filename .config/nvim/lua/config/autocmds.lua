-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

-- Hot-reload colorscheme when evo-theme swaps ~/.themes/current
local themes_dir = vim.fn.expand("~/.themes")
local reload_timer = nil

local function apply_colorscheme()
  vim.schedule(function()
    if reload_timer then
      pcall(vim.fn.timer_stop, reload_timer)
      reload_timer = nil
    end
    reload_timer = vim.fn.timer_start(250, function()
      reload_timer = nil
      vim.schedule(function()
        pcall(function()
          require("modular").reload_all()
        end)
      end)
    end)
  end)
end

local function start_watcher()
  local w = vim.uv.new_fs_event()
  if not w then
    return
  end
  w:start(themes_dir, { recurse = true }, function(err)
    if err then
      return
    end
    apply_colorscheme()
  end)
end

if vim.fn.isdirectory(themes_dir) == 1 then
  start_watcher()
end

vim.api.nvim_create_autocmd("FocusGained", {
  group = vim.api.nvim_create_augroup("theme_reload", { clear = true }),
  callback = function()
    pcall(function()
      require("modular").reload_if_changed()
      package.loaded["theme-icons"] = nil
      pcall(function()
        require("theme-icons").setup()
      end)
    end)
  end,
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
