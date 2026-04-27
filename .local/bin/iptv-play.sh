#!/usr/bin/env bash
# iptv-org playlist picker: floating terminal (TUI.float), fzf search, mpv playback.

set -euo pipefail

IPTV_PLAYLIST_URL="${IPTV_PLAYLIST_URL:-https://iptv-org.github.io/iptv/index.m3u}"
IPTV_CACHE_MAX_AGE_MINUTES="${IPTV_CACHE_MAX_AGE_MINUTES:-1440}"
TERMINAL_FLOAT="${TERMINAL_FLOAT:-ghostty}"

script_path=$(readlink -f "${BASH_SOURCE[0]}")

if [[ "${1:-}" != "--inner" ]]; then
	exec "$TERMINAL_FLOAT" --class=TUI.float -e bash -c "exec bash $(printf '%q' "$script_path") --inner"
fi

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/iptv"
playlist="$cache_dir/index.m3u"
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

if [[ ! -s "$playlist" ]]; then
	echo "playlist missing or empty: $playlist" >&2
	exit 1
fi

# Parse M3U: title from #EXTINF (text after last comma), optional EXTVLCOPT, then stream URL.
selected=$(
	awk '
		function strip_cr(s) { sub(/\r$/, "", s); return s }
		/^#EXTINF:/ {
			title = strip_cr($0)
			sub(/^.*,/, "", title)
			ref = ""
			ua = ""
			url = ""
			while ((getline line) > 0) {
				line = strip_cr(line)
				if (line ~ /^#EXTVLCOPT:http-referrer=/) {
					sub(/^#EXTVLCOPT:http-referrer=/, "", line)
					ref = line
				} else if (line ~ /^#EXTVLCOPT:http-user-agent=/) {
					sub(/^#EXTVLCOPT:http-user-agent=/, "", line)
					ua = line
				} else if (line ~ /^https?:\/\//) {
					url = line
					break
				}
			}
			if (url != "" && title != "")
				print title "\t" url "\t" ref "\t" ua
		}
	' "$playlist" | fzf --delimiter=$'\t' --with-nth=1 \
		--prompt='iptv channel> ' \
		--height=100% \
		--layout=reverse \
		--info=inline
) || true

[[ -z "${selected:-}" ]] && exit 0

IFS=$'\t' read -r title url referrer useragent <<<"$selected"

mpv_args=()
[[ -n "${referrer:-}" ]] && mpv_args+=(--referrer="$referrer")
[[ -n "${useragent:-}" ]] && mpv_args+=(--user-agent="$useragent")

# start mpv outside this tty/session so ghostty can exit as soon as fzf is done
if command -v setsid >/dev/null 2>&1; then
	setsid -f -- mpv "${mpv_args[@]}" "$url" </dev/null &>/dev/null
else
	nohup mpv "${mpv_args[@]}" "$url" </dev/null &>/dev/null &
	disown || true
fi
exit 0
