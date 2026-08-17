-- Neovim icon highlights (from colours.css, theme-specific)

local M = {}

M.setup = function()
  local icon_colors = {
    ["folder"] = "#e68e0d",
    ["folder-config"] = "#e68e0d",
    ["folder-git"] = "#b91c1c",
    ["folder-home"] = "#bebebe",
    ["folder-downloads"] = "#b91c1c",
    ["folder-documents"] = "#bebebe",
    ["folder-music"] = "#B91C1C",
    ["folder-pictures"] = "#b91c1c",
    ["folder-videos"] = "#b91c1c",
    ["lua"] = "#e68e0d",
    ["javascript"] = "#b91c1c",
    ["typescript"] = "#e68e0d",
    ["json"] = "#b91c1c",
    ["markdown"] = "#bebebe",
    ["txt"] = "#bebebe",
    ["bash"] = "#b91c1c",
    ["zsh"] = "#b91c1c",
    ["python"] = "#FFC107",
    ["rust"] = "#D35F5F",
    ["go"] = "#e68e0d",
    ["c"] = "#D35F5F",
    ["cpp"] = "#e68e0d",
    ["css"] = "#bebebe",
    ["scss"] = "#D35F5F",
    ["html"] = "#D35F5F",
    ["yaml"] = "#b91c1c",
    ["toml"] = "#e68e0d",
    ["conf"] = "#D35F5F",
    ["mp3"] = "#D35F5F",
    ["flac"] = "#FFC107",
    ["jpg"] = "#b91c1c",
    ["png"] = "#b91c1c",
    ["gif"] = "#B91C1C",
    ["pdf"] = "#D35F5F",
    ["zip"] = "#b91c1c",
  }

  for name, color in pairs(icon_colors) do
    local hl_name = "MiniIcons" .. name:gsub("^%l", string.upper):gsub("-(%l)", string.upper)
    vim.api.nvim_set_hl(0, hl_name, { fg = color })
  end
end

return M
