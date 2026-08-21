-- Project picker confirm: cd, restore session, refresh chrome.

local M = {}

local function refresh_chrome()
  pcall(function()
    require("config.editor-chrome").refresh()
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
    end
    vim.defer_fn(refresh_chrome, 80)
  end, 100)
end

function M.setup_autocmds()
  vim.api.nvim_create_autocmd("User", {
    pattern = "PersistenceLoadPost",
    callback = function()
      vim.defer_fn(refresh_chrome, 80)
    end,
  })
end

return M
