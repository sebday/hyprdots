-- Visual blank row between lualine winbar and buffer content.

local M = {}

local ns = vim.api.nvim_create_namespace("winbar_gap")
local busy = false

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
  winbar_gap = true,
  md_render = true,
  ["md-render"] = true,
}

local function skip_buf(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  return not vim.api.nvim_buf_is_valid(buf)
    or not vim.bo[buf].buflisted
    or skip_ft[vim.bo[buf].filetype]
end

local function blank_line()
  return string.rep(" ", math.max(vim.o.columns, 1))
end

local function clear_gap(buf)
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  end
end

local function apply_gap(buf)
  if skip_buf(buf) then
    clear_gap(buf)
    return
  end
  clear_gap(buf)
  vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
    virt_lines = { { { blank_line(), "Normal" } } },
    virt_lines_above = true,
  })
end

function M.refresh(buf)
  if busy then
    return
  end
  busy = true
  if buf then
    pcall(apply_gap, buf)
  else
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      pcall(apply_gap, b)
    end
  end
  busy = false
end

function M.setup()
  vim.api.nvim_create_autocmd({ "BufEnter", "FileType", "VimResized" }, {
    group = vim.api.nvim_create_augroup("winbar_gap", { clear = true }),
    callback = function(ev)
      vim.schedule(function()
        M.refresh(ev.buf)
      end)
    end,
  })

  vim.schedule(function()
    M.refresh()
  end)
end

return M
