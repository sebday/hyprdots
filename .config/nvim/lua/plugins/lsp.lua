return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        lua_ls = {
          settings = {
            Lua = {
              diagnostics = {
                globals = { "hl" },
              },
              workspace = {
                library = vim.uv.fs_stat("/usr/share/hypr/stubs") and { "/usr/share/hypr/stubs" } or nil,
                checkThirdParty = false,
              },
            },
          },
        },
      },
    },
  },
}
