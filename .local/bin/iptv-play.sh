#!/usr/bin/env bash
# iptv-org M3U → ~/.cache/iptv/channels.tsv → Walker --dmenu → detached mpv.

set -euo pipefail

export PATH="${HOME}/.local/bin:${PATH}"

for cmd in launch-walker walker mpv; do
	command -v "$cmd" >/dev/null 2>&1 || {
		echo "iptv-play.sh: need '$cmd' in PATH" >&2
		exit 127
	}
done

bash "${HOME}/.local/bin/iptv-ensure-cache.sh"

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/iptv"
channels_tsv="$cache_dir/channels.tsv"

[[ -s "$channels_tsv" ]] || {
	echo "no channel list: $channels_tsv" >&2
	exit 1
}

idx=$(cut -f1 "$channels_tsv" | launch-walker --dmenu --width 644 --minheight 1 --maxheight 520 -p 'search channels ' -i | tr -d '\n\r')
[[ -z "$idx" ]] && exit 0
[[ "$idx" =~ ^[0-9]+$ ]] || exit 0

IFS=$'\t' read -r title url referrer useragent < <(awk -v n="$idx" 'NR == n + 1 { print; exit }' "$channels_tsv")

mpv_args=(--force-window=immediate --title="$title")
[[ -n "${referrer:-}" ]] && mpv_args+=(--referrer="$referrer")
[[ -n "${useragent:-}" ]] && mpv_args+=(--user-agent="$useragent")

before_mpv=0
if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
	before_mpv=$(hyprctl clients -j 2>/dev/null | jq 'map(select(.class == "mpv")) | length' 2>/dev/null || echo 0)
fi

notify-send -a "IPTV" "Starting" "$title" 2>/dev/null || true
setsid -f mpv "${mpv_args[@]}" "$url" </dev/null &>/dev/null

if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
	for ((i = 0; i < 48; i++)); do
		after=$(hyprctl clients -j 2>/dev/null | jq 'map(select(.class == "mpv")) | length' 2>/dev/null || echo 0)
		((after > before_mpv)) && break
		sleep 0.25
	done
else
	sleep 2
fi
