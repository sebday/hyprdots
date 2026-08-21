-- Project picker confirm: cd, restore session, then open explorer.

local M = {}

local explorer = {
  hidden = true,
  ignored = true,
  git_status = false,
  layout = {
    preset = "sidebar",
    preview = false,
    layout = {
      width = 30,
      min_width = 30,
    },
  },
}

local function has_explorer_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
    if ft:find("snacks_picker", 1, true) or ft == "snacks_layout_box" then
      return true
    end
  end
  return false
end

local function explorer_open()
  if has_explorer_win() then
    return true
  end
  local ok, Snacks = pcall(require, "snacks")
  if not ok then
    return false
  end
  return #Snacks.picker.get({ source = "explorer" }) > 0
end

function M.open_explorer()
  if explorer_open() then
    return
  end
  pcall(function()
    require("snacks").explorer.open(explorer)
  end)
end

function M.load(picker, item)
  if not item or not item.file then
    return
  end
  picker:close()

  local dir = item.file
  local session_loaded = false

  vim.api.nvim_create_autocmd("User", {
    pattern = "PersistenceLoadPost",
    once = true,
    callback = function()
      session_loaded = true
    end,
  })

  vim.fn.chdir(dir)
  pcall(require("config.session-restore").sync_persistence)

  local ok, dash = pcall(require, "snacks.dashboard")
  if ok then
    local session = dash.sections.session()
    if session and session.action then
      vim.cmd(session.action:sub(2))
    end
  end

  vim.defer_fn(function()
    if not session_loaded then
      pcall(function()
        require("snacks").picker.files()
      end)
      vim.defer_fn(M.open_explorer, 80)
    end
  end, 100)
end

function M.setup_autocmds()
  vim.api.nvim_create_autocmd("User", {
    pattern = "PersistenceLoadPost",
    callback = function()
      vim.defer_fn(M.open_explorer, 80)
    end,
  })
end

return M
