-- Strip background from markdown inline code and headings while keeping theme foreground.
local explicit_groups = {
	"@markup.raw.markdown_inline",
	"@markup.raw",
	"markdownCode",
	"RenderMarkdownCodeInline",
}

local heading_patterns = {
	"^@markup%.heading",
	"^RenderMarkdownH%d+",
	"^Headline%d+$",
	"^markdownH%d+$",
}

local function matches_heading(name)
	for _, pat in ipairs(heading_patterns) do
		if name:match(pat) then
			return true
		end
	end
	return false
end

local function clear_bg(name)
	local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
	if ok and hl.bg then
		hl.bg = nil
		vim.api.nvim_set_hl(0, name, hl)
	end
end

local function clear_markdown_bg()
	for _, name in ipairs(explicit_groups) do
		clear_bg(name)
	end

	for name, hl in pairs(vim.api.nvim_get_hl(0, {})) do
		if hl.bg and matches_heading(name) then
			clear_bg(name)
		end
	end
end

vim.api.nvim_create_autocmd("ColorScheme", { callback = clear_markdown_bg })
vim.defer_fn(clear_markdown_bg, 0)
