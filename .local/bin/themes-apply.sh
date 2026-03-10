#!/bin/bash
set -e
# Apply a theme: build into staging, atomic swap, run setters, reload apps
#
# USAGE:
#   themes-apply.sh [select]  - Open menu to select a theme (default)
#   themes-apply.sh refresh   - Regenerate configs for current theme
#   themes-apply.sh <name>     - Apply theme by name

THEME_DIR="${THEME_DIR:-$HOME/.themes}"
CURRENT_PATH="${CURRENT_PATH:-$THEME_DIR/current}"
NEXT_PATH="${NEXT_PATH:-$THEME_DIR/next}"

get_current_theme() {
    [ -f "$CURRENT_PATH/.theme-name" ] && cat "$CURRENT_PATH/.theme-name" || echo ""
}

apply_theme() {
    local theme_name="$1"
    [ -z "$theme_name" ] && return 1

    local source_path="$THEME_DIR/$theme_name"
    [ ! -d "$source_path" ] && return 1

    # Build into staging dir (atomic: only swap on success)
    rm -rf "$NEXT_PATH"
    mkdir -p "$NEXT_PATH"
    cp -a "$source_path/." "$NEXT_PATH/"
    echo "$theme_name" > "$NEXT_PATH/.theme-name"

    # Generate configs from templates into staging
    "$HOME/.local/bin/themes-process-templates.sh" "$NEXT_PATH"

    # Generate GTK theme into staging (THEME_PATH=next for build)
    THEME_PATH="$NEXT_PATH" "$HOME/.local/bin/themes-set-gtk.sh"

    # Generate VS Code theme extension from colors.toml (Catppuccin Mocha base)
    "$HOME/.local/bin/themes-generate-vscode.sh" "$NEXT_PATH"

    # Generate Neovim theme from colors.toml (Modular palette)
    "$HOME/.local/bin/themes-generate-neovim.sh" "$NEXT_PATH"

    # Atomic swap
    rm -rf "$CURRENT_PATH"
    mv "$NEXT_PATH" "$CURRENT_PATH"

    # Set theme components (read from current/)
    "$HOME/.local/bin/themes-install-manifest.sh"
    "$HOME/.local/bin/themes-activate-gtk.sh"
    "$HOME/.local/bin/wallpaper.sh" "next"
    "$HOME/.local/bin/themes-set-icons.sh"
    "$HOME/.local/bin/themes-set-cursor.sh"
    "$HOME/.local/bin/themes-set-fuzzel.sh"
    "$HOME/.local/bin/themes-set-obsidian.sh"
}

reload_apps() {
    local theme_name="$1"

    # Reload Ghostty windows
    local ghostty_addresses
    ghostty_addresses=$(hyprctl clients -j 2>/dev/null | jq -r '.[] | select(.class == "com.mitchellh.ghostty") | .address' 2>/dev/null) || true
    if [[ -n "$ghostty_addresses" ]]; then
        local current_window
        current_window=$(hyprctl activewindow -j 2>/dev/null | jq -r '.address' 2>/dev/null) || true
        while IFS= read -r address; do
            if [[ -n "$address" ]]; then
                hyprctl dispatch focuswindow "address:$address" 2>/dev/null || true
                sleep 0.1
                hyprctl dispatch sendshortcut "CTRL SHIFT, comma, address:$address" 2>/dev/null || true
            fi
        done <<< "$ghostty_addresses"
        if [[ -n "$current_window" ]]; then
            hyprctl dispatch focuswindow "address:$current_window" 2>/dev/null || true
        fi
    fi
    
    makoctl reload 2>/dev/null || true
    hyprctl reload 2>/dev/null || true
    pkill waybar 2>/dev/null; waybar &
    pkill -SIGUSR2 btop 2>/dev/null || true

    # Post-switch hook (optional)
    if [ -x "$HOME/.local/bin/themes-hook-post-switch" ]; then
        "$HOME/.local/bin/themes-hook-post-switch" "$theme_name" 2>/dev/null || true
    fi

    notify-send "Theme switched to $theme_name" 2>/dev/null || true
}

COMMAND="${1:-select}"

case "$COMMAND" in
    select|"")
        source "$HOME/.local/bin/thumbnails.sh"

        generate_theme_list() {
            for theme_dir in "$THEME_DIR"/*; do
                if [ -d "$theme_dir" ] && [ "$(basename "$theme_dir")" != "current" ] && [ "$(basename "$theme_dir")" != "shared" ]; then
                    theme_name=$(basename "$theme_dir")
                    preview_file="$theme_dir/preview.png"
                    printf "%s\t%s\n" "$theme_name" "$preview_file"
                fi
            done
        }

        selected_entry=$(generate_theme_list | generate_fuzzel_entries_with_thumbs "theme" | fuzzel -d -p "Select a theme: ")
        if [ -z "$selected_entry" ]; then
            exit 0
        fi
        selected_theme=$(echo "$selected_entry" | sed 's/^[[:space:]]*//')

        apply_theme "$selected_theme" || exit 1
        reload_apps "$selected_theme"
        ;;

    refresh)
        current_theme=$(get_current_theme)
        if [ -z "$current_theme" ]; then
            notify-send "Theme Refresh" "No current theme." 2>/dev/null || true
            exit 1
        fi
        apply_theme "$current_theme" || exit 1
        reload_apps "$current_theme"
        ;;

    *)
        # Direct theme name
        apply_theme "$COMMAND" || exit 1
        reload_apps "$COMMAND"
        ;;
esac
