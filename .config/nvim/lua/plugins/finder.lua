local function list_projects()
  local home = vim.fn.expand("~")
  local dirs = { home }
  for _, path in ipairs(vim.fn.glob(home .. "/projects/*", false, true)) do
    if vim.fn.isdirectory(path) == 1 then
      dirs[#dirs + 1] = path
    end
  end
  table.sort(dirs, function(a, b)
    if a == home then
      return true
    end
    if b == home then
      return false
    end
    return a:lower() < b:lower()
  end)
  return dirs
end

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

return {
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = { enabled = false },
      explorer = explorer,
      picker = {
        sources = {
          files = {
            hidden = true,
            ignored = true,
            exclude = { "node_modules" },
          },
          explorer = explorer,
          projects = {
            dev = {}, -- fd scan misses .git (ignored); use explicit list below
            projects = list_projects(),
            recent = true,
          },
        },
      },
    },
    init = function()
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        once = true,
        callback = function()
          vim.defer_fn(function()
            if vim.fn.argc() > 0 then
              return
            end
            local ok, Snacks = pcall(require, "snacks")
            if ok then
              Snacks.picker.projects()
            end
          end, 80)
        end,
      })
    end,
  },
}
