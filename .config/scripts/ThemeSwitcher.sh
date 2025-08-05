#!/bin/bash

# Define directories
THEME_DIR="$HOME/.themes"
CURRENT_THEME_LINK="$HOME/.themes/current"
GTK2_CONFIG_FILE="$HOME/.gtkrc-2.0"
GTK3_CONFIG_FILE="$HOME/.config/gtk-3.0/settings.ini"
GTK4_CONFIG_DIR="$HOME/.config/gtk-4.0"
GTK4_CONFIG_FILE="$HOME/.config/gtk-4.0/settings.ini"
XSETTINGS_CONFIG_FILE="$HOME/.config/xsettingsd/xsettingsd.conf"
BTOP_CONFIG_FILE="$HOME/.config/btop/btop.conf"
MAKO_CONFIG_FILE="$HOME/.config/mako/config"
FUZZEL_CONFIG_FILE="$HOME/.config/fuzzel/fuzzel.ini"
CURSOR_CONFIG_FILE="$HOME/.config/Cursor/User/settings.json"
OBSIDIAN_CONFIG_FILE="$HOME/OneDrive/Notes/.obsidian/appearance.json"
OBSIDIAN_SNIPPET_FILE="$HOME/OneDrive/Notes/.obsidian/snippets/custom-background.css"
WALLPAPER_SCRIPT="$HOME/.config/scripts/Wallpaper.sh"
THUMBNAILS_SCRIPT="$HOME/.config/scripts/Thumbnails.sh"

# Source the shared thumbnail utilities
source "$THUMBNAILS_SCRIPT"

# Use fuzzel to select a theme, using thumbnails from wallpaper files
selected_entry=$(
    (
        for theme_dir in "$THEME_DIR"/*; do
            if [ -d "$theme_dir" ] && [ "$(basename "$theme_dir")" != "current" ] && [ "$(basename "$theme_dir")" != "shared" ]; then
                theme_name=$(basename "$theme_dir")
                
                # Find any image file from the wallpapers subfolder (alphabetically sorted)
                wallpaper_file=""
                wallpapers_dir="$theme_dir/wallpapers"
                if [ -d "$wallpapers_dir" ]; then
                    wallpaper_file=$(find "$wallpapers_dir" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) | sort | head -n 1)
                fi
                
                printf "%s\t%s\n" "$theme_name" "$wallpaper_file"
            fi
        done
    ) | generate_fuzzel_thumbnails "theme" | fuzzel -d -l 8 -p "Select a theme: "
)



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

# Update icon theme from .conf file
ICON_THEME_FILE="$CURRENT_THEME_LINK/icons.conf"
if [ -f "$ICON_THEME_FILE" ]; then
    # Source the icon theme file to get the variables
    source "$ICON_THEME_FILE"
    
    # Apply via gsettings and update config file
    [ -n "$icon_theme" ] && gsettings set org.gnome.desktop.interface icon-theme "$icon_theme"
    [ -n "$icon_theme" ] && sed -i "s|^gtk-icon-theme-name=.*|gtk-icon-theme-name=$icon_theme|" "$GTK3_CONFIG_FILE"
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
OBSIDIAN_THEME_FILE="$CURRENT_THEME_LINK/obsidian.conf"
if [ -f "$OBSIDIAN_THEME_FILE" ] && [ -f "$OBSIDIAN_CONFIG_FILE" ]; then
    # Source the obsidian theme file to get the theme name and css
    source "$OBSIDIAN_THEME_FILE"
    
    if [ -n "$obsidian_theme" ]; then
        # Update the cssTheme and theme lines in Obsidian's appearance.json
        sed -i "s|\"cssTheme\":.*|\"cssTheme\": \"$obsidian_theme\",|" "$OBSIDIAN_CONFIG_FILE"
        sed -i "s|\"theme\":.*|\"theme\": \"$theme\",|" "$OBSIDIAN_CONFIG_FILE"
    fi

    # Update the custom CSS snippet file
    if [ -n "$obsidian_css" ]; then
        echo "$obsidian_css" > "$OBSIDIAN_SNIPPET_FILE"
    else
        # Clear the file if no CSS is provided
        > "$OBSIDIAN_SNIPPET_FILE"
    fi
fi


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
reload_ghostty_windows
reload_obsidian
makoctl reload
pkill -SIGUSR2 btop
pkill -SIGUSR2 waybar

notify-send "Theme Switcher" "Set to $selected_theme"
