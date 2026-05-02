-- Themes under System: list ~/.themes/* (excludes current, shared, next).
Name = "theme"
NamePretty = "Themes"
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

local function file_readable(path)
	local f = io.open(path, "r")
	if f then
		f:close()
		return true
	end
	return false
end

function GetEntries(query)
	local home = os.getenv("HOME") or ""
	local root = home .. "/.themes"
	local skip = {
		current = true,
		shared = true,
		next = true,
	}
	local out = {}

	local cmd =
		string.format('find "%s" -mindepth 1 -maxdepth 1 -type d -printf "%%f\\n" 2>/dev/null | sort', root)
	local p = io.popen(cmd)
	if not p then
		return {
			{
				Text = "Themes: could not scan ~/.themes",
				Actions = { ["menus:default"] = ":" },
			},
		}
	end

	local names = {}
	for line in p:lines() do
		if line ~= "" and not skip[line] then
			table.insert(names, line)
		end
	end
	p:close()

	if #names == 0 then
		return {
			{
				Text = "Themes: no theme folders in ~/.themes",
				Actions = { ["menus:default"] = ":" },
			},
		}
	end

	for _, name in ipairs(names) do
		local run = string.format(
			"bash -lc %s",
			sh_quote('exec "' .. home .. '/.local/bin/themes-apply.sh" ' .. name)
		)
		local preview_path = root .. "/" .. name .. "/preview.png"
		local entry = {
			Text = name,
			Value = name,
			Keywords = { "theme", name },
			Actions = { ["menus:default"] = run },
		}
		if file_readable(preview_path) then
			entry.Preview = preview_path
			entry.PreviewType = "file"
		end
		table.insert(out, entry)
	end

	return out
end
