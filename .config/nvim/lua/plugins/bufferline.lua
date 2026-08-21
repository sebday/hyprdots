return {
  {
    "akinsho/bufferline.nvim",
    opts = function(_, opts)
      opts.options = opts.options or {}
      local filter = opts.options.custom_filter
      opts.options.custom_filter = function(bufnr, ...)
        if vim.bo[bufnr].filetype == "md-render" then
          return false
        end
        return filter and filter(bufnr, ...) or true
      end
    end,
  },
}
