-- Neovim icon highlights (from colours.css, theme-specific)

local M = {}

M.setup = function()
  local icon_colors = {
    ["folder"] = "#81a1c1",
    ["folder-config"] = "#81a1c1",
    ["folder-git"] = "#ebcb8b",
    ["folder-home"] = "#d8dee9",
    ["folder-downloads"] = "#ebcb8b",
    ["folder-documents"] = "#d8dee9",
    ["folder-music"] = "#b48ead",
    ["folder-pictures"] = "#ebcb8b",
    ["folder-videos"] = "#ebcb8b",
    ["lua"] = "#81a1c1",
    ["javascript"] = "#ebcb8b",
    ["typescript"] = "#81a1c1",
    ["json"] = "#ebcb8b",
    ["markdown"] = "#d8dee9",
    ["txt"] = "#d8dee9",
    ["bash"] = "#ebcb8b",
    ["zsh"] = "#ebcb8b",
    ["python"] = "#a3be8c",
    ["rust"] = "#bf616a",
    ["go"] = "#81a1c1",
    ["c"] = "#b48ead",
    ["cpp"] = "#81a1c1",
    ["css"] = "#88c0d0",
    ["scss"] = "#b48ead",
    ["html"] = "#bf616a",
    ["yaml"] = "#ebcb8b",
    ["toml"] = "#81a1c1",
    ["conf"] = "#b48ead",
    ["mp3"] = "#b48ead",
    ["flac"] = "#a3be8c",
    ["jpg"] = "#ebcb8b",
    ["png"] = "#ebcb8b",
    ["gif"] = "#b48ead",
    ["pdf"] = "#bf616a",
    ["zip"] = "#ebcb8b",
  }

  for name, color in pairs(icon_colors) do
    local hl_name = "MiniIcons" .. name:gsub("^%l", string.upper):gsub("-(%l)", string.upper)
    vim.api.nvim_set_hl(0, hl_name, { fg = color })
  end
end

return M
