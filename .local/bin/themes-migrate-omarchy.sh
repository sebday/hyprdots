#!/bin/bash

# Migrate omarchy theme to local theme format
# Usage: themes-migrate-omarchy.sh <source-theme-path>
# Automatically appends '-omarchy' to the theme name

if [ -z "$1" ]; then
    echo "Usage: $0 <source-theme-path>"
    echo "Example: $0 ~/Projects/omarchy/themes/catppuccin"
    echo "Note: Will automatically create theme as 'catppuccin-omarchy'"
    exit 1
fi

SOURCE_THEME="$1"
BASE_THEME_NAME="$(basename "$SOURCE_THEME")"
THEME_NAME="${BASE_THEME_NAME}-omarchy"
TARGET_DIR="$HOME/.themes/$THEME_NAME"

generate_colours_css() {
    local target_dir="$1"
    
    # Catppuccin Mocha defaults for missing colors
    local default_bg_primary="#1e1e2e"
    local default_bg_secondary="#181825"
    local default_text_primary="#cdd6f4"
    local default_text_accent="#74c7ec"
    local default_blue="#89b4fa"
    local default_cyan="#94e2d5"
    local default_purple="#cba6f7"
    local default_pink="#f5c2e7"
    local default_green="#a6e3a1"
    local default_orange="#fab387"
    local default_red="#f38ba8"
    
    # Collect colors from all available sources
    declare -A colors
    local sources_found=()
    
    # Extract from walker.css
    if [ -f "$target_dir/walker.css" ]; then
        colors[walker_text]=$(grep -oP '@define-color text \K#[0-9a-fA-F]+' "$target_dir/walker.css" | head -1)
        colors[walker_foreground]=$(grep -oP '@define-color foreground \K#[0-9a-fA-F]+' "$target_dir/walker.css" | head -1)
        colors[walker_background]=$(grep -oP '@define-color background \K#[0-9a-fA-F]+' "$target_dir/walker.css" | head -1)
        colors[walker_base]=$(grep -oP '@define-color base \K#[0-9a-fA-F]+' "$target_dir/walker.css" | head -1)
        colors[walker_selected]=$(grep -oP '@define-color selected-text \K#[0-9a-fA-F]+' "$target_dir/walker.css" | head -1)
        colors[walker_border]=$(grep -oP '@define-color border \K#[0-9a-fA-F]+' "$target_dir/walker.css" | head -1)
        [ -n "${colors[walker_background]}" ] && sources_found+=("walker.css")
    fi
    
    # Extract from waybar.css
    if [ -f "$target_dir/waybar.css" ]; then
        colors[waybar_foreground]=$(grep -oP '@define-color foreground \K#[0-9a-fA-F]+' "$target_dir/waybar.css" | head -1)
        colors[waybar_background]=$(grep -oP '@define-color background \K#[0-9a-fA-F]+' "$target_dir/waybar.css" | head -1)
        [ -n "${colors[waybar_background]}" ] && sources_found+=("waybar.css")
    fi
    
    # Extract from mako.ini
    if [ -f "$target_dir/mako.ini" ]; then
        colors[mako_text]=$(grep -oP '^text-color=\K#[0-9a-fA-F]+' "$target_dir/mako.ini" | head -1)
        colors[mako_border]=$(grep -oP '^border-color=\K#[0-9a-fA-F]+' "$target_dir/mako.ini" | head -1)
        colors[mako_background]=$(grep -oP '^background-color=\K#[0-9a-fA-F]+' "$target_dir/mako.ini" | head -1)
        [ -n "${colors[mako_background]}" ] && sources_found+=("mako.ini")
    fi
    
    # Build CSS with all required colors (use defaults if not found)
    local bg_primary="${colors[walker_base]:-${colors[walker_background]:-${colors[waybar_background]:-${colors[mako_background]:-$default_bg_primary}}}}"
    local bg_secondary="${colors[walker_background]:-${colors[waybar_background]:-${colors[mako_background]:-$default_bg_secondary}}}"
    local text_primary="${colors[walker_text]:-${colors[walker_foreground]:-${colors[waybar_foreground]:-${colors[mako_text]:-$default_text_primary}}}}"
    local text_accent="${colors[walker_selected]:-${colors[walker_foreground]:-${colors[waybar_foreground]:-${colors[mako_text]:-$default_text_accent}}}}"
    
    # Use defaults for color palette (not available in omarchy themes)
    local blue="$default_blue"
    local cyan="$default_cyan"
    local purple="$default_purple"
    local pink="$default_pink"
    local green="$default_green"
    local orange="$default_orange"
    local red="$default_red"
    
    cat > "$target_dir/colours.css" << EOF
:root {
    --bg-primary: $bg_primary;
    --bg-secondary: $bg_secondary;
    --text-primary: $text_primary;
    --text-accent: $text_accent;
    --blue: $blue;
    --cyan: $cyan;
    --purple: $purple;
    --pink: $pink;
    --green: $green;
    --orange: $orange;
    --red: $red;
}
EOF
    
    if [ ${#sources_found[@]} -gt 0 ]; then
        echo "Created: colours.css (extracted from ${sources_found[*]}, defaults for palette colors)"
    else
        echo "Created: colours.css (using catppuccin defaults)"
    fi
}

if [ ! -d "$SOURCE_THEME" ]; then
    echo "Error: Source theme directory does not exist: $SOURCE_THEME"
    exit 1
fi

echo "Migrating theme: $BASE_THEME_NAME → $THEME_NAME"
echo "Source: $SOURCE_THEME"
echo "Target: $TARGET_DIR"
echo

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Copy theme files (rsync to preserve existing dirs like gtk-3.0/)
# Exclude generated files that we create later
rsync -a --exclude='*.toml' --exclude='chromium.theme' --exclude='kitty.conf' --exclude='swayosd.css' --exclude='walker.css' --exclude='colours.css' --exclude='fuzzel.conf' --exclude='obsidian.css' --exclude='waybar.css' --exclude='mako.ini' "$SOURCE_THEME/" "$TARGET_DIR/"

# Generate colours.css BEFORE removing walker.css (needs it for color extraction)
# Only generate if it doesn't exist or is incomplete
if [ ! -f "$TARGET_DIR/colours.css" ] || ! grep -q -- "--red:" "$TARGET_DIR/colours.css"; then
    generate_colours_css "$TARGET_DIR"
else
    echo "Preserved: existing colours.css (already complete)"
fi

# Generate icons.theme - always overwrite to match available icon packs
# Try to intelligently match theme name to available icon packs
local icon_theme=""

case "$BASE_THEME_NAME" in
    *catppuccin*|*mocha*)
        icon_theme="Catppuccin-Mocha"
        ;;
    *catppuccin*|*latte*)
        icon_theme="Catppuccin-Latte"
        ;;
    *gruvbox*)
        icon_theme="Gruvbox-Dark"
        ;;
    *tokyo*|*night*)
        icon_theme="Tokyonight-Dark-Cyan"
        ;;
    *rose*|*pine*)
        icon_theme="Rosepine-Moon"
        ;;
esac

# Verify the icon theme exists, otherwise use default
if [ -z "$icon_theme" ] || { [ ! -d "$HOME/.local/share/icons/$icon_theme" ] && [ ! -d "/usr/share/icons/$icon_theme" ]; }; then
    icon_theme="Adwaita"
fi

echo "$icon_theme" > "$TARGET_DIR/icons.theme"
echo "Created: icons.theme (matched: $icon_theme)"

# Generate mako.ini from colours.css
if [ -f "$TARGET_DIR/colours.css" ]; then
    bg_primary=$(grep -oP -- '--bg-primary:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css")
    text_primary=$(grep -oP -- '--text-primary:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css")
    text_accent=$(grep -oP -- '--text-accent:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css")
    purple=$(grep -oP -- '--purple:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css")
    
    # Read icon theme from icons.theme file
    local icon_pack="Catppuccin-Mocha"
    if [ -f "$TARGET_DIR/icons.theme" ]; then
        icon_pack=$(cat "$TARGET_DIR/icons.theme" | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    fi
    
    if [ -n "$bg_primary" ] && [ -n "$text_primary" ]; then
        cat > "$TARGET_DIR/mako.ini" << EOF
include=~/.themes/shared/mako.ini

icon-path=/home/seb/.local/share/icons/${icon_pack}
background-color=${bg_primary}
text-color=${text_primary}
border-color=${text_accent}
progress-color=${purple}
EOF
        echo "Created: mako.ini (generated from colours.css with ${icon_pack} icons)"
    fi
fi

# Generate fuzzel.conf from colours.css if it exists
if [ -f "$TARGET_DIR/colours.css" ]; then
    # Extract colors from colours.css and convert to fuzzel format (remove # and add alpha)
    bg_primary=$(grep -oP -- '--bg-primary:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css" | sed 's/#//g')
    bg_secondary=$(grep -oP -- '--bg-secondary:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css" | sed 's/#//g')
    text_primary=$(grep -oP -- '--text-primary:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css" | sed 's/#//g')
    text_accent=$(grep -oP -- '--text-accent:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css" | sed 's/#//g')
    border=$(grep -oP -- '--border:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css" | sed 's/#//g')
    
    if [ -n "$bg_primary" ] && [ -n "$text_primary" ]; then
        cat > "$TARGET_DIR/fuzzel.conf" << EOF
fuzzel_background=${bg_primary}ee
fuzzel_text=${text_primary}ff
fuzzel_match=${text_accent:-${text_primary}}ff
fuzzel_selection=${text_accent:-${text_primary}}ff
fuzzel_selection_match=${text_primary}ff
fuzzel_selection_text=${bg_primary}ff
fuzzel_border=${border:-${text_accent:-${text_primary}}}ff
EOF
        echo "Created: fuzzel.conf (generated from colours.css)"
    fi
fi

# Generate waybar.css from colours.css
if [ -f "$TARGET_DIR/colours.css" ]; then
    bg_primary=$(grep -oP -- '--bg-primary:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css")
    bg_secondary=$(grep -oP -- '--bg-secondary:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css")
    text_primary=$(grep -oP -- '--text-primary:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css")
    text_accent=$(grep -oP -- '--text-accent:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css")
    blue=$(grep -oP -- '--blue:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css")
    cyan=$(grep -oP -- '--cyan:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css")
    purple=$(grep -oP -- '--purple:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css")
    pink=$(grep -oP -- '--pink:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css")
    green=$(grep -oP -- '--green:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css")
    orange=$(grep -oP -- '--orange:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css")
    red=$(grep -oP -- '--red:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css")
    
    if [ -n "$bg_primary" ] && [ -n "$text_primary" ]; then
        cat > "$TARGET_DIR/waybar.css" << EOF
/* Waybar CSS generated from colours.css */
@define-color background ${bg_primary};
@define-color foreground ${text_primary};
@define-color text-secondary ${bg_secondary};
@define-color accent-blue ${blue};
@define-color accent-pink ${purple};
@define-color accent-yellow ${orange};
@define-color accent-orange ${orange};
@define-color github-0 ${bg_secondary};
@define-color github-1 ${blue};
@define-color github-2 ${cyan};
@define-color github-3 ${cyan};
@define-color github-4 ${green};
EOF
        echo "Created: waybar.css (generated from colours.css)"
    fi
fi

# Generate obsidian.css from colours.css
if [ -f "$TARGET_DIR/colours.css" ]; then
    bg_primary=$(grep -oP -- '--bg-primary:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css")
    bg_secondary=$(grep -oP -- '--bg-secondary:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css")
    text_primary=$(grep -oP -- '--text-primary:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css")
    text_accent=$(grep -oP -- '--text-accent:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css")
    blue=$(grep -oP -- '--blue:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css")
    cyan=$(grep -oP -- '--cyan:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css")
    purple=$(grep -oP -- '--purple:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css")
    pink=$(grep -oP -- '--pink:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css")
    green=$(grep -oP -- '--green:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css")
    orange=$(grep -oP -- '--orange:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css")
    red=$(grep -oP -- '--red:\s*\K#[0-9a-fA-F]+' "$TARGET_DIR/colours.css")
    
    if [ -n "$bg_primary" ] && [ -n "$text_primary" ]; then
        cat > "$TARGET_DIR/obsidian.css" << EOF
/* Obsidian CSS generated from colours.css */
.theme-dark,
.theme-light {
  --background-primary: ${bg_primary};
  --background-primary-alt: ${bg_secondary};
  --background-secondary: var(--background-primary);
  --background-secondary-alt: var(--background-primary-alt);
  --text-normal: ${text_primary};
  --text-on-accent: ${bg_primary};
  --text-title-h1: ${purple};
  --text-title-h2: ${orange};
  --text-title-h3: ${green};
  --text-title-h4: ${red};
  --text-title-h5: ${orange};
  --text-title-h6: ${purple};
  --text-link: ${blue};
  --text-a: ${pink};
  --text-a-hover: ${pink};
  --interactive-accent: var(--text-title-h3);
  --blockquote-border: ${purple};

  /* Code view */
  --code-normal: var(--text-normal);
  --code-background: var(--background-primary);
  --modular-foreground: var(--text-normal);
  --modular-Comment: ${text_accent};
  --modular-keyword: var(--text-a);
  --modular-definition: var(--text-title-h3);
  --modular-variable: var(--text-normal);
  --modular-number: var(--text-title-h1);
  --modular-function: ${cyan};
  --modular-string: var(--text-title-h5);
}
EOF
        echo "Created: obsidian.css (generated from colours.css)"
    fi
fi

echo
echo "✓ Theme migration complete!"
echo "You can now use this theme with themes-switch.sh"
echo
echo "To customize icon theme, edit: $TARGET_DIR/icons.theme"
echo "To customize colors, edit: $TARGET_DIR/colours.css"

