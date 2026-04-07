-- Neovim icon highlights (from colours.css, theme-specific)

local M = {}

M.setup = function()
  local icon_colors = {
    ["folder"] = "#8d8d8d",
    ["folder-config"] = "#8d8d8d",
    ["folder-git"] = "#cecece",
    ["folder-home"] = "#ffffff",
    ["folder-downloads"] = "#cecece",
    ["folder-documents"] = "#ffffff",
    ["folder-music"] = "#9b9b9b",
    ["folder-pictures"] = "#cecece",
    ["folder-videos"] = "#cecece",
    ["lua"] = "#8d8d8d",
    ["javascript"] = "#cecece",
    ["typescript"] = "#8d8d8d",
    ["json"] = "#cecece",
    ["markdown"] = "#ffffff",
    ["txt"] = "#ffffff",
    ["bash"] = "#cecece",
    ["zsh"] = "#cecece",
    ["python"] = "#b6b6b6",
    ["rust"] = "#a4a4a4",
    ["go"] = "#8d8d8d",
    ["c"] = "#9b9b9b",
    ["cpp"] = "#8d8d8d",
    ["css"] = "#b0b0b0",
    ["scss"] = "#9b9b9b",
    ["html"] = "#a4a4a4",
    ["yaml"] = "#cecece",
    ["toml"] = "#8d8d8d",
    ["conf"] = "#9b9b9b",
    ["mp3"] = "#9b9b9b",
    ["flac"] = "#b6b6b6",
    ["jpg"] = "#cecece",
    ["png"] = "#cecece",
    ["gif"] = "#9b9b9b",
    ["pdf"] = "#a4a4a4",
    ["zip"] = "#cecece",
  }

  for name, color in pairs(icon_colors) do
    local hl_name = "MiniIcons" .. name:gsub("^%l", string.upper):gsub("-(%l)", string.upper)
    vim.api.nvim_set_hl(0, hl_name, { fg = color })
  end
end

return M
