#!/usr/bin/env bash
set -euo pipefail

lib="${HOME}/.local/bin/evo-player-lib.sh"
[[ -f "$lib" ]] || { echo "missing evo-player-lib.sh" >&2; exit 1; }

# shellcheck source=/dev/null
source "$lib"

[[ -n "$MUSIC_STATE" ]] || { echo "MUSIC_STATE unset" >&2; exit 1; }
[[ -n "$MUSIC_CACHE" ]] || { echo "MUSIC_CACHE unset" >&2; exit 1; }
[[ "$MUSIC_STATE" != "$MUSIC_CACHE" ]] || { echo "state and cache must differ" >&2; exit 1; }
[[ "$MUSIC_STATE" == *"/panel/player" ]] || { echo "unexpected state path: $MUSIC_STATE" >&2; exit 1; }
[[ "$MUSIC_CACHE" == *"/evoshell/panel/player" ]] || { echo "unexpected cache path: $MUSIC_CACHE" >&2; exit 1; }

tmp="$(mktemp --suffix=.jpg)"
trap 'rm -f "$tmp"' EXIT
printf '\xff\xd8\xff\xe0\x00\x10JFIF' >"$tmp"
hash="$(art_image_hash "$tmp")"
[[ -n "$hash" ]] || { echo "art_image_hash failed" >&2; exit 1; }
dest="${XDG_CACHE_HOME:-$HOME/.cache}/evoshell/display-art/${hash}.jpg"
rm -f "$dest"
tmpcopy="$(mktemp "${dest}.XXXXXX")"
cp "$tmp" "$tmpcopy" && mv -f "$tmpcopy" "$dest"
[[ -f "$dest" ]] || { echo "atomic display-art write failed" >&2; exit 1; }

echo "evo-player art cache ok"
