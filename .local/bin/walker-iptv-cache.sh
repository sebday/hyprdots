#!/usr/bin/env bash
# Download iptv-org M3U if missing/stale; parse to ~/.cache/iptv/channels.tsv (tab: title, url, referrer, ua).
# Used by walker-iptv-play.sh and the Elephant Lua IPTV menu.

set -euo pipefail
export PATH="${HOME}/.local/bin:${PATH}"

for cmd in curl; do
	command -v "$cmd" >/dev/null 2>&1 || {
		echo "walker-iptv-cache.sh: need '$cmd' in PATH" >&2
		exit 127
	}
done

IPTV_PLAYLIST_URL="${IPTV_PLAYLIST_URL:-https://iptv-org.github.io/iptv/index.m3u}"
IPTV_CACHE_MAX_AGE_MINUTES="${IPTV_CACHE_MAX_AGE_MINUTES:-1440}"

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/iptv"
playlist="$cache_dir/index.m3u"
channels_tsv="$cache_dir/channels.tsv"
mkdir -p "$cache_dir"

refresh_playlist() {
	local tmp
	tmp=$(mktemp "$playlist.part.XXXXXX")
	if curl -fsSL --max-time 120 -o "$tmp" "$IPTV_PLAYLIST_URL"; then
		mv "$tmp" "$playlist"
	else
		rm -f "$tmp"
		return 1
	fi
}

if [[ ! -f "$playlist" ]]; then
	refresh_playlist || {
		echo "failed to download playlist" >&2
		exit 1
	}
elif find "$playlist" -mmin "+$IPTV_CACHE_MAX_AGE_MINUTES" 2>/dev/null | grep -q .; then
	refresh_playlist || true
fi

[[ -s "$playlist" ]] || {
	echo "playlist missing or empty: $playlist" >&2
	exit 1
}

awk '
	function strip_cr(s) { sub(/\r$/, "", s); return s }
	/^#EXTINF:/ {
		title = strip_cr($0)
		sub(/^.*,/, "", title)
		ref = ""; ua = ""; url = ""
		while ((getline line) > 0) {
			line = strip_cr(line)
			if (line ~ /^#EXTVLCOPT:http-referrer=/) {
				sub(/^#EXTVLCOPT:http-referrer=/, "", line); ref = line
			} else if (line ~ /^#EXTVLCOPT:http-user-agent=/) {
				sub(/^#EXTVLCOPT:http-user-agent=/, "", line); ua = line
			} else if (line ~ /^https?:\/\//) {
				url = line
				break
			}
		}
		if (url != "" && title != "")
			print title "\t" url "\t" ref "\t" ua
	}
' "$playlist" >"$channels_tsv"

[[ -s "$channels_tsv" ]] || {
	echo "no playable channels parsed" >&2
	exit 1
}
