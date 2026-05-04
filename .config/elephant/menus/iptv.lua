-- channels.tsv from ~/.local/bin/iptv-cache.sh
Name = "iptv"
NamePretty = "IPTV"
Parent = "media"
SearchName = true
HideFromProviderlist = true
Icon = "video-display"
Cache = true
RefreshOnChange = { (os.getenv("HOME") or "") .. "/.cache/iptv/index.m3u" }

local MAX = 25000

local function q(s)
	return s and "'" .. s:gsub("'", "'\\''") .. "'" or "''"
end

function GetEntries(query)
	local home = os.getenv("HOME") or ""
	local cache = (os.getenv("XDG_CACHE_HOME") or home .. "/.cache") .. "/iptv/channels.tsv"

	os.execute("bash " .. q(home .. "/.local/bin/iptv-cache.sh") .. " >/dev/null 2>&1")

	local f = io.open(cache, "r")
	if not f then
		return { { Text = "IPTV: no channel list", Actions = { ["menus:default"] = ":" } } }
	end

	local out, n = {}, 0
	for line in f:lines() do
		n = n + 1
		if n > MAX then
			break
		end
		local title, url, ref, ua = line:match("^(.-)\t(.-)\t(.-)\t(.*)$")
		if title and url and title ~= "" and url ~= "" then
			local mpv = "mpv --force-window=immediate --title=" .. q(title)
			if ref and ref ~= "" then
				mpv = mpv .. " --referrer=" .. q(ref)
			end
			if ua and ua ~= "" then
				mpv = mpv .. " --user-agent=" .. q(ua)
			end
			mpv = mpv .. " " .. q(url)
			local run = "export PATH=" .. q(home .. "/.local/bin") .. ":\"$PATH\"; notify-send -a IPTV Starting "
				.. q(title)
				.. " 2>/dev/null; setsid -f "
				.. mpv
				.. " </dev/null >/dev/null 2>&1 &"
			out[#out + 1] = {
				Text = title,
				Value = url,
				Actions = { ["menus:default"] = run },
				Keywords = { "tv", "iptv", "stream" },
			}
		end
	end
	f:close()

	if #out == 0 then
		return { { Text = "IPTV: no channels parsed", Actions = { ["menus:default"] = ":" } } }
	end
	return out
end
