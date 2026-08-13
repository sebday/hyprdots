return {
  {
    "saghen/blink.cmp",
    ---@param opts blink.cmp.Config
    opts = function(_, opts)
      opts.completion = opts.completion or {}
      
      -- Disable auto popup of completion menu
      opts.completion.menu = opts.completion.menu or {}
      opts.completion.menu.auto_show = false

      -- Disable ghost text (grey text)
      opts.completion.ghost_text = opts.completion.ghost_text or {}
      opts.completion.ghost_text.enabled = false

      -- Disable documentation auto popup
      opts.completion.documentation = opts.completion.documentation or {}
      opts.completion.documentation.auto_show = false
    end,
  },
}
