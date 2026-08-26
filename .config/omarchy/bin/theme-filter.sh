#!/bin/bash
# Shared helpers to hide light Omarchy themes from picker/cycle lists.
# Source this file; do not execute directly.

OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"
USER_THEMES_PATH="${HOME}/.config/omarchy/themes"
OMARCHY_THEMES_PATH="${OMARCHY_PATH}/themes"
THEME_FILTER_ALL_MARKER="${HOME}/.config/omarchy/theme-filter-all"

theme_filter_enabled() {
	[[ -f "$THEME_FILTER_ALL_MARKER" ]] && return 1
	[[ "${OMARCHY_HIDE_LIGHT_THEMES:-1}" == 0 ]] && return 1
	return 0
}

theme_colors_file() {
	local slug="$1"
	local colors

	for colors in \
		"$USER_THEMES_PATH/$slug/colors.toml" \
		"$OMARCHY_THEMES_PATH/$slug/colors.toml"; do
		[[ -f "$colors" ]] || continue
		printf '%s' "$colors"
		return 0
	done

	return 1
}

theme_slug_visible() {
	local slug="$1"

	theme_filter_enabled || return 0

	local colors mode
	colors=$(theme_colors_file "$slug") || return 0
	mode=$(omarchy-theme-color --file "$colors" mode 2>/dev/null) || return 0
	[[ "$mode" != light ]]
}

theme_slug_to_display_name() {
	local slug="$1"
	printf '%s\n' "$slug" | sed -E 's/(^|-)([a-z])/\1\u\2/g; s/-/ /g'
}

theme_list_slugs() {
	{
		[[ -d "$USER_THEMES_PATH" ]] &&
			find -L "$USER_THEMES_PATH" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) -printf '%f\n' 2>/dev/null
		[[ -d "$OMARCHY_THEMES_PATH" ]] &&
			find "$OMARCHY_THEMES_PATH" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null
	} | sort -u
}

theme_list_visible() {
	local slug

	while IFS= read -r slug; do
		[[ -n "$slug" ]] || continue
		theme_slug_visible "$slug" || continue
		theme_slug_to_display_name "$slug"
	done < <(theme_list_slugs)
}
