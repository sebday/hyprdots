-- /mnt/external/tv: folders → SubMenu "tv" + lastMenuValue("tv"); files → mpv.
Name = "tv"
NamePretty = "TV"
Parent = "media"
SearchName = true
HideFromProviderlist = true
Icon = "video-television"
FixedOrder = true
Cache = false

local ROOT = "/mnt/external/tv"
local VID = [[-type f \( -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.webm" -o -iname "*.m4v" -o -iname "*.mpg" -o -iname "*.mpeg" -o -iname "*.ts" -o -iname "*.m2ts" -o -iname "*.wmv" -o -iname "*.flv" \)]]

local function q(s)
	return s and "'" .. s:gsub("'", "'\\''") .. "'" or "''"
end
local function base(p)
	return (p:match(".+/([^/]+)$")) or p
end
local function under(p)
	return p == ROOT or p:sub(1, #ROOT + 1) == ROOT .. "/"
end
local function isdir(p)
	local h = io.popen("test -d " .. q(p) .. " && echo 1")
	if not h then
		return false
	end
	local ok = h:read("*l") == "1"
	h:close()
	return ok
end
local function cwd()
	local v = lastMenuValue("tv")
	if v == nil or v == "" or not under(v) or not isdir(v) then
		return ROOT
	end
	return v
end
local function parent(dir)
	if dir == ROOT then
		return nil
	end
	local p = dir:match("^(/.+)/[^/]+$")
	if not p or not under(p) then
		return ROOT
	end
	return p
end
local function play(path, title)
	local m = "mpv --force-window=immediate --title=" .. q(title) .. " " .. q(path)
	return "notify-send -a Media Starting " .. q(title) .. " 2>/dev/null; setsid -f " .. m .. " </dev/null >/dev/null 2>&1 &"
end
local function lines(cmd)
	local p = io.popen(cmd)
	if not p then
		return {}
	end
	local t = {}
	for l in p:lines() do
		if l ~= "" then
			t[#t + 1] = l
		end
	end
	p:close()
	return t
end

function GetEntries(query)
	local dir, out = cwd(), {}
	local pd = parent(dir)
	if pd then
		out[#out + 1] = {
			Text = "..",
			Subtext = pd,
			Value = pd,
			Icon = "go-up-symbolic",
			Keywords = { "tv", "up" },
			SubMenu = "tv",
		}
	end
	for _, path in ipairs(lines(string.format("find %s -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | sort", q(dir)))) do
		out[#out + 1] = {
			Text = base(path),
			Subtext = path,
			Value = path,
			Icon = "folder-symbolic",
			Keywords = { "tv", "folder", base(path) },
			SubMenu = "tv",
		}
	end
	for _, path in ipairs(lines(string.format("find %s -maxdepth 1 %s -print 2>/dev/null | sort", q(dir), VID))) do
		local t = base(path)
		out[#out + 1] = {
			Text = t,
			Subtext = path,
			Value = path,
			Keywords = { "tv", "file", t },
			Actions = { ["menus:default"] = play(path, t) },
		}
	end
	if #out == 0 then
		return { { Text = "TV: empty " .. dir, Actions = { ["menus:default"] = ":" } } }
	end
	return out
end
