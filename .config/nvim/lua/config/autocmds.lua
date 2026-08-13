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

-- Reopen files from leftover swap (unclean close) or the last persistence session.
local function pid_alive(pid)
  if type(pid) ~= "number" or pid <= 0 then
    return false
  end
  return vim.uv.fs_stat("/proc/" .. tostring(pid)) ~= nil
end

local function path_from_swap(swp)
  local name = vim.fn.fnamemodify(swp, ":t"):gsub("%.sw%a+$", "")
  if name:find("%%", 1, true) then
    return "/" .. name:gsub("%%", "/")
  end
  local info = vim.fn.swapinfo(swp)
  if info and info.fname and info.fname ~= "" then
    return vim.fn.expand(info.fname)
  end
end

local function restore_from_swap()
  local swaps = vim.fn.glob(vim.fn.stdpath("state") .. "/swap/*", false, true)
  local files, seen = {}, {}
  for _, swp in ipairs(swaps) do
    local info = vim.fn.swapinfo(swp)
    if info and not pid_alive(info.pid) then
      local path = path_from_swap(swp)
      if path and vim.fn.filereadable(path) == 1 and not seen[path] then
        seen[path] = true
        files[#files + 1] = path
      end
      pcall(vim.fn.delete, swp)
    end
  end
  if #files == 0 then
    return false
  end
  table.sort(files)
  for i, path in ipairs(files) do
    local escaped = vim.fn.fnameescape(path)
    if i == 1 then
      vim.cmd.edit(escaped)
    else
      vim.cmd.badd(escaped)
    end
  end
  return true
end

local function restore_previous_files()
  if vim.fn.argc() > 0 then
    return
  end
  if restore_from_swap() then
    return
  end
  pcall(function()
    require("persistence").load()
  end)
end

vim.schedule(restore_previous_files)
