-- Modular: self-contained Neovim colorscheme, palette from colors.toml
local M = {}

local uv = vim.uv or vim.loop
local THEME_FILE = "~/.themes/current/neovim.lua"

M._palette = nil
M._last_mtime = nil

local function theme_path()
  return vim.fn.expand(THEME_FILE)
end

local function theme_mtime()
  local stat = uv.fs_stat(theme_path())
  if not stat or not stat.mtime then
    return nil
  end
  return stat.mtime.sec or stat.mtime
end

function M.set_palette(palette)
  M._palette = palette
end

function M.get_palette()
  return M._palette or M._default_palette()
end

function M._load_palette_from_theme_file()
  local load_fn = loadfile(theme_path())
  if not load_fn then
    return nil
  end
  local ok, data = pcall(load_fn)
  if not ok or not data then
    return nil
  end
  return data.palette or (data[1] and data[1].opts and data[1].opts.palette)
end

function M.reload_from_theme_file()
  local palette = M._load_palette_from_theme_file()
  if palette then
    M.set_palette(palette)
    pcall(vim.cmd.colorscheme, "modular")
  end
end

function M.reload_if_changed()
  local mtime = theme_mtime()
  if not mtime then
    return
  end
  if M._last_mtime and mtime > M._last_mtime then
    M.reload_from_theme_file()
  end
  M._last_mtime = mtime
end

function M.set_baseline_mtime()
  local mtime = theme_mtime()
  if mtime then
    M._last_mtime = mtime
  end
end

function M._default_palette()
  -- Fallback if no palette injected (e.g. before theme switch)
  return {
    base = "#1e1e2e",
    mantle = "#181825",
    crust = "#11111b",
    surface0 = "#313244",
    surface1 = "#45475a",
    surface2 = "#585b70",
    text = "#cdd6f4",
    subtext1 = "#bac2de",
    subtext0 = "#a6adc8",
    overlay2 = "#9399b2",
    overlay1 = "#7f849c",
    overlay0 = "#6c7086",
    rosewater = "#f5e0dc",
    flamingo = "#f2cdcd",
    pink = "#f5c2e7",
    mauve = "#cba6f7",
    red = "#f38ba8",
    maroon = "#eba0ac",
    peach = "#fab387",
    yellow = "#f9e2af",
    green = "#a6e3a1",
    teal = "#94e2d5",
    sky = "#89dceb",
    sapphire = "#74c7ec",
    blue = "#89b4fa",
    lavender = "#b4befe",
  }
end

return M
