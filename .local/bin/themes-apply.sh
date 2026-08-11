#!/bin/bash
set -e
# Apply a theme: build into staging, promote, activate live consumers, notify apps
#
# USAGE:
#   themes-apply.sh [select]  - Open menu to select a theme (default)
#   themes-apply.sh refresh   - Regenerate configs for current theme
#   themes-apply.sh <name>    - Apply theme by name

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/themes-common.sh"

CURRENT_PATH="${CURRENT_PATH:-$THEME_DIR/current}"
NEXT_PATH="${NEXT_PATH:-$THEME_DIR/next}"
STAGING_DIR=""

cleanup_staging() {
    if [[ -n "$STAGING_DIR" && -d "$STAGING_DIR" ]]; then
        rm -rf "$STAGING_DIR"
    fi
}
trap cleanup_staging EXIT

get_current_theme() {
    [ -f "$CURRENT_PATH/.theme-name" ] && cat "$CURRENT_PATH/.theme-name" || echo ""
}

ensure_gtk_theme_name() {
    local ini="$1" gtk_theme="${2:-current}"
    mkdir -p "$(dirname "$ini")"
    if [[ -f "$ini" ]]; then
        if grep -q '^gtk-theme-name=' "$ini"; then
            sed -i "s/^gtk-theme-name=.*/gtk-theme-name=$gtk_theme/" "$ini"
        elif grep -q '^\[Settings\]' "$ini"; then
            sed -i "/^\[Settings\]/a gtk-theme-name=$gtk_theme" "$ini"
        else
            printf '\n[Settings]\ngtk-theme-name=%s\n' "$gtk_theme" >>"$ini"
        fi
    else
        printf '[Settings]\ngtk-theme-name=%s\n' "$gtk_theme" >"$ini"
    fi
}

activate_gtk() {
    local gtk_theme="current"
    ensure_gtk_theme_name "$HOME/.config/gtk-3.0/settings.ini" "$gtk_theme"
    ensure_gtk_theme_name "$HOME/.config/gtk-4.0/settings.ini" "$gtk_theme"

    local current_gtk="$THEME_DIR/current/gtk-4.0"
    if [ -d "$current_gtk" ]; then
        mkdir -p "$HOME/.config/gtk-4.0"
        ln -sf "$current_gtk/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"
        [ -f "$current_gtk/gtk-dark.css" ] && ln -sf "$current_gtk/gtk-dark.css" "$HOME/.config/gtk-4.0/gtk-dark.css"
        local assets_src="$current_gtk/assets"
        local assets_dst="$HOME/.config/gtk-4.0/assets"
        if [ -d "$assets_src" ] && ! paths_resolved_equal "$assets_src" "$assets_dst" 2>/dev/null; then
            ln -sfn "$assets_src" "$assets_dst"
        fi
    fi

    gsettings set org.gnome.desktop.interface gtk-theme "" 2>/dev/null || true
    sleep 0.5
    gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme" 2>/dev/null || true
}

build_theme() {
    local theme_name="$1"
    local source_path="$THEME_DIR/$theme_name"

    STAGING_DIR="$NEXT_PATH"
    rm -rf "$NEXT_PATH"
    mkdir -p "$NEXT_PATH"
    cp -a "$source_path/." "$NEXT_PATH/"
    echo "$theme_name" > "$NEXT_PATH/.theme-name"

    process_theme_templates "$NEXT_PATH"
    process_theme_template "$NEXT_PATH" "obsidian.css"
    process_theme_template "$NEXT_PATH" "colors.css"
    process_theme_template "$NEXT_PATH" "shoelace-hex.css"
    THEME_PATH="$NEXT_PATH" "$HOME/.local/bin/themes-set-gtk.sh"
    "$HOME/.local/bin/themes-generate-vscode.sh" "$NEXT_PATH"
}

promote_theme() {
    rm -rf "$CURRENT_PATH"
    mv "$NEXT_PATH" "$CURRENT_PATH"
    STAGING_DIR=""
}

activate_theme() {
    install_theme_manifest
    themes_sync_evo_shell
    activate_gtk

    local wallpaper
    wallpaper=$(themes_default_wallpaper || true)
    if [ -n "$wallpaper" ]; then
        "$HOME/.local/bin/evo-wallpaper.sh" set "$wallpaper"
    fi

    themes_sync_icon_theme_gsettings
    themes_sync_vscode_generated_extension
    themes_sync_obsidian_modular
    # GTK font settings only; theme.json was written by themes_sync_evo_shell.
    "$HOME/.local/bin/evo-font.sh" apply-gtk >/dev/null 2>&1 || true
}

notify_theme_switch() {
    local theme_name="$1"

    rm -rf "${HOME}/.cache/evo-shell/bar" 2>/dev/null || true

    local ghostty_addresses
    ghostty_addresses=$(hyprctl clients -j 2>/dev/null | jq -r '.[] | select(.class == "com.mitchellh.ghostty") | .address' 2>/dev/null) || true
    if [[ -n "$ghostty_addresses" ]]; then
        local current_window
        current_window=$(hyprctl activewindow -j 2>/dev/null | jq -r '.address' 2>/dev/null) || true
        while IFS= read -r address; do
            if [[ -n "$address" ]]; then
                hyprctl dispatch "hl.dsp.focus({ window = \"address:$address\" })" 2>/dev/null || true
                sleep 0.1
                hyprctl dispatch "hl.dsp.send_shortcut({ mods = \"CTRL SHIFT\", key = \"comma\", window = \"address:$address\" })" 2>/dev/null || true
            fi
        done <<< "$ghostty_addresses"
        if [[ -n "$current_window" ]]; then
            hyprctl dispatch "hl.dsp.focus({ window = \"address:$current_window\" })" 2>/dev/null || true
        fi
    fi

    hyprctl reload 2>/dev/null || true
    "$HOME/.local/bin/evo-menu-preview-warm.sh" 2>/dev/null &
    pkill -SIGUSR2 btop 2>/dev/null || true

    if [ -x "$HOME/.local/bin/themes-hook-post-switch" ]; then
        "$HOME/.local/bin/themes-hook-post-switch" "$theme_name" 2>/dev/null || true
    fi

    notify-send "Theme switched to $theme_name" 2>/dev/null || true
}

apply_theme() {
    local theme_name="$1"
    [ -z "$theme_name" ] && return 1
    [ -d "$THEME_DIR/$theme_name" ] || return 1

    build_theme "$theme_name"
    promote_theme
    activate_theme
}

COMMAND="${1:-select}"

case "$COMMAND" in
    select|"")
        trap - EXIT
        exec "$HOME/.local/bin/evo-shell-ipc" shell toggle evo.menu '{"submenu":"themes"}'
        ;;

    refresh)
        current_theme=$(get_current_theme)
        if [ -z "$current_theme" ]; then
            notify-send "Theme Refresh" "No current theme." 2>/dev/null || true
            exit 1
        fi
        apply_theme "$current_theme" || exit 1
        notify_theme_switch "$current_theme"
        ;;

    *)
        apply_theme "$COMMAND" || exit 1
        notify_theme_switch "$COMMAND"
        ;;
esac
