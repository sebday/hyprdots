#!/usr/bin/env bash
# Create or refresh a menu preview thumbnail and print its path.
set -euo pipefail

src="${1:-}"
key="${2:-}"

[[ -n "$src" && -n "$key" ]] || exit 1
[[ -f "$src" ]] || exit 1

cache_root="${XDG_STATE_HOME:-$HOME/.local/state}/evo-shell/menu-cache"
dst="$cache_root/$key"

mkdir -p "$(dirname "$dst")"

if [[ ! -f "$dst" ]] || [[ "$src" -nt "$dst" ]]; then
    if command -v magick >/dev/null 2>&1; then
        magick "$src" -thumbnail 384x248^ -gravity center -extent 384x248 PNG:"$dst" 2>/dev/null || cp -f "$src" "$dst"
    else
        cp -f "$src" "$dst"
    fi
fi

printf '%s' "$dst"
