-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.opt.scrolloff = 0
vim.opt.sidescrolloff = 0
vim.opt.shortmess:append("A")
vim.opt.laststatus = 0

-- Prefer the git repo (home) over nested LSP roots like ~/.config/hypr/.luarc.json
vim.g.root_spec = { { ".git" }, "lsp", "cwd" }
