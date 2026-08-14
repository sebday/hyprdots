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

return {
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = { enabled = false },
      explorer = {
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
      },
      picker = {
        sources = {
          files = {
            hidden = true,
            ignored = true,
            exclude = { "node_modules" },
          },
          explorer = {
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
            config = function(opts)
              local home = require("config.explorer-home")
              if home.is_home(vim.fn.getcwd()) then
                opts = vim.tbl_deep_extend("force", opts, home.explorer_opts())
              end
              return require("snacks.picker.source.explorer").setup(opts)
            end,
          },
          projects = {
            dev = {}, -- fd scan misses .git (ignored); use explicit list below
            projects = list_projects(),
            recent = true,
          },
        },
      },
    },
    init = function()
      local explorer_home = require("config.explorer-home")

      local skip = {
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

      local function has_file_buffer()
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted and not skip[vim.bo[buf].filetype] then
            if vim.api.nvim_buf_get_name(buf) ~= "" then
              return true
            end
          end
        end
        return false
      end

      local opening = false
      local session_loading = false

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
        local ok, Snacks = pcall(require, "snacks")
        if not ok then
          return false
        end
        return #Snacks.picker.get({ source = "explorer" }) > 0 or has_explorer_win()
      end

      local function open_explorer()
        if opening or explorer_open() or not has_file_buffer() then
          return
        end
        local ok, Snacks = pcall(require, "snacks")
        if not ok then
          return
        end
        opening = true
        local prev = vim.api.nvim_get_current_win()
        pcall(Snacks.explorer.open, explorer_home.explorer_opts())
        vim.schedule(function()
          opening = false
          if vim.api.nvim_win_is_valid(prev) then
            pcall(vim.api.nvim_set_current_win, prev)
          end
          vim.defer_fn(function()
            pcall(require("config.editor-chrome").refresh)
          end, 50)
        end)
      end

      vim.api.nvim_create_autocmd("User", {
        pattern = "PersistenceLoadPre",
        callback = function()
          session_loading = true
        end,
      })

      vim.api.nvim_create_autocmd("User", {
        pattern = "PersistenceLoadPost",
        callback = function()
          vim.defer_fn(function()
            session_loading = false
            local mode = vim.api.nvim_get_mode().mode
            if mode == "v" or mode == "V" or mode == "\22" then
              vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
            end
            if explorer_open() then
              if explorer_home.is_home(vim.fn.getcwd()) then
                explorer_home.refresh_explorer()
              end
              pcall(require("config.editor-chrome").refresh)
            else
              open_explorer()
            end
          end, 80)
        end,
      })

      vim.api.nvim_create_autocmd("BufReadPost", {
        callback = function(ev)
          if session_loading then
            return
          end
          if skip[vim.bo[ev.buf].filetype] or vim.api.nvim_buf_get_name(ev.buf) == "" then
            return
          end
          vim.defer_fn(open_explorer, 50)
        end,
      })

      vim.api.nvim_create_autocmd({ "BufEnter", "BufDelete" }, {
        callback = function()
          if explorer_home.is_home(vim.fn.getcwd()) then
            vim.defer_fn(explorer_home.refresh_explorer, 50)
          end
        end,
      })

      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        once = true,
        callback = function()
          vim.defer_fn(function()
            if vim.fn.argc() > 0 then
              if vim.fn.isdirectory(vim.fn.argv(0)) ~= 1 then
                open_explorer()
              end
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
