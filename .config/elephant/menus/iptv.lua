-- Walker /providerlist → IPTV: rows load from ~/.cache/iptv/channels.tsv (walker-iptv-cache.sh).
Name = "iptv"
NamePretty = "IPTV"
Icon = "video-display"
Cache = true
RefreshOnChange = { (os.getenv("HOME") or "") .. "/.cache/iptv/index.m3u" }

local MAX_CHANNELS = 25000

local function sh_quote(s)
	if not s then
		return "''"
	end
	return "'" .. s:gsub("'", "'\\''") .. "'"
end

function GetEntries(query)
	local home = os.getenv("HOME") or ""
	local ensure = home .. "/.local/bin/iptv-cache.sh"
	local cache = (os.getenv("XDG_CACHE_HOME") or (home .. "/.cache")) .. "/iptv/channels.tsv"

	os.execute("bash " .. sh_quote(ensure) .. " >/dev/null 2>&1")

	local f = io.open(cache, "r")
	if not f then
		return {
			{
				Text = "IPTV: no channel list (run ~/.local/bin/walker-iptv-cache.sh)",
				Actions = { ["menus:default"] = ":" },
			},
		}
	end

	local out = {}
	local n = 0
	for line in f:lines() do
		n = n + 1
		if n > MAX_CHANNELS then
			break
		end
		local title, url, ref, ua = line:match("^(.-)\t(.-)\t(.-)\t(.*)$")
		if title and url and title ~= "" and url ~= "" then
			local mpv = "mpv --force-window=immediate --title=" .. sh_quote(title)
			if ref and ref ~= "" then
				mpv = mpv .. " --referrer=" .. sh_quote(ref)
			end
			if ua and ua ~= "" then
				mpv = mpv .. " --user-agent=" .. sh_quote(ua)
			end
			mpv = mpv .. " " .. sh_quote(url)

			local run = "export PATH="
				.. sh_quote(home .. "/.local/bin")
				.. ":\"$PATH\"; "
				.. "notify-send -a IPTV Starting "
				.. sh_quote(title)
				.. " 2>/dev/null; setsid -f "
				.. mpv
				.. " </dev/null >/dev/null 2>&1 &"

			table.insert(out, {
				Text = title,
				Value = url,
				Actions = { ["menus:default"] = run },
				Keywords = { "tv", "iptv", "stream" },
			})
		end
	end
	f:close()

	if #out == 0 then
		return {
			{
				Text = "IPTV: no channels parsed",
				Actions = { ["menus:default"] = ":" },
			},
		}
	end

	return out
end
