-- Only save persistence sessions for ~ and ~/projects/*.

local M = {}

local function normalize(path)
  return vim.fs.normalize(path)
end

function M.session_allowed(cwd)
  cwd = normalize(cwd or vim.fn.getcwd())
  local home = normalize(vim.fn.expand("~"))
  if cwd == home then
    return true
  end
  local prefix = home .. "/projects/"
  return cwd:sub(1, #prefix) == prefix
end

function M.sync_persistence()
  local ok, persistence = pcall(require, "persistence")
  if not ok then
    return
  end
  if M.session_allowed() then
    if not persistence.active() then
      persistence.start()
    end
  elseif persistence.active() then
    persistence.stop()
  end
end

function M.setup_autocmds()
  local group = vim.api.nvim_create_augroup("session_policy", { clear = true })
  vim.api.nvim_create_autocmd({ "DirChanged", "VimEnter" }, {
    group = group,
    callback = function()
      vim.schedule(M.sync_persistence)
    end,
  })
end

return M
