-- Explorer + files picker filtering:
-- ~            → git-tracked only (minus icon packs) + open buffers
-- ~/projects/* → respect .gitignore

local M = {}

local home = vim.fn.expand("~")
local projects = home .. "/projects"
local icons_prefix = home .. "/.local/share/icons/"
local cached_include
local cached_allowed

local skip_ft = {
  snacks_dashboard = true,
  snacks_picker_input = true,
  snacks_picker_list = true,
  snacks_picker_preview = true,
  snacks_layout_box = true,
  dashboard = true,
  alpha = true,
  ministarter = true,
  lazy = true,
  mason = true,
  editor_chrome = true,
}

local function normalize(path)
  return vim.fs.normalize(path)
end

function M.is_home(cwd)
  return normalize(cwd or vim.fn.getcwd()) == normalize(home)
end

function M.is_project(cwd)
  cwd = normalize(cwd or vim.fn.getcwd())
  local root = normalize(projects)
  return cwd == root or cwd:find(root .. "/", 1, true) == 1
end

local function skip_git_path(path)
  return path == ".local/share/icons" or path:find("^%.local/share/icons/") ~= nil
end

local function open_buffer_paths()
  local paths = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted and not skip_ft[vim.bo[buf].filetype] then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" then
        paths[#paths + 1] = normalize(name)
      end
    end
  end
  return paths
end

local function add_path(seen, include, path)
  path = normalize(path)
  if path ~= normalize(home) and path:find(normalize(home) .. "/", 1, true) ~= 1 then
    return
  end
  while path and path ~= "" do
    if not seen[path] then
      seen[path] = true
      include[#include + 1] = path
    end
    if path == normalize(home) then
      break
    end
    path = vim.fs.dirname(path)
  end
end

function M.include_patterns()
  if cached_include then
    return cached_include
  end

  local seen = {}
  local include = {}
  local root = normalize(home)

  for _, rel in ipairs(vim.fn.systemlist({ "git", "-C", home, "ls-files", "--cached" })) do
    if rel ~= "" and not skip_git_path(rel) then
      add_path(seen, include, root .. "/" .. rel)
    end
  end

  for _, path in ipairs(open_buffer_paths()) do
    if path:find(icons_prefix, 1, true) ~= 1 then
      add_path(seen, include, path)
    end
  end

  cached_include = include
  return include
end

function M.allowed_set()
  if cached_allowed then
    return cached_allowed
  end
  cached_allowed = {}
  for _, path in ipairs(M.include_patterns()) do
    cached_allowed[path] = true
  end
  return cached_allowed
end

function M.allows_path(path)
  return M.allowed_set()[normalize(path)] == true
end

function M.invalidate()
  cached_include = nil
  cached_allowed = nil
end

function M.explorer_opts(cwd)
  cwd = cwd or vim.fn.getcwd()
  if M.is_home(cwd) then
    return {
      include = M.include_patterns(),
      exclude = { "**" },
      hidden = true,
      ignored = true,
    }
  end
  if M.is_project(cwd) then
    return {
      hidden = true,
      ignored = false,
      git_status = true,
    }
  end
  return {}
end

function M.files_opts(cwd)
  cwd = cwd or vim.fn.getcwd()
  if M.is_home(cwd) then
    return {
      finder = "git_files",
      cmd_args = { "--", ":!.local/share/icons", ":!.local/share/icons/**" },
      filter = {
        filter = function(item)
          local path = require("snacks.picker.util").path(item)
          return path ~= nil and M.allows_path(path)
        end,
      },
    }
  end
  if M.is_project(cwd) then
    return {
      hidden = true,
      ignored = false,
    }
  end
  return {
    hidden = true,
    ignored = false,
  }
end

function M.refresh_explorer(cwd)
  cwd = cwd or vim.fn.getcwd()
  local opts = M.explorer_opts(cwd)
  if vim.tbl_isempty(opts) then
    return
  end
  if M.is_home(cwd) then
    M.invalidate()
    opts = M.explorer_opts(cwd)
  end
  local ok_picker, picker = pcall(require, "snacks.picker")
  if not ok_picker then
    return
  end
  local ok_actions, Actions = pcall(require, "snacks.explorer.actions")
  local target = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
  for _, p in ipairs(picker.get({ source = "explorer" })) do
    if normalize(p:cwd()) == normalize(cwd) then
      for k, v in pairs(opts) do
        p.opts[k] = v
      end
      if ok_actions and target ~= "" then
        Actions.update(p, { target = target })
      else
        p:find()
      end
    end
  end
end

return M
