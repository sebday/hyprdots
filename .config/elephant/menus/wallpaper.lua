-- Wallpaper under System: images in ~/.themes/current/backgrounds (same as wallpaper.sh select).
Name = "wallpaper"
NamePretty = "Wallpaper"
Parent = "system"
SearchName = true
HideFromProviderlist = true
Cache = false

local function sh_quote(s)
	if not s then
		return "''"
	end
	return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function basename(path)
	local base = path:match(".+/([^/]+)$")
	return base or path
end

function GetEntries(query)
	local home = os.getenv("HOME") or ""
	local dir = home .. "/.themes/current/backgrounds"

	local cmd = string.format(
		'find "%s" -type f \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \\) -print 2>/dev/null | sort',
		dir
	)
	local p = io.popen(cmd)
	if not p then
		return {
			{
				Text = "Wallpaper: could not read backgrounds folder",
				Actions = { ["menus:default"] = ":" },
			},
		}
	end

	local paths = {}
	for line in p:lines() do
		if line ~= "" then
			table.insert(paths, line)
		end
	end
	p:close()

	if #paths == 0 then
		return {
			{
				Text = "Wallpaper: no images in ~/.themes/current/backgrounds",
				Actions = { ["menus:default"] = ":" },
			},
		}
	end

	local out = {}
	for _, full in ipairs(paths) do
		local inner = string.format(
			'exec "%s/.local/bin/wallpaper.sh" %s',
			home,
			sh_quote(full)
		)
		local run = string.format("bash -lc %s", sh_quote(inner))
		table.insert(out, {
			Text = basename(full),
			Subtext = full,
			Value = full,
			Preview = full,
			PreviewType = "file",
			Keywords = { "wallpaper", basename(full) },
			Actions = { ["menus:default"] = run },
		})
	end

	return out
end
