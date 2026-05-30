-- Flat videos in /mnt/external/films → mpv.
Name = "films"
NamePretty = "Films"
Parent = "media"
SearchName = true
HideFromProviderlist = true
Icon = "video-x-generic"
Cache = false

local ROOT = "/mnt/external/films"
local VID = [[-type f \( -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.webm" -o -iname "*.m4v" -o -iname "*.mpg" -o -iname "*.mpeg" -o -iname "*.ts" -o -iname "*.m2ts" -o -iname "*.wmv" -o -iname "*.flv" \)]]

local function q(s)
	return s and "'" .. s:gsub("'", "'\\''") .. "'" or "''"
end
local function base(p)
	return (p:match(".+/([^/]+)$")) or p
end
local function play(path, title)
	local m = "mpv --force-window=immediate --title=" .. q(title) .. " " .. q(path)
	return "notify-send -a Media Starting " .. q(title) .. " 2>/dev/null; setsid -f " .. m .. " </dev/null >/dev/null 2>&1 &"
end

function GetEntries(query)
	local p = io.popen(string.format("find %s -maxdepth 1 %s -print 2>/dev/null | sort", q(ROOT), VID))
	if not p then
		return { { Text = "Films: could not scan " .. ROOT, Actions = { ["menus:default"] = ":" } } }
	end
	local paths = {}
	for line in p:lines() do
		if line ~= "" then
			paths[#paths + 1] = line
		end
	end
	p:close()
	if #paths == 0 then
		return { { Text = "Films: empty " .. ROOT, Actions = { ["menus:default"] = ":" } } }
	end
	local out = {}
	for _, full in ipairs(paths) do
		local t = base(full)
		out[#out + 1] = {
			Text = t,
			Subtext = full,
			Value = full,
			Keywords = { "films", "movies", t },
			Actions = { ["menus:default"] = play(full, t) },
		}
	end
	return out
end
