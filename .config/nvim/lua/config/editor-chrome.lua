-- Status stays in the tabline. Tabs + both gaps live in one 3-line split:
--   row 1 blank (under status)
--   row 2 buffer tabs
--   row 3 blank (under tabs)
-- Tabline/winbar are single-row UI; they cannot host these gaps.

local M = {}

local ns = vim.api.nvim_create_namespace("editor_chrome")
local chrome_buf, chrome_win
local tab_hits = {}
local busy = false
local HEIGHT = 3

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

local function listed_bufs()
  local bufs = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
      bufs[#bufs + 1] = buf
    end
  end
  return bufs
end

local function is_editor_win(win)
  if not vim.api.nvim_win_is_valid(win) or win == chrome_win then
    return false
  end
  local cfg = vim.api.nvim_win_get_config(win)
  if cfg.relative ~= "" then
    return false
  end
  local buf = vim.api.nvim_win_get_buf(win)
  return vim.bo[buf].buflisted and not skip_ft[vim.bo[buf].filetype]
end

local function hide_ui()
  return skip_ft[vim.bo.filetype] == true
end

local function blank()
  return string.rep(" ", math.max(vim.o.columns, 1))
end

local function hide_status()
  vim.o.laststatus = 0
  vim.o.ruler = false
  vim.o.winbar = ""
end

local function style_chrome(win)
  vim.wo[win].winbar = ""
  vim.wo[win].statusline = " "
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].statuscolumn = ""
  vim.wo[win].cursorline = false
  vim.wo[win].list = false
  vim.wo[win].wrap = false
  vim.wo[win].winfixheight = true
  vim.wo[win].fillchars = "eob: ,stl: ,stlnc: "
  vim.wo[win].winhighlight = "Normal:Normal,EndOfBuffer:Normal,WinBar:Normal,WinBarNC:Normal,StatusLine:Normal,StatusLineNC:Normal"
  hide_status()
  pcall(vim.api.nvim_win_set_height, win, HEIGHT)
end

local function close_chrome()
  if chrome_win and vim.api.nvim_win_is_valid(chrome_win) then
    pcall(vim.api.nvim_win_close, chrome_win, true)
  end
  chrome_win = nil
end

local function render_tabs()
  local cur = vim.api.nvim_get_current_buf()
  if chrome_buf and vim.api.nvim_buf_is_valid(chrome_buf) and cur == chrome_buf then
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if is_editor_win(win) then
        cur = vim.api.nvim_win_get_buf(win)
        break
      end
    end
  end

  local parts = {}
  tab_hits = {}
  local col = 0
  local bcol = 0
  for _, buf in ipairs(listed_bufs()) do
    local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
    if name == "" then
      name = "[No Name]"
    end
    if vim.bo[buf].modified then
      name = name .. " ●"
    end
    local label = " " .. name .. " "
    local width = vim.fn.strdisplaywidth(label)
    local nbytes = #label
    tab_hits[#tab_hits + 1] = {
      buf = buf,
      start = col,
      stop = col + width,
      bstart = bcol,
      bstop = bcol + nbytes,
      active = buf == cur,
    }
    parts[#parts + 1] = label
    col = col + width
    bcol = bcol + nbytes
  end

  local tabs = table.concat(parts)
  local width = math.max(vim.o.columns, 1)
  if vim.fn.strdisplaywidth(tabs) < width then
    tabs = tabs .. string.rep(" ", width - vim.fn.strdisplaywidth(tabs))
  end

  vim.bo[chrome_buf].modifiable = true
  vim.api.nvim_buf_set_lines(chrome_buf, 0, -1, false, { blank(), tabs, blank() })
  vim.api.nvim_buf_clear_namespace(chrome_buf, ns, 0, -1)
  for _, hit in ipairs(tab_hits) do
    pcall(vim.api.nvim_buf_set_extmark, chrome_buf, ns, 1, hit.bstart, {
      end_col = hit.bstop,
      hl_group = hit.active and "Visual" or "Comment",
    })
  end
  vim.bo[chrome_buf].modifiable = false
end

local function ensure_chrome()
  hide_status()
  if hide_ui() then
    close_chrome()
    return
  end

  if not chrome_buf or not vim.api.nvim_buf_is_valid(chrome_buf) then
    chrome_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[chrome_buf].buftype = "nofile"
    vim.bo[chrome_buf].bufhidden = "hide"
    vim.bo[chrome_buf].swapfile = false
    vim.bo[chrome_buf].buflisted = false
    vim.bo[chrome_buf].filetype = "editor_chrome"
  end

  if not chrome_win or not vim.api.nvim_win_is_valid(chrome_win) then
    chrome_win = vim.api.nvim_open_win(chrome_buf, false, {
      split = "above",
      win = -1,
      height = HEIGHT,
      noautocmd = true,
    })
  end

  style_chrome(chrome_win)
  render_tabs()

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_editor_win(win) then
      vim.wo[win].winbar = ""
    end
  end
end

local function editor_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_editor_win(win) then
      return win
    end
  end
end

local function bounce_focus()
  local win = editor_win()
  if win then
    pcall(vim.api.nvim_set_current_win, win)
  end
end

local function click_tab(mouse)
  if not chrome_win or mouse.winid ~= chrome_win then
    return false
  end
  -- wincol is 1-based screen column; hits are 0-based display widths.
  -- Accept any of the 3 chrome rows so a slightly high/low click still works.
  local col = math.max((mouse.wincol or 1) - 1, 0)
  local win = editor_win()
  for _, hit in ipairs(tab_hits) do
    if col >= hit.start and col < hit.stop then
      if win then
        pcall(vim.api.nvim_win_set_buf, win, hit.buf)
        pcall(vim.api.nvim_set_current_win, win)
      else
        pcall(vim.cmd.buffer, hit.buf)
      end
      vim.schedule(M.refresh)
      return true
    end
  end
  bounce_focus()
  return true
end

function M.refresh()
  if busy then
    return
  end
  busy = true
  local ok, err = pcall(function()
    hide_status()
    ensure_chrome()
    if vim.api.nvim_get_current_win() == chrome_win then
      bounce_focus()
    end
  end)
  busy = false
  if not ok then
    vim.schedule(function()
      vim.notify("editor-chrome: " .. tostring(err), vim.log.levels.ERROR)
    end)
  end
end

function M.hook_lualine()
  local ll = require("lualine")
  if ll._editor_chrome_patched then
    return
  end
  ll._editor_chrome_patched = true
  local refresh = ll.refresh
  ll.refresh = function(...)
    refresh(...)
    hide_status()
    if chrome_win and vim.api.nvim_win_is_valid(chrome_win) then
      style_chrome(chrome_win)
    end
  end
end

function M.setup()
  vim.o.mouse = "a"

  -- LeftMouse runs before mouse position is updated (wincol often 0).
  -- LeftRelease has the real coordinates.
  vim.keymap.set({ "n", "v", "i" }, "<LeftRelease>", function()
    click_tab(vim.fn.getmousepos())
  end, { silent = true, desc = "Select chrome buffer tab" })

  vim.api.nvim_create_autocmd("OptionSet", {
    group = vim.api.nvim_create_augroup("editor_chrome_status", { clear = true }),
    pattern = "laststatus",
    callback = function()
      if vim.o.laststatus ~= 0 then
        vim.o.laststatus = 0
      end
    end,
  })

  vim.api.nvim_create_autocmd({
    "BufAdd",
    "BufDelete",
    "BufEnter",
    "BufModifiedSet",
    "VimResized",
    "TabEnter",
  }, {
    group = vim.api.nvim_create_augroup("editor_chrome", { clear = true }),
    callback = function(ev)
      if chrome_buf and ev.buf == chrome_buf then
        return
      end
      vim.schedule(M.refresh)
    end,
  })

  vim.api.nvim_create_autocmd("WinEnter", {
    group = vim.api.nvim_create_augroup("editor_chrome_focus", { clear = true }),
    callback = function()
      if chrome_win and vim.api.nvim_get_current_win() == chrome_win then
        vim.defer_fn(function()
          if chrome_win and vim.api.nvim_get_current_win() == chrome_win then
            bounce_focus()
          end
        end, 120)
      end
    end,
  })

  vim.schedule(M.refresh)
end

return M
