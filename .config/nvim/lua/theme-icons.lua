-- Neovim icon highlights (from colours.css, theme-specific)

local M = {}

M.setup = function()
  local icon_colors = {
    ["folder"] = "#89b4fa",
    ["folder-config"] = "#89b4fa",
    ["folder-git"] = "#f9e2af",
    ["folder-home"] = "#cdd6f4",
    ["folder-downloads"] = "#f9e2af",
    ["folder-documents"] = "#cdd6f4",
    ["folder-music"] = "#f5c2e7",
    ["folder-pictures"] = "#f9e2af",
    ["folder-videos"] = "#f9e2af",
    ["lua"] = "#89b4fa",
    ["javascript"] = "#f9e2af",
    ["typescript"] = "#89b4fa",
    ["json"] = "#f9e2af",
    ["markdown"] = "#cdd6f4",
    ["txt"] = "#cdd6f4",
    ["bash"] = "#f9e2af",
    ["zsh"] = "#f9e2af",
    ["python"] = "#a6e3a1",
    ["rust"] = "#f38ba8",
    ["go"] = "#89b4fa",
    ["c"] = "#f5c2e7",
    ["cpp"] = "#89b4fa",
    ["css"] = "#94e2d5",
    ["scss"] = "#f5c2e7",
    ["html"] = "#f38ba8",
    ["yaml"] = "#f9e2af",
    ["toml"] = "#89b4fa",
    ["conf"] = "#f5c2e7",
    ["mp3"] = "#f5c2e7",
    ["flac"] = "#a6e3a1",
    ["jpg"] = "#f9e2af",
    ["png"] = "#f9e2af",
    ["gif"] = "#f5c2e7",
    ["pdf"] = "#f38ba8",
    ["zip"] = "#f9e2af",
  }

  for name, color in pairs(icon_colors) do
    local hl_name = "MiniIcons" .. name:gsub("^%l", string.upper):gsub("-(%l)", string.upper)
    vim.api.nvim_set_hl(0, hl_name, { fg = color })
  end
end

return M
