local function preview_opts()
  local win = vim.api.nvim_get_current_win()
  local total = vim.api.nvim_win_get_width(win)
  local wininfo = vim.fn.getwininfo(win)[1]
  local textoff = (wininfo and wininfo.textoff) or 0
  return { max_width = math.max(1, total - textoff) }
end

local function in_render_mode(win)
  win = win or vim.api.nvim_get_current_win()
  local ok, state = pcall(vim.api.nvim_win_get_var, win, "md_render_state")
  return ok and type(state) == "table" and state.mode == "render"
end

local function open_markdown_preview()
  if vim.bo.filetype ~= "markdown" or vim.bo.buftype ~= "" or vim.b.md_preview_dismissed then
    return
  end
  if in_render_mode() then
    return
  end
  require("md-render.preview").toggle(preview_opts())
end

local function toggle_markdown_preview()
  local preview = require("md-render.preview")
  if in_render_mode() then
    vim.b.md_preview_dismissed = true
    preview.toggle()
    return
  end

  vim.b.md_preview_dismissed = nil
  preview.toggle(preview_opts())
end

local function ensure_source_for_edit()
  if in_render_mode() then
    require("md-render.preview").toggle()
  end
end

local function setup_render_edit_redirect(buf)
  local opts = { buffer = buf, silent = true }
  for _, key in ipairs({ "p", "P", "gp", "gP", "[p", "]p", "[P", "]P" }) do
    vim.keymap.set("n", key, function()
      ensure_source_for_edit()
      return key
    end, vim.tbl_extend("force", opts, { expr = true }))
  end
  for _, key in ipairs({ "<C-r>+", "<C-r>*", "<C-r>\"", "<C-r>0" }) do
    vim.keymap.set("i", key, function()
      ensure_source_for_edit()
      return key
    end, vim.tbl_extend("force", opts, { expr = true }))
  end
end

return {
  {
    "delphinus/md-render.nvim",
    version = "*",
    ft = "markdown",
    keys = {
      {
        "<leader>mp",
        toggle_markdown_preview,
        desc = "Markdown preview (toggle)",
        ft = "markdown",
      },
    },
    config = function()
      local default_paste = vim.paste
      ---@diagnostic disable-next-line: duplicate-set-field
      function vim.paste(lines, phase)
        if phase == 1 and in_render_mode() then
          ensure_source_for_edit()
        end
        return default_paste(lines, phase)
      end

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("md_render_edit_redirect", { clear = true }),
        pattern = "md-render",
        callback = function(ev)
          setup_render_edit_redirect(ev.buf)
        end,
      })

      vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
        group = vim.api.nvim_create_augroup("md_render_auto_preview", { clear = true }),
        pattern = "*.md",
        callback = function()
          vim.b.md_preview_dismissed = nil
          vim.schedule(open_markdown_preview)
        end,
      })

      vim.schedule(open_markdown_preview)
    end,
  },
}
