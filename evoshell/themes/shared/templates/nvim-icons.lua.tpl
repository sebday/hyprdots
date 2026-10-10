-- Neovim icon highlights (from colours.css, theme-specific)

local M = {}

M.setup = function()
  local icon_colors = {
    ["folder"] = "{{ color4 }}",
    ["folder-config"] = "{{ color4 }}",
    ["folder-git"] = "{{ color3 }}",
    ["folder-home"] = "{{ foreground }}",
    ["folder-downloads"] = "{{ color3 }}",
    ["folder-documents"] = "{{ foreground }}",
    ["folder-music"] = "{{ color13 }}",
    ["folder-pictures"] = "{{ color3 }}",
    ["folder-videos"] = "{{ color3 }}",
    ["lua"] = "{{ color4 }}",
    ["javascript"] = "{{ color3 }}",
    ["typescript"] = "{{ color4 }}",
    ["json"] = "{{ color3 }}",
    ["markdown"] = "{{ foreground }}",
    ["txt"] = "{{ foreground }}",
    ["bash"] = "{{ color3 }}",
    ["zsh"] = "{{ color3 }}",
    ["python"] = "{{ color2 }}",
    ["rust"] = "{{ color1 }}",
    ["go"] = "{{ color4 }}",
    ["c"] = "{{ color5 }}",
    ["cpp"] = "{{ color4 }}",
    ["css"] = "{{ color6 }}",
    ["scss"] = "{{ color5 }}",
    ["html"] = "{{ color1 }}",
    ["yaml"] = "{{ color3 }}",
    ["toml"] = "{{ color4 }}",
    ["conf"] = "{{ color5 }}",
    ["mp3"] = "{{ color5 }}",
    ["flac"] = "{{ color2 }}",
    ["jpg"] = "{{ color3 }}",
    ["png"] = "{{ color3 }}",
    ["gif"] = "{{ color13 }}",
    ["pdf"] = "{{ color1 }}",
    ["zip"] = "{{ color3 }}",
  }

  for name, color in pairs(icon_colors) do
    local hl_name = "MiniIcons" .. name:gsub("^%l", string.upper):gsub("-(%l)", string.upper)
    vim.api.nvim_set_hl(0, hl_name, { fg = color })
  end
end

return M
