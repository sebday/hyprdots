#!/usr/bin/env bash

set -Eeo pipefail

REPO_DIR="/home/seb/.config/scripts/ThemeGenerate"
SRC_DIR="${REPO_DIR}"

source "${REPO_DIR}/gtkrc.sh"

ROOT_UID=0
DEST_DIR=

# Destination directory
if [ "$UID" -eq "$ROOT_UID" ]; then
	DEST_DIR="/usr/share/themes"
else
	DEST_DIR="$HOME/.themes"
fi

SASSC_OPT="-M -t expanded"
THEME_NAME='Osaka-Jade'

# Function to read colors from colours.css and create a sass palette
create_osaka_jade_palette() {
    local colours_file="$HOME/.themes/osaka-jade/colours.css"
    local palette_file="${SRC_DIR}/sass/_osaka-jade-palette.scss"

    if [ ! -f "$colours_file" ]; then
        echo "ERROR: ${colours_file} not found, aborting."
        exit 1
    fi

    echo "// Osaka-Jade Color Palette" > "$palette_file"
    echo "" >> "$palette_file"

    # Extract colors and convert to sass variables
    local bg_primary=$(grep -oP '(?<=--bg-primary: ).*?(?=;)' "$colours_file")
    local text_primary=$(grep -oP '(?<=--text-primary: ).*?(?=;)' "$colours_file")
    local accent_cyan=$(grep -oP '(?<=--accent-cyan: ).*?(?=;)' "$colours_file")
    local white=$(grep -oP '(?<=--white: ).*?(?=;)' "$colours_file")
    local bg_light=$(grep -oP '(?<=--bg-light: ).*?(?=;)' "$colours_file")
    local green=$(grep -oP '(?<=--green: ).*?(?=;)' "$colours_file")
    local orange=$(grep -oP '(?<=--orange: ).*?(?=;)' "$colours_file")
    local red=$(grep -oP '(?<=--red: ).*?(?=;)' "$colours_file")
    local accent_light=$(grep -oP '(?<=--accent-light: ).*?(?=;)' "$colours_file")

    echo "\$bg_color: $bg_primary;" >> "$palette_file"
    echo "\$fg_color: $text_primary;" >> "$palette_file"
    echo "" >> "$palette_file"
    echo "\$primary_color: $accent_cyan;" >> "$palette_file"
    echo "\$secondary_color: $accent_cyan;" >> "$palette_file"
    echo "\$tertiary_color: $accent_light;" >> "$palette_file"
    echo "" >> "$palette_file"
    echo "// Misc Colors" >> "$palette_file"
    echo "\$red: $red;" >> "$palette_file"
    echo "\$green: $green;" >> "$palette_file"
    echo "\$yellow: $orange;" >> "$palette_file"
    echo "\$blue: $accent_cyan;" >> "$palette_file"
    echo "\$cyan: $accent_cyan;" >> "$palette_file"
    echo "\$magenta: $accent_light;" >> "$palette_file"
    echo "\$orange: $orange;" >> "$palette_file"
    echo "\$white: $white;" >> "$palette_file"
    echo "\$grey: $bg_light;" >> "$palette_file"
    echo "\$black: $bg_primary;" >> "$palette_file"
    echo "" >> "$palette_file"
    echo "// Main background colors" >> "$palette_file"
    echo "\$bg_darker: darken(\$bg_color, 2%);" >> "$palette_file"
    echo "\$bg_dark: darken(\$bg_color, 1%);" >> "$palette_file"
    echo "\$bg_light: lighten(\$bg_color, 15%);" >> "$palette_file"
    echo "\$bg_lighter: lighten(\$bg_color, 33%);" >> "$palette_file"
    echo "\$bg_lightest: lighten(\$bg_color, 67%);" >> "$palette_file"
    echo "" >> "$palette_file"
    echo "// Main foreground colors" >> "$palette_file"
    echo "\$fg_darker: darken(\$fg_color, 40%);" >> "$palette_file"
    echo "\$fg_dark: darken(\$fg_color, 20%);" >> "$palette_file"
    echo "\$fg_light: lighten(\$fg_color, 10%);" >> "$palette_file"
    echo "\$fg_lighter: lighten(\$fg_color, 20%);" >> "$palette_file"
    echo "\$fg_lightest: lighten(\$fg_color, 30%);" >> "$palette_file"

    echo "\$default-dark: \$bg_color;" >> "$palette_file"
}

# Create a temporary tweaks file that imports our custom palette
create_temp_tweaks() {
	cp -rf "${SRC_DIR}/sass/_tweaks.scss" "${SRC_DIR}/sass/_tweaks-temp.scss"
	sed -i 's|@import "color-palette-default";|@import "osaka-jade-palette";|' "${SRC_DIR}/sass/_tweaks-temp.scss"
}

install_theme() {
	local dest="$DEST_DIR"
	local name="$THEME_NAME"
	local color="-Dark" # Hardcode to dark variant
	local theme="" # No color accents
	local size="" # Standard size
	local ctype="" # No storm/moon colorscheme

	local THEME_DIR="${dest}/${name}"

	[[ -d "${THEME_DIR}" ]] && rm -rf "${THEME_DIR}"

	echo "Installing '${THEME_DIR}'..."

	mkdir -p "${THEME_DIR}"

	# Index Theme File
	{
		echo "[Desktop Entry]"
		echo "Type=X-GNOME-Metatheme"
		echo "Name=${name}"
		echo "Comment=A GTK theme based on the Osaka Jade colour palette"
		echo "Encoding=UTF-8"
		echo ""
		echo "[X-GNOME-Metatheme]"
		echo "GtkTheme=${name}"
		echo "MetacityTheme=${name}"
		echo "IconTheme=Tokyonight-Dark" # You can change this if needed
		echo "CursorTheme=Sweet-cursors" # You can change this if needed
		echo "ButtonLayout=close,minimize,maximize:menu"
	} > "${THEME_DIR}/index.theme"

	# GTK2 Themes
	mkdir -p "${THEME_DIR}/gtk-2.0"
	cp -r "${SRC_DIR}/main/gtk-2.0/common/"*'.rc' "${THEME_DIR}/gtk-2.0"
	cp -r "${SRC_DIR}/assets/gtk-2.0/assets-common${color}" "${THEME_DIR}/gtk-2.0/assets"
	make_gtkrc "$dest" "$name" "$theme" "$color" "$size" "$ctype"

	# GTK3 Themes
	mkdir -p "${THEME_DIR}/gtk-3.0"
	sassc $SASSC_OPT "${SRC_DIR}/main/gtk-3.0/gtk${color}.scss" "${THEME_DIR}/gtk-3.0/gtk.css"

	# GTK4 Themes
	mkdir -p "${THEME_DIR}/gtk-4.0"
	sassc $SASSC_OPT "${SRC_DIR}/main/gtk-4.0/gtk${color}.scss" "${THEME_DIR}/gtk-4.0/gtk.css"
}

# Temporarily modify the main SCSS files to use our temp tweaks file
toggle_tweaks_import() {
    local from_file="tweaks"
    local to_file="tweaks-temp"

    if [[ "$1" == "revert" ]]; then
        from_file="tweaks-temp"
        to_file="tweaks"
    fi

    sed -i "s|@import \"sass/${from_file}\";|@import \"sass/${to_file}\";|" \
        "${SRC_DIR}/main/gtk-3.0/gtk.scss" \
        "${SRC_DIR}/main/gtk-3.0/gtk-Dark.scss" \
        "${SRC_DIR}/main/gtk-4.0/gtk.scss" \
        "${SRC_DIR}/main/gtk-4.0/gtk-Dark.scss"
}

cleanup() {
    echo "Cleaning up temporary files..."
    toggle_tweaks_import "revert"
    rm -f "${SRC_DIR}/sass/_tweaks-temp.scss"
    rm -f "${SRC_DIR}/sass/_osaka-jade-palette.scss"
}

# Make sure to clean up on exit
trap cleanup EXIT

# --- Main execution ---
echo "--- Generating Osaka-Jade GTK Theme ---"

# 1. Create the color palette from CSS variables
create_osaka_jade_palette

# 2. Create a temporary tweaks file importing the new palette
create_temp_tweaks

# 3. Modify main SCSS files to use the temp tweaks file
toggle_tweaks_import

# 4. Install the theme
install_theme

echo
echo "Done."
