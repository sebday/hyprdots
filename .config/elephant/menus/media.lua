Name = "media"
NamePretty = "Media"
Icon = "multimedia-video-player"
SearchName = true
FixedOrder = true
Cache = false

function GetEntries(query)
	return {
		{ Text = "IPTV", Icon = "video-display", Keywords = { "iptv", "stream", "channels", "m3u" }, SubMenu = "iptv" },
		{ Text = "TV", Icon = "video-television", Keywords = { "tv", "shows", "series", "local", "files" }, SubMenu = "tv" },
		{ Text = "Films", Icon = "video-x-generic", Keywords = { "films", "movies", "local", "files" }, SubMenu = "films" },
	}
end
