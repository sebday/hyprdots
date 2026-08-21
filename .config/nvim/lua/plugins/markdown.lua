local function preview_is_open()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local config = vim.api.nvim_win_get_config(win)
    if config.relative ~= "" then
      local title = config.title
      if title and title[1] and title[1][1]:find("Markdown Preview", 1, true) then
        return true
      end
    end
  end
  return false
end

local function open_markdown_preview()
  if vim.bo.filetype ~= "markdown" or vim.bo.buftype ~= "" then
    return
  end

  local preview = require("md-render.preview")
  if preview_is_open() then
    preview.show()
  end
  preview.show()
end

return {
  {
    "delphinus/md-render.nvim",
    version = "*",
    ft = "markdown",
    keys = {
      {
        "<leader>mp",
        "<Plug>(md-render-preview)",
        desc = "Markdown preview (toggle)",
        ft = "markdown",
      },
    },
    config = function()
      vim.api.nvim_create_autocmd("BufEnter", {
        group = vim.api.nvim_create_augroup("md_render_auto_preview", { clear = true }),
        pattern = "*.md",
        callback = function()
          vim.schedule(open_markdown_preview)
        end,
      })

      vim.schedule(open_markdown_preview)
    end,
  },
}
