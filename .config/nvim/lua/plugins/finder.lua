return {
  {
    "folke/snacks.nvim",
    opts = {
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
          },
        },
      },
    },
    init = function()
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        callback = function()
          vim.defer_fn(function()
            if vim.fn.argc() == 1 and vim.fn.isdirectory(vim.fn.argv(0)) == 1 then
              return
            end
            local ok, Snacks = pcall(require, "snacks")
            if not ok then
              return
            end
            if #Snacks.picker.get({ source = "explorer" }) > 0 then
              return
            end
            local prev = vim.api.nvim_get_current_win()
            pcall(Snacks.explorer.open)
            vim.schedule(function()
              if vim.api.nvim_win_is_valid(prev) then
                pcall(vim.api.nvim_set_current_win, prev)
              end
            end)
          end, 80)
        end,
      })
    end,
  },
}
