#!/usr/bin/env bash
# Apply hyprdots omarchy package additions and removals from list files
# via `omarchy pkg` (not yay/pacman directly).
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADDED="$DIR/packages.txt"
REMOVED="$DIR/packages-removed.txt"

require_omarchy() {
	if ! command -v omarchy >/dev/null 2>&1; then
		echo "packages.sh: omarchy required (use omarchy pkg add/drop, not yay/pacman)" >&2
		return 1
	fi
}

read_list() {
	local file="$1"
	[[ -f "$file" ]] || return 0
	grep -vE '^\s*#|^\s*$' "$file" | awk '{print $1}'
}

installed() {
	omarchy pkg present "$1" >/dev/null 2>&1
}

in_sync_repo() {
	pacman -Si "$1" >/dev/null 2>&1
}

cmd_show() {
	local pkg to_remove=() to_install=()

	require_omarchy

	while IFS= read -r pkg; do
		[[ -n "$pkg" ]] || continue
		if installed "$pkg"; then
			to_remove+=("$pkg")
		fi
	done < <(read_list "$REMOVED")

	while IFS= read -r pkg; do
		[[ -n "$pkg" ]] || continue
		if ! installed "$pkg"; then
			to_install+=("$pkg")
		fi
	done < <(read_list "$ADDED")

	echo "remove (${#to_remove[@]}):"
	if ((${#to_remove[@]} > 0)); then
		printf '  %s\n' "${to_remove[@]}"
	else
		echo "  (none)"
	fi

	echo "install (${#to_install[@]}):"
	if ((${#to_install[@]} > 0)); then
		printf '  %s\n' "${to_install[@]}"
	else
		echo "  (none)"
	fi
}

cmd_apply() {
	local pkg to_remove=() to_install=() repo_pkgs=() aur_pkgs=()

	require_omarchy

	while IFS= read -r pkg; do
		[[ -n "$pkg" ]] || continue
		installed "$pkg" && to_remove+=("$pkg")
	done < <(read_list "$REMOVED")

	while IFS= read -r pkg; do
		[[ -n "$pkg" ]] || continue
		installed "$pkg" || to_install+=("$pkg")
	done < <(read_list "$ADDED")

	if ((${#to_remove[@]} > 0)); then
		echo "removing ${#to_remove[@]} package(s) via omarchy pkg drop..."
		omarchy pkg drop "${to_remove[@]}"
	fi

	for pkg in "${to_install[@]}"; do
		if in_sync_repo "$pkg"; then
			repo_pkgs+=("$pkg")
		else
			aur_pkgs+=("$pkg")
		fi
	done

	if ((${#repo_pkgs[@]} > 0)); then
		echo "installing ${#repo_pkgs[@]} package(s) via omarchy pkg add..."
		omarchy pkg add "${repo_pkgs[@]}"
	fi

	if ((${#aur_pkgs[@]} > 0)); then
		echo "installing ${#aur_pkgs[@]} package(s) via omarchy pkg aur add..."
		omarchy pkg aur add "${aur_pkgs[@]}"
	fi

	if ((${#to_remove[@]} == 0 && ${#to_install[@]} == 0)); then
		echo "packages: nothing to do"
	fi
}

case "${1:-}" in
show)
	cmd_show
	;;
apply)
	cmd_apply
	;;
*)
	echo "usage: $0 show|apply" >&2
	exit 1
	;;
esac
