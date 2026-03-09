#!/bin/bash

# A unified script for managing themes in Hyprland
#
# USAGE:
#   themes-switch.sh select   - Open a menu to select a theme
#   themes-switch.sh next     - Cycle to the next theme
#   themes-switch.sh prev     - Cycle to the previous theme
#   themes-switch.sh refresh  - Regenerate configs for current theme (after cleanup)

THEME_DIR="$HOME/.themes"
CURRENT_PATH="$THEME_DIR/current"
TEMPLATES_DIR="$THEME_DIR/shared/templates"

get_current_theme() {
    if [ -f "$CURRENT_PATH/.theme-name" ]; then
        cat "$CURRENT_PATH/.theme-name"
    elif [ -L "$CURRENT_PATH" ]; then
        basename "$(readlink -f "$CURRENT_PATH")"
    else
        echo ""
    fi
}

# Process templates from colors.toml (omarchy-style)
process_templates() {
    local theme_dir="$1"
    local toml="$theme_dir/colors.toml"
    [ ! -f "$toml" ] && return

    local sed_script
    sed_script=$(mktemp)

    while IFS='=' read -r key value; do
        key="${key//[\"\' ]/}"
        [[ $key && $key != \#* ]] || continue
        value="${value#*[\"\']}"
        value="${value%%[\"\']*}"
        printf 's|{{ %s }}|%s|g\n' "$key" "$value" >> "$sed_script"
        printf 's|{{ %s_strip }}|%s|g\n' "$key" "${value#\#}" >> "$sed_script"
        if [[ $value =~ ^# ]]; then
            local hex="${value#\#}"
            printf 's|{{ %s_rgb }}|%d,%d,%d|g\n' "$key" "$(( 0x${hex:0:2} ))" "$(( 0x${hex:2:2} ))" "$(( 0x${hex:4:2} ))" >> "$sed_script"
        fi
    done < "$toml"

    # Add icon_path from icons.theme for mako.ini
    local icon_path="/home/seb/.local/share/icons/Adwaita"
    if [ -f "$theme_dir/icons.theme" ]; then
        local icon_name
        icon_name=$(tr -d '\n' < "$theme_dir/icons.theme" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [ -n "$icon_name" ] && icon_path="/home/seb/.local/share/icons/$icon_name"
    fi
    printf 's|{{ icon_path }}|%s|g\n' "$icon_path" >> "$sed_script"

    for tpl in "$TEMPLATES_DIR"/*.tpl; do
        [ -f "$tpl" ] || continue
        local filename
        filename=$(basename "$tpl" .tpl)
        local output="$theme_dir/$filename"
        # hyprland.conf goes to stable path to avoid globbing error when current/ is rebuilt
        if [ "$filename" = "hyprland.conf" ]; then
            output="$HOME/.config/hypr/theme.conf"
        fi
        [ -f "$output" ] && [ "$filename" != "hyprland.conf" ] && continue
        sed -f "$sed_script" "$tpl" > "$output"
    done

    rm -f "$sed_script"
}

# Function to apply a theme
apply_theme() {
    local theme_name="$1"
    local source_path="$THEME_DIR/$theme_name"

    # Rebuild current dir: copy source, then generate templates (omarchy-style staging)
    rm -rf "$CURRENT_PATH"
    mkdir -p "$CURRENT_PATH"
    cp -a "$source_path/." "$CURRENT_PATH/"
    echo "$theme_name" > "$CURRENT_PATH/.theme-name"

    # Generate configs from templates into current/
    process_templates "$CURRENT_PATH"

    # Set GTK theme
    gsettings set org.gnome.desktop.interface gtk-theme "$theme_name"

    # Update GTK config files
    if [ -f "$HOME/.config/gtk-3.0/settings.ini" ]; then
        sed -i "s/^gtk-theme-name=.*/gtk-theme-name=$theme_name/" "$HOME/.config/gtk-3.0/settings.ini"
    fi
    if [ -f "$HOME/.config/gtk-4.0/settings.ini" ]; then
        sed -i "s/^gtk-theme-name=.*/gtk-theme-name=$theme_name/" "$HOME/.config/gtk-4.0/settings.ini"
    fi
    # Link GTK-4.0 assets and css to ensure apps like Ghostty pick up the theme
    if [ -d "$CURRENT_PATH/gtk-4.0" ]; then
        mkdir -p "$HOME/.config/gtk-4.0"
        ln -sf "$CURRENT_PATH/gtk-4.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"
        if [ -f "$CURRENT_PATH/gtk-4.0/gtk-dark.css" ]; then
            ln -sf "$CURRENT_PATH/gtk-4.0/gtk-dark.css" "$HOME/.config/gtk-4.0/gtk-dark.css"
        fi
        if [ -d "$CURRENT_PATH/gtk-4.0/assets" ]; then
            ln -sf "$CURRENT_PATH/gtk-4.0/assets" "$HOME/.config/gtk-4.0/assets"
        fi
    fi   
    
    # Set theme components
    "$HOME/.local/bin/wallpaper.sh" "next"
    "$HOME/.local/bin/themes-set-icons.sh"
    "$HOME/.local/bin/themes-set-btop.sh"
    "$HOME/.local/bin/themes-set-yazi.sh"
    "$HOME/.local/bin/themes-set-neovim-icons.sh"
    "$HOME/.local/bin/themes-set-mako.sh"
    "$HOME/.local/bin/themes-set-cursor.sh"
    "$HOME/.local/bin/themes-set-fuzzel.sh"
    "$HOME/.local/bin/themes-set-obsidian.sh"
    
    # Reload applications
    reload_ghostty_windows() {
        local ghostty_addresses=$(hyprctl clients -j | jq -r '.[] | select(.class == "com.mitchellh.ghostty") | .address')
        if [[ -n "$ghostty_addresses" ]]; then
            local current_window=$(hyprctl activewindow -j | jq -r '.address')
            while IFS= read -r address; do
                if [[ -n "$address" ]]; then
                    hyprctl dispatch focuswindow "address:$address"
                    sleep 0.1
                    hyprctl dispatch sendshortcut "CTRL SHIFT, comma, address:$address"
                fi
            done <<< "$ghostty_addresses" 
            if [[ -n "$current_window" ]]; then
                hyprctl dispatch focuswindow "address:$current_window"
            fi
        fi
    }
    
    reload_obsidian() {
        xdg-open "obsidian://command?id=app%3Areload"
    }
    
    reload_ghostty_windows
    reload_obsidian
    makoctl reload
    hyprctl reload
    pkill -SIGUSR2 waybar
    pkill -SIGUSR2 btop
    
    notify-send "Theme switched to $theme_name"
}

COMMAND=${1:-select}

case "$COMMAND" in
    select)
        # Interactive theme selection with fuzzel
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
        
        apply_theme "$selected_theme"
        ;;
    
    next|prev)
        # Cycle through themes
        mapfile -t themes < <(
            for theme_dir in "$THEME_DIR"/*; do
                if [ -d "$theme_dir" ]; then
                    theme_name=$(basename "$theme_dir")
                    if [[ "$theme_name" != "current" && "$theme_name" != "shared" ]]; then
                        echo "$theme_name"
                    fi
                fi
            done | sort
        )
        
        if [ ${#themes[@]} -eq 0 ]; then
            notify-send "Theme Cycler" "No themes found."
            exit 0
        fi
        
        # Get current theme
        current_theme=$(get_current_theme)
        
        # Find current theme index
        current_idx=-1
        if [ -n "$current_theme" ]; then
            for i in "${!themes[@]}"; do
                if [[ "${themes[$i]}" == "$current_theme" ]]; then
                    current_idx=$i
                    break
                fi
            done
        fi
        
        # Determine target theme
        target_idx=0
        if [ "$current_idx" -ne -1 ]; then
            if [[ "$COMMAND" == "next" ]]; then
                target_idx=$(( (current_idx + 1) % ${#themes[@]} ))
            elif [[ "$COMMAND" == "prev" ]]; then
                target_idx=$(( (current_idx - 1 + ${#themes[@]}) % ${#themes[@]} ))
            fi
        else
            # If current not found, start from beginning or end
            [[ "$COMMAND" == "prev" ]] && target_idx=$(( ${#themes[@]} - 1 ))
        fi
        
        apply_theme "${themes[$target_idx]}"
        ;;

    refresh)
        current_theme=$(get_current_theme)
        if [ -z "$current_theme" ]; then
            notify-send "Theme Refresh" "No current theme."
            exit 1
        fi
        apply_theme "$current_theme"
        ;;
    
    *)
        echo "Usage: $0 [select|next|prev|refresh]"
        exit 1
        ;;
esac

exit 0
