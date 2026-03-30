-- Neovim icon highlights (from colours.css, theme-specific)

local M = {}

M.setup = function()
  local icon_colors = {
    ["folder"] = "#6fb8e3",
    ["folder-config"] = "#6fb8e3",
    ["folder-git"] = "#6fa4c9",
    ["folder-home"] = "#d6e2ee",
    ["folder-downloads"] = "#6fa4c9",
    ["folder-documents"] = "#d6e2ee",
    ["folder-music"] = "#b1d8ee",
    ["folder-pictures"] = "#6fa4c9",
    ["folder-videos"] = "#6fa4c9",
    ["lua"] = "#6fb8e3",
    ["javascript"] = "#6fa4c9",
    ["typescript"] = "#6fb8e3",
    ["json"] = "#6fa4c9",
    ["markdown"] = "#d6e2ee",
    ["txt"] = "#d6e2ee",
    ["bash"] = "#6fa4c9",
    ["zsh"] = "#6fa4c9",
    ["python"] = "#5e95bc",
    ["rust"] = "#4d86b0",
    ["go"] = "#6fb8e3",
    ["c"] = "#8bc9eb",
    ["cpp"] = "#6fb8e3",
    ["css"] = "#b4e4f6",
    ["scss"] = "#8bc9eb",
    ["html"] = "#4d86b0",
    ["yaml"] = "#6fa4c9",
    ["toml"] = "#6fb8e3",
    ["conf"] = "#8bc9eb",
    ["mp3"] = "#8bc9eb",
    ["flac"] = "#5e95bc",
    ["jpg"] = "#6fa4c9",
    ["png"] = "#6fa4c9",
    ["gif"] = "#b1d8ee",
    ["pdf"] = "#4d86b0",
    ["zip"] = "#6fa4c9",
  }

  for name, color in pairs(icon_colors) do
    local hl_name = "MiniIcons" .. name:gsub("^%l", string.upper):gsub("-(%l)", string.upper)
    vim.api.nvim_set_hl(0, hl_name, { fg = color })
  end
end

return M
