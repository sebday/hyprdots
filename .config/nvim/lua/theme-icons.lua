-- Neovim icon highlights (from colours.css, theme-specific)

local M = {}

M.setup = function()
  local icon_colors = {
    ["folder"] = "#7daea3",
    ["folder-config"] = "#7daea3",
    ["folder-git"] = "#d8a657",
    ["folder-home"] = "#d4be98",
    ["folder-downloads"] = "#d8a657",
    ["folder-documents"] = "#d4be98",
    ["folder-music"] = "#d3869b",
    ["folder-pictures"] = "#d8a657",
    ["folder-videos"] = "#d8a657",
    ["lua"] = "#7daea3",
    ["javascript"] = "#d8a657",
    ["typescript"] = "#7daea3",
    ["json"] = "#d8a657",
    ["markdown"] = "#d4be98",
    ["txt"] = "#d4be98",
    ["bash"] = "#d8a657",
    ["zsh"] = "#d8a657",
    ["python"] = "#a9b665",
    ["rust"] = "#ea6962",
    ["go"] = "#7daea3",
    ["c"] = "#d3869b",
    ["cpp"] = "#7daea3",
    ["css"] = "#89b482",
    ["scss"] = "#d3869b",
    ["html"] = "#ea6962",
    ["yaml"] = "#d8a657",
    ["toml"] = "#7daea3",
    ["conf"] = "#d3869b",
    ["mp3"] = "#d3869b",
    ["flac"] = "#a9b665",
    ["jpg"] = "#d8a657",
    ["png"] = "#d8a657",
    ["gif"] = "#d3869b",
    ["pdf"] = "#ea6962",
    ["zip"] = "#d8a657",
  }

  for name, color in pairs(icon_colors) do
    local hl_name = "MiniIcons" .. name:gsub("^%l", string.upper):gsub("-(%l)", string.upper)
    vim.api.nvim_set_hl(0, hl_name, { fg = color })
  end
end

return M
