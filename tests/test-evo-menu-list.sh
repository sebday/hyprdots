#!/usr/bin/env bash
set -euo pipefail

root="${EVOSHELL_ROOT:-$HOME/projects/evoshell}"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

export HOME="${tmpdir}/home"
export EVOSHELL_BIN="${root}/bin"
export EVOSHELL_ROOT="${root}"
export EVOSHELL_CONFIG="${HOME}/.config/evoshell"
export EVOSHELL_STATE="${HOME}/.local/state/evoshell"
export EVOSHELL_CACHE="${HOME}/.cache/evoshell"

mkdir -p "${HOME}/.themes" "${EVOSHELL_CACHE}/menu-cache"
ln -sfn "${root}/themes" "${HOME}/.themes/repo-themes"
rm -rf "${HOME}/.themes"
ln -sfn "${root}/themes" "${HOME}/.themes"

out="$("${root}/bin/evo-menu-list" themes)"
[[ -n "$out" ]] || { echo "evo-menu-list themes returned no entries" >&2; exit 1; }
grep -q $'everforest\t' <<<"$out" || { echo "expected everforest theme in listing" >&2; exit 1; }

wallpapers="$("${root}/bin/evo-menu-list" wallpapers)"
[[ -n "$wallpapers" ]] || { echo "evo-menu-list wallpapers returned no entries" >&2; exit 1; }
grep -q 'evo-wallpaper set' <<<"$wallpapers" || { echo "expected wallpaper commands in listing" >&2; exit 1; }

echo "ok"
