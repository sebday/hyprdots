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
LAUNCH_WALKER="${LAUNCH_WALKER:-$HOME/.local/bin/launch-walker}"

get_current_theme() {
    [ -f "$CURRENT_PATH/.theme-name" ] && cat "$CURRENT_PATH/.theme-name" || echo ""
}

activate_gtk() {
    local gtk_theme="current"
    if [ -f "$HOME/.config/gtk-3.0/settings.ini" ]; then
        sed -i "s/^gtk-theme-name=.*/gtk-theme-name=$gtk_theme/" "$HOME/.config/gtk-3.0/settings.ini"
    fi
    if [ -f "$HOME/.config/gtk-4.0/settings.ini" ]; then
        sed -i "s/^gtk-theme-name=.*/gtk-theme-name=$gtk_theme/" "$HOME/.config/gtk-4.0/settings.ini"
    fi
    local current_gtk="$THEME_DIR/current/gtk-4.0"
    if [ -d "$current_gtk" ]; then
        mkdir -p "$HOME/.config/gtk-4.0"
        ln -sf "$current_gtk/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"
        [ -f "$current_gtk/gtk-dark.css" ] && ln -sf "$current_gtk/gtk-dark.css" "$HOME/.config/gtk-4.0/gtk-dark.css"
        [ -d "$current_gtk/assets" ] && ln -sf "$current_gtk/assets" "$HOME/.config/gtk-4.0/assets"
    fi
    gsettings set org.gnome.desktop.interface gtk-theme "" 2>/dev/null || true
    sleep 0.5
    gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme" 2>/dev/null || true
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

    # Atomic swap
    rm -rf "$CURRENT_PATH"
    mv "$NEXT_PATH" "$CURRENT_PATH"

    # Set theme components (read from current/)
    "$HOME/.local/bin/themes-install-manifest.sh"
    activate_gtk
    "$HOME/.local/bin/wallpaper.sh" "next"
    "$HOME/.local/bin/themes-set-icons.sh"
    "$HOME/.local/bin/themes-set-vscode.sh"
    "$HOME/.local/bin/themes-set-walker.sh"
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

    if command -v walker >/dev/null 2>&1; then
        pkill -f "walker --gapplication-service" 2>/dev/null || true
        setsid env GSK_RENDERER=cairo walker --gapplication-service >/dev/null 2>&1 &
    fi

    # Post-switch hook (optional)
    if [ -x "$HOME/.local/bin/themes-hook-post-switch" ]; then
        "$HOME/.local/bin/themes-hook-post-switch" "$theme_name" 2>/dev/null || true
    fi

    notify-send "Theme switched to $theme_name" 2>/dev/null || true
}

COMMAND="${1:-select}"

case "$COMMAND" in
    select|"")
        # Theme list: Walker --dmenu (see LAUNCH_WALKER, same as menu-main)
        selected_theme=$(
            for theme_dir in "$THEME_DIR"/*; do
                [ ! -d "$theme_dir" ] && continue
                theme_name=$(basename "$theme_dir")
                [[ "$theme_name" == "current" || "$theme_name" == "shared" ]] && continue
                echo "$theme_name"
            done | "$LAUNCH_WALKER" --dmenu --width 420 --minheight 1 --maxheight 480 -p "Select a theme: "
        )
        if [ -z "$selected_theme" ]; then
            exit 0
        fi

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
