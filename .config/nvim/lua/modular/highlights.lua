-- Modular: highlight group definitions (palette-agnostic)
-- Each function receives palette and returns { [group] = { fg, bg, ... } }
--
-- Coverage: core (Normal, StatusLine, Cursor, Pmenu, syntax, etc.), LSP, diagnostics,
-- Treesitter (@comment, @string, @function, etc.), Snacks (picker, input).
-- Expand lsp/treesitter as needed for additional plugins.

local M = {}

function M.core(p)
  return {
    Normal = { fg = p.text, bg = p.base },
    NormalNC = { fg = p.text, bg = p.base },
    NormalSB = { fg = p.text, bg = p.base },
    NormalFloat = { fg = p.text, bg = p.mantle },
    FloatBorder = { fg = p.overlay0, bg = p.mantle },
    FloatTitle = { fg = p.text, bg = p.mantle },

    Comment = { fg = p.overlay2, italic = true },
    String = { fg = p.green },
    Character = { fg = p.green },
    Number = { fg = p.peach },
    Boolean = { fg = p.peach },
    Float = { fg = p.peach },
    Identifier = { fg = p.text },
    Function = { fg = p.blue },
    Method = { fg = p.blue },
    Keyword = { fg = p.pink },
    Statement = { fg = p.pink },
    Conditional = { fg = p.pink },
    Repeat = { fg = p.pink },
    Label = { fg = p.pink },
    Operator = { fg = p.sky },
    Exception = { fg = p.red },
    PreProc = { fg = p.mauve },
    Include = { fg = p.mauve },
    Define = { fg = p.mauve },
    Macro = { fg = p.mauve },
    Type = { fg = p.yellow },
    StorageClass = { fg = p.yellow },
    Structure = { fg = p.yellow },
    Typedef = { fg = p.yellow },
    Constant = { fg = p.peach },
    Special = { fg = p.mauve },
    SpecialChar = { fg = p.flamingo },
    Tag = { fg = p.mauve },
    Delimiter = { fg = p.overlay2 },
    Debug = { fg = p.red },
    Underlined = { underline = true, fg = p.text },
    Ignore = { fg = p.overlay0 },
    Error = { fg = p.red },
    Todo = { fg = p.mauve, bold = true },

    Cursor = { fg = p.base, bg = p.rosewater },
    CursorLine = { bg = p.surface0 },
    CursorLineNr = { fg = p.rosewater, bg = p.surface0 },
    LineNr = { fg = p.overlay1 },
    CursorColumn = { bg = p.surface0 },

    StatusLine = { fg = p.text, bg = p.base },
    StatusLineNC = { fg = p.surface1, bg = p.base },
    WinSeparator = { fg = p.surface2 },

    Visual = { bg = p.surface1 },
    VisualNOS = { bg = p.surface1 },
    Search = { fg = p.base, bg = p.yellow },
    IncSearch = { fg = p.base, bg = p.peach },
    Substitute = { fg = p.base, bg = p.peach },

    Pmenu = { fg = p.text, bg = p.mantle },
    PmenuSel = { fg = p.mantle, bg = p.blue },
    PmenuSbar = { bg = p.surface0 },
    PmenuThumb = { bg = p.overlay0 },

    TabLine = { fg = p.overlay1, bg = p.mantle },
    TabLineFill = { fg = p.overlay1, bg = p.mantle },
    TabLineSel = { fg = p.text, bg = p.base },

    MatchParen = { fg = p.peach, bold = true },
    ColorColumn = { bg = p.surface0 },
    Conceal = { fg = p.overlay1 },
    Directory = { fg = p.blue },
    EndOfBuffer = { fg = p.base },
    ErrorMsg = { fg = p.red },
    Folded = { fg = p.overlay2, bg = p.mantle },
    FoldColumn = { fg = p.overlay1 },
    SignColumn = { fg = p.text, bg = p.base },
    MoreMsg = { fg = p.green },
    NonText = { fg = p.overlay1 },
    Question = { fg = p.yellow },
    QuickFixLine = { bg = p.surface1 },
    SpecialKey = { fg = p.overlay1 },
    SpellBad = { fg = p.red, underline = true },
    SpellCap = { fg = p.sapphire, underline = true },
    SpellLocal = { fg = p.teal, underline = true },
    SpellRare = { fg = p.flamingo, underline = true },
    Title = { fg = p.blue, bold = true },
    WarningMsg = { fg = p.peach },
    Whitespace = { fg = p.overlay0 },
    WildMenu = { fg = p.mantle, bg = p.blue },
  }
end

function M.lsp(p)
  return {
    LspReferenceText = { bg = p.surface1 },
    LspReferenceRead = { bg = p.surface1 },
    LspReferenceWrite = { bg = p.surface1 },
    LspCodeLens = { fg = p.overlay0 },
    LspCodeLensSeparator = { fg = p.overlay0 },
    LspInfoBorder = { fg = p.surface1 },
    LspInlayHint = { fg = p.overlay0 },
  }
end

function M.diagnostics(p)
  return {
    DiagnosticError = { fg = p.red },
    DiagnosticWarn = { fg = p.peach },
    DiagnosticInfo = { fg = p.blue },
    DiagnosticHint = { fg = p.teal },
    DiagnosticOk = { fg = p.green },
    DiagnosticUnderlineError = { sp = p.red, underline = true },
    DiagnosticUnderlineWarn = { sp = p.peach, underline = true },
    DiagnosticUnderlineInfo = { sp = p.blue, underline = true },
    DiagnosticUnderlineHint = { sp = p.teal, underline = true },
  }
end

function M.snacks(p)
  return {
    SnacksNormalNC = { fg = p.text, bg = p.base },
    SnacksPicker = { fg = p.text, bg = p.base },
    SnacksPickerInput = { fg = p.text, bg = p.base },
    SnacksPickerInputBorder = { fg = p.overlay0, bg = p.base },
    SnacksPickerDir = { fg = p.overlay2 },
    SnacksPickerDimmed = { fg = p.overlay2 },
    SnacksPickerPathHidden = { fg = p.overlay1 },
    SnacksPickerPathIgnored = { fg = p.overlay1 },
    SnacksPickerTotals = { fg = p.overlay2 },
    SnacksPickerUnselected = { fg = p.overlay2 },
    SnacksPickerDelim = { fg = p.overlay1 },
    SnacksPickerComment = { fg = p.overlay2, italic = true },
    SnacksPickerBufFlags = { fg = p.overlay1 },
    SnacksPickerKeymapRhs = { fg = p.overlay1 },
  }
end

function M.treesitter(p)
  return {
    ["@comment"] = { link = "Comment" },
    ["@string"] = { link = "String" },
    ["@string.special"] = { link = "SpecialChar" },
    ["@character"] = { link = "Character" },
    ["@number"] = { link = "Number" },
    ["@boolean"] = { link = "Boolean" },
    ["@float"] = { link = "Float" },
    ["@function"] = { link = "Function" },
    ["@function.call"] = { link = "Function" },
    ["@method"] = { link = "Method" },
    ["@method.call"] = { link = "Method" },
    ["@constructor"] = { link = "Type" },
    ["@parameter"] = { link = "Identifier" },
    ["@keyword"] = { link = "Keyword" },
    ["@keyword.function"] = { link = "Keyword" },
    ["@keyword.return"] = { link = "Keyword" },
    ["@conditional"] = { link = "Conditional" },
    ["@repeat"] = { link = "Repeat" },
    ["@label"] = { link = "Label" },
    ["@operator"] = { link = "Operator" },
    ["@exception"] = { link = "Exception" },
    ["@type"] = { link = "Type" },
    ["@type.builtin"] = { link = "Type" },
    ["@type.definition"] = { link = "Typedef" },
    ["@storageclass"] = { link = "StorageClass" },
    ["@attribute"] = { link = "PreProc" },
    ["@field"] = { link = "Identifier" },
    ["@property"] = { link = "Identifier" },
    ["@variable"] = { link = "Identifier" },
    ["@variable.builtin"] = { link = "Constant" },
    ["@constant"] = { link = "Constant" },
    ["@constant.builtin"] = { link = "Constant" },
    ["@constant.macro"] = { link = "Define" },
    ["@namespace"] = { link = "Include" },
    ["@symbol"] = { link = "Identifier" },
    ["@text"] = { link = "Normal" },
    ["@text.uri"] = { fg = p.blue, underline = true },
    ["@text.reference"] = { fg = p.blue },
    ["@text.title"] = { link = "Title" },
    ["@text.literal"] = { link = "String" },
    ["@text.emphasis"] = { italic = true },
    ["@text.strong"] = { bold = true },
    ["@text.warning"] = { fg = p.peach },
    ["@text.danger"] = { fg = p.red },
    ["@text.diff.add"] = { fg = p.green },
    ["@text.diff.delete"] = { fg = p.red },
    ["@tag"] = { link = "Tag" },
    ["@tag.delimiter"] = { link = "Delimiter" },
    ["@tag.attribute"] = { link = "Identifier" },
    ["@punctuation"] = { link = "Delimiter" },
    ["@punctuation.delimiter"] = { link = "Delimiter" },
    ["@punctuation.bracket"] = { link = "Delimiter" },
    ["@punctuation.special"] = { link = "Delimiter" },
  }
end

function M.apply_all(palette)
  local p = palette
  local groups = {}
  for name, fn in pairs(M) do
    if type(fn) == "function" and name ~= "apply_all" then
      for group, attrs in pairs(fn(p)) do
        groups[group] = attrs
      end
    end
  end
  for group, attrs in pairs(groups) do
    vim.api.nvim_set_hl(0, group, attrs)
  end
end

return M
