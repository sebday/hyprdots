-- Neovim icon highlights (from colours.css, theme-specific)

local M = {}

M.setup = function()
  local icon_colors = {
    ["folder"] = "#7fbbb3",
    ["folder-config"] = "#7fbbb3",
    ["folder-git"] = "#dbbc7f",
    ["folder-home"] = "#d3c6aa",
    ["folder-downloads"] = "#dbbc7f",
    ["folder-documents"] = "#d3c6aa",
    ["folder-music"] = "#d699b6",
    ["folder-pictures"] = "#dbbc7f",
    ["folder-videos"] = "#dbbc7f",
    ["lua"] = "#7fbbb3",
    ["javascript"] = "#dbbc7f",
    ["typescript"] = "#7fbbb3",
    ["json"] = "#dbbc7f",
    ["markdown"] = "#d3c6aa",
    ["txt"] = "#d3c6aa",
    ["bash"] = "#dbbc7f",
    ["zsh"] = "#dbbc7f",
    ["python"] = "#a7c080",
    ["rust"] = "#e67e80",
    ["go"] = "#7fbbb3",
    ["c"] = "#d699b6",
    ["cpp"] = "#7fbbb3",
    ["css"] = "#83c092",
    ["scss"] = "#d699b6",
    ["html"] = "#e67e80",
    ["yaml"] = "#dbbc7f",
    ["toml"] = "#7fbbb3",
    ["conf"] = "#d699b6",
    ["mp3"] = "#d699b6",
    ["flac"] = "#a7c080",
    ["jpg"] = "#dbbc7f",
    ["png"] = "#dbbc7f",
    ["gif"] = "#d699b6",
    ["pdf"] = "#e67e80",
    ["zip"] = "#dbbc7f",
  }

  for name, color in pairs(icon_colors) do
    local hl_name = "MiniIcons" .. name:gsub("^%l", string.upper):gsub("-(%l)", string.upper)
    vim.api.nvim_set_hl(0, hl_name, { fg = color })
  end
end

return M
