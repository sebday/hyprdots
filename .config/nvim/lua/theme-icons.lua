-- Neovim icon highlights (from colours.css, theme-specific)

local M = {}

M.setup = function()
  local icon_colors = {
    ["folder"] = "#8be9fd",
    ["folder-config"] = "#8be9fd",
    ["folder-git"] = "#ffb86c",
    ["folder-home"] = "#f8f8f2",
    ["folder-downloads"] = "#ffb86c",
    ["folder-documents"] = "#f8f8f2",
    ["folder-music"] = "#ff79c6",
    ["folder-pictures"] = "#ffb86c",
    ["folder-videos"] = "#ffb86c",
    ["lua"] = "#8be9fd",
    ["javascript"] = "#ffb86c",
    ["typescript"] = "#8be9fd",
    ["json"] = "#ffb86c",
    ["markdown"] = "#f8f8f2",
    ["txt"] = "#f8f8f2",
    ["bash"] = "#ffb86c",
    ["zsh"] = "#ffb86c",
    ["python"] = "#50fa7b",
    ["rust"] = "#ff5555",
    ["go"] = "#8be9fd",
    ["c"] = "#bd93f9",
    ["cpp"] = "#8be9fd",
    ["css"] = "#b2f8f8",
    ["scss"] = "#bd93f9",
    ["html"] = "#ff5555",
    ["yaml"] = "#ffb86c",
    ["toml"] = "#8be9fd",
    ["conf"] = "#bd93f9",
    ["mp3"] = "#bd93f9",
    ["flac"] = "#50fa7b",
    ["jpg"] = "#ffb86c",
    ["png"] = "#ffb86c",
    ["gif"] = "#ff79c6",
    ["pdf"] = "#ff5555",
    ["zip"] = "#ffb86c",
  }

  for name, color in pairs(icon_colors) do
    local hl_name = "MiniIcons" .. name:gsub("^%l", string.upper):gsub("-(%l)", string.upper)
    vim.api.nvim_set_hl(0, hl_name, { fg = color })
  end
end

return M
