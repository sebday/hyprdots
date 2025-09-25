#!/bin/bash

# Define directories
THEME_DIR="$HOME/.themes"
OOMOX_THEME_DIR="$HOME/.themes/shared/oomox"
CURRENT_THEME_LINK="$HOME/.themes/current"
WALLPAPER_SCRIPT="$HOME/.local/bin//wallpaper.sh"
GTK2_CONFIG_FILE="$HOME/.gtkrc-2.0"
GTK3_CONFIG_FILE="$HOME/.config/gtk-3.0/settings.ini"
GTK4_CONFIG_DIR="$HOME/.config/gtk-4.0"
GTK4_CONFIG_FILE="$HOME/.config/gtk-4.0/settings.ini"
XSETTINGS_CONFIG_FILE="$HOME/.config/xsettingsd/xsettingsd.conf"
HYPR_CONFIG_FILE="$HOME/.config/hypr/looks.conf"
BTOP_CONFIG_FILE="$HOME/.config/btop/btop.conf"
MAKO_CONFIG_FILE="$HOME/.config/mako/config"
FUZZEL_CONFIG_FILE="$HOME/.config/fuzzel/fuzzel.ini"
CURSOR_CONFIG_FILE="$HOME/.config/Cursor/User/settings.json"
OBSIDIAN_VAULT_DIR="$HOME/OneDrive/Notes"

# Source the shared fuzzel utilities
FUZZEL_HELPERS="$HOME/.local/bin//thumbnails.sh"
if [ -f "$FUZZEL_HELPERS" ]; then
    source "$FUZZEL_HELPERS"
fi

# Function to generate the list of themes for fuzzel
generate_theme_list() {
    for theme_dir in "$THEME_DIR"/*; do
        if [ -d "$theme_dir" ] && [ "$(basename "$theme_dir")" != "current" ] && [ "$(basename "$theme_dir")" != "shared" ]; then
            theme_name=$(basename "$theme_dir")
            
            # Find the first wallpaper image to use as a thumbnail
            wallpaper_file=""
            wallpapers_dir="$theme_dir/wallpapers"
            if [ -d "$wallpapers_dir" ]; then
                wallpaper_file=$(find "$wallpapers_dir" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) -print -quit)
            fi
            
            # Output in "theme_name<tab>wallpaper_path" format
            printf "%s\t%s\n" "$theme_name" "$wallpaper_file"
        fi
    done
}

# Use fuzzel to select a theme, using thumbnails from wallpaper files
selected_entry=$(generate_theme_list | generate_fuzzel_entries_with_thumbs "theme" | fuzzel -d -p "Select a theme: ")

# Exit if no theme is selected
if [ -z "$selected_entry" ]; then
    exit 0
fi

# Trim leading spaces from selection to get the theme name
selected_theme=$(echo "$selected_entry" | sed 's/^[[:space:]]*//')

# --- Update GTK theme ---
if [ -f "$GTK2_CONFIG_FILE" ]; then
    sed -i "s|^gtk-theme-name=.*|gtk-theme-name=\"$selected_theme\"|" "$GTK2_CONFIG_FILE"
fi

if [ -f "$GTK3_CONFIG_FILE" ]; then
    sed -i "s|^gtk-theme-name=.*|gtk-theme-name=$selected_theme|" "$GTK3_CONFIG_FILE"
fi

if [ -f "$GTK4_CONFIG_FILE" ]; then
    sed -i "s|^gtk-theme-name=.*|gtk-theme-name=$selected_theme|" "$GTK4_CONFIG_FILE"
fi

if [ -d "$GTK4_CONFIG_DIR" ]; then
    rm -f "$GTK4_CONFIG_DIR/assets" "$GTK4_CONFIG_DIR/gtk.css" "$GTK4_CONFIG_DIR/gtk-dark.css"
    ln -sfn "$THEME_DIR/$selected_theme/gtk-4.0/assets" "$GTK4_CONFIG_DIR/assets"
    ln -sfn "$THEME_DIR/$selected_theme/gtk-4.0/gtk.css" "$GTK4_CONFIG_DIR/gtk.css"
    ln -sfn "$THEME_DIR/$selected_theme/gtk-4.0/gtk-dark.css" "$GTK4_CONFIG_DIR/gtk-dark.css"
fi

if [ -f "$XSETTINGS_CONFIG_FILE" ]; then
    sed -i "s|^Net/ThemeName.*|Net/ThemeName \"$selected_theme\"|" "$XSETTINGS_CONFIG_FILE"
fi

# Apply the theme using gsettings (the nwg-look way)
gsettings set org.gnome.desktop.interface gtk-theme "$selected_theme"

# Update the symbolic link for other configs
ln -sfn "$HOME/.themes/$selected_theme" "$CURRENT_THEME_LINK"

# Update wallpaper using any image from the theme's wallpapers folder (alphabetically sorted)
if [ -f "$WALLPAPER_SCRIPT" ]; then
    wallpapers_dir="$THEME_DIR/$selected_theme/wallpapers"
    if [ -d "$wallpapers_dir" ]; then
        theme_wallpaper=$(find "$wallpapers_dir" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) | sort | head -n 1)
        if [ -n "$theme_wallpaper" ] && [ -f "$theme_wallpaper" ]; then
            "$WALLPAPER_SCRIPT" "$theme_wallpaper"
        fi
    fi
fi

# Update icon theme from index.theme file
INDEX_THEME_FILE="$CURRENT_THEME_LINK/index.theme"
if [ -f "$INDEX_THEME_FILE" ]; then
    # Parse the icon theme name from the index.theme file
    icon_theme=$(grep -i '^IconTheme=' "$INDEX_THEME_FILE" | cut -d'=' -f2)
    
    if [ -n "$icon_theme" ]; then
        # Apply via gsettings and update config files for all GTK versions
        gsettings set org.gnome.desktop.interface icon-theme "$icon_theme"
        
        # Update GTK2 config
        if [ -f "$GTK2_CONFIG_FILE" ]; then
            sed -i "s|^gtk-icon-theme-name=.*|gtk-icon-theme-name=\"$icon_theme\"|" "$GTK2_CONFIG_FILE"
        fi
        
        # Update GTK3 config
        sed -i "s|^gtk-icon-theme-name=.*|gtk-icon-theme-name=$icon_theme|" "$GTK3_CONFIG_FILE"
        
        # Update GTK4 config
        if [ -f "$GTK4_CONFIG_FILE" ]; then
            sed -i "s|^gtk-icon-theme-name=.*|gtk-icon-theme-name=$icon_theme|" "$GTK4_CONFIG_FILE"
        fi
    fi
fi

# Update btop theme
BTHEME_CONFIG_FILE="$CURRENT_THEME_LINK/btop.conf"
if [ -f "$BTHEME_CONFIG_FILE" ]; then
    # Source the config file to get the btop_theme variable
    source "$BTHEME_CONFIG_FILE"
    
    if [ -n "$btop_theme" ]; then
        # Update the color_theme line in btop config
        sed -i "s|^color_theme =.*|color_theme = \"$btop_theme\"|" "$BTOP_CONFIG_FILE"
    fi
fi

# Update mako theme
MAKO_THEME_FILE="$CURRENT_THEME_LINK/mako.conf"
if [ -f "$MAKO_THEME_FILE" ]; then
    # Source the mako theme file to get color variables
    source "$MAKO_THEME_FILE"
    
    # Update mako config with theme colors
    sed -i "s|^background-color=.*|background-color=$background_color|" "$MAKO_CONFIG_FILE"
    sed -i "s|^text-color=.*|text-color=$text_color|" "$MAKO_CONFIG_FILE"
    sed -i "s|^border-color=.*|border-color=$border_color|" "$MAKO_CONFIG_FILE"
    sed -i "s|^progress-color=.*|progress-color=$progress_color|" "$MAKO_CONFIG_FILE"
fi

# Update Cursor theme
CURSOR_THEME_FILE="$CURRENT_THEME_LINK/cursor.conf"
if [ -f "$CURSOR_THEME_FILE" ] && [ -f "$CURSOR_CONFIG_FILE" ]; then
    # Source the cursor theme file to get the theme name
    source "$CURSOR_THEME_FILE"
    
    if [ -n "$cursor_theme" ]; then
        # Update the workbench.colorTheme line in Cursor settings
        sed -i "s|\"workbench.colorTheme\":.*|\"workbench.colorTheme\": \"$cursor_theme\",|" "$CURSOR_CONFIG_FILE"
    fi
fi

# Update fuzzel theme
FUZZEL_THEME_FILE="$CURRENT_THEME_LINK/fuzzel.conf"
if [ -f "$FUZZEL_THEME_FILE" ]; then
    # Source the fuzzel theme file to get color variables
    source "$FUZZEL_THEME_FILE"
    
    # Update fuzzel config with theme colors
    sed -i "s|^background=.*|background=$fuzzel_background|" "$FUZZEL_CONFIG_FILE"
    sed -i "s|^text=.*|text=$fuzzel_text|" "$FUZZEL_CONFIG_FILE"
    sed -i "s|^match=.*|match=$fuzzel_match|" "$FUZZEL_CONFIG_FILE"
    sed -i "s|^selection=.*|selection=$fuzzel_selection|" "$FUZZEL_CONFIG_FILE"
    sed -i "s|^selection-match=.*|selection-match=$fuzzel_selection_match|" "$FUZZEL_CONFIG_FILE"
    sed -i "s|^selection-text=.*|selection-text=$fuzzel_selection_text|" "$FUZZEL_CONFIG_FILE"
    sed -i "s|^border=.*|border=$fuzzel_border|" "$FUZZEL_CONFIG_FILE"
fi

# Update Obsidian theme
OBSIDIAN_CONFIG_FILE="$OBSIDIAN_VAULT_DIR/.obsidian/appearance.json"
OBSIDIAN_VAULT_THEMES_DIR="$OBSIDIAN_VAULT_DIR/.obsidian/themes"
THEME_CSS_FILE="$CURRENT_THEME_LINK/obsidian.css"

if [ -f "$THEME_CSS_FILE" ]; then
    # --- New Modular Theme Logic ---
    MODULAR_THEME_NAME="Modular"
    MODULAR_THEME_DIR="$OBSIDIAN_VAULT_THEMES_DIR/$MODULAR_THEME_NAME"
    SHARED_CSS_FILE="$THEME_DIR/shared/obsidian.css"

    # Ensure the modular theme directory exists
    mkdir -p "$MODULAR_THEME_DIR"

    # Create a manifest.json if it doesn't exist, by copying the shared one
    SHARED_MANIFEST_FILE="$THEME_DIR/shared/obsidian.conf"
    if [ ! -f "$MODULAR_THEME_DIR/manifest.json" ] && [ -f "$SHARED_MANIFEST_FILE" ]; then
        cp "$SHARED_MANIFEST_FILE" "$MODULAR_THEME_DIR/manifest.json"
    fi

    # Combine theme-specific and shared CSS into the modular theme's css file
    if [ -f "$SHARED_CSS_FILE" ] && [ -f "$THEME_CSS_FILE" ]; then
        cat "$THEME_CSS_FILE" "$SHARED_CSS_FILE" > "$MODULAR_THEME_DIR/theme.css"
    fi

    # Ensure config file and directories exist
    OBSIDIAN_CONFIG_DIR=$(dirname "$OBSIDIAN_CONFIG_FILE")
    mkdir -p "$OBSIDIAN_CONFIG_DIR"

    # Read existing config or create a default one
    local updated_json
    if [ -f "$OBSIDIAN_CONFIG_FILE" ]; then
        updated_json=$(cat "$OBSIDIAN_CONFIG_FILE")
    else
        updated_json='{}'
    fi

    # Set the theme to "Modular" and remove snippet settings
    updated_json=$(echo "$updated_json" | jq --arg theme "obsidian" '.theme = $theme' | jq --arg cssTheme "$MODULAR_THEME_NAME" '.cssTheme = $cssTheme' | jq 'del(.enabledCssSnippets)')

    # Write the updated json to the config file
    echo "$updated_json" > "$OBSIDIAN_CONFIG_FILE"
fi

# Update Hyprland border colors
HYPR_THEME_FILE="$CURRENT_THEME_LINK/hypr.conf"
if [ -f "$HYPR_THEME_FILE" ]; then
    # Extract color variables without sourcing
    col_active_border=$(grep "^\$col_active_border" "$HYPR_THEME_FILE" | cut -d '=' -f 2- | sed 's/^[[:space:]]*//')
    col_inactive_border=$(grep "^\$col_inactive_border" "$HYPR_THEME_FILE" | cut -d '=' -f 2- | sed 's/^[[:space:]]*//')
    
    # Update hyprland config with theme colors
    sed -i "s|^[[:space:]]*col\.active_border =.*|    col.active_border = $col_active_border|" "$HYPR_CONFIG_FILE"
    sed -i "s|^[[:space:]]*col\.inactive_border =.*|    col.inactive_border = $col_inactive_border|" "$HYPR_CONFIG_FILE"
fi

# Function to reload ghostty windows
reload_ghostty_windows() {
    # Get all ghostty window addresses
    local ghostty_addresses=$(hyprctl clients -j | jq -r '.[] | select(.class == "com.mitchellh.ghostty") | .address')
    
    if [[ -n "$ghostty_addresses" ]]; then
        # Save current active window
        local current_window=$(hyprctl activewindow -j | jq -r '.address')
        
        # Send reload keybind to each ghostty window
        while IFS= read -r address; do
            if [[ -n "$address" ]]; then
                hyprctl dispatch focuswindow "address:$address"
                sleep 0.1
                # Send Ctrl+Shift+, (reload config shortcut)
                hyprctl dispatch sendshortcut "CTRL SHIFT, comma, address:$address"
            fi
        done <<< "$ghostty_addresses"
        
        # Return focus to original window
        if [[ -n "$current_window" ]]; then
            hyprctl dispatch focuswindow "address:$current_window"
        fi
    fi
}

# Function to reload obsidian gracefully
reload_obsidian() {
    xdg-open "obsidian://command?id=app%3Areload"
}

# Reload all applications
pkill -SIGUSR2 waybar
reload_ghostty_windows
reload_obsidian
makoctl reload
hyprctl reload
pkill -SIGUSR2 btop

notify-send "Theme Switcher" "Set to $selected_theme"
