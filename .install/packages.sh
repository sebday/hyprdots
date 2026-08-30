#!/usr/bin/env bash
# Apply hyprdots omarchy package additions and removals from list files.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADDED="$DIR/packages.txt"
REMOVED="$DIR/packages-removed.txt"

pkg_manager() {
	if command -v yay >/dev/null 2>&1; then
		printf '%s' yay
	elif command -v pacman >/dev/null 2>&1; then
		printf '%s' pacman
	else
		return 1
	fi
}

read_list() {
	local file="$1"
	[[ -f "$file" ]] || return 0
	grep -vE '^\s*#|^\s*$' "$file" | awk '{print $1}'
}

installed() {
	pacman -Q "$1" >/dev/null 2>&1
}

cmd_show() {
	local pkg to_remove=() to_install=()

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
	local mgr pkg to_remove=() to_install=()

	mgr="$(pkg_manager)" || {
		echo "packages.sh: yay or pacman required" >&2
		return 1
	}

	while IFS= read -r pkg; do
		[[ -n "$pkg" ]] || continue
		installed "$pkg" && to_remove+=("$pkg")
	done < <(read_list "$REMOVED")

	while IFS= read -r pkg; do
		[[ -n "$pkg" ]] || continue
		installed "$pkg" || to_install+=("$pkg")
	done < <(read_list "$ADDED")

	if ((${#to_remove[@]} > 0)); then
		echo "removing ${#to_remove[@]} package(s)..."
		if [[ "$mgr" == yay ]]; then
			yay -Rns "${to_remove[@]}"
		else
			pacman -Rns "${to_remove[@]}"
		fi
	fi

	if ((${#to_install[@]} > 0)); then
		echo "installing ${#to_install[@]} package(s)..."
		if [[ "$mgr" == yay ]]; then
			yay -S --noconfirm "${to_install[@]}"
		else
			pacman -S --noconfirm "${to_install[@]}"
		fi
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
