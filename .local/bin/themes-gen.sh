#!/bin/bash

# Script to generate theme files from a colours.css file
# Usage: ./generate_theme.sh <theme_name>

# --- Configuration ---
THEME_DIR="$HOME/.themes"

# --- Alphas ---
ALPHA_OPAQUE="ff"
ALPHA_HIGH="ee"
ALPHA_MED="aa"
ALPHA_LOW="55"
ALPHA_TRANSPARENT="00"

# --- Argument Parsing ---
if [ -z "$1" ]; then
    echo "Usage: $0 <theme_name>"
    echo "  <theme_name> should be a directory in $THEME_DIR"
    exit 1
fi

SELECTED_THEME="$1"
SELECTED_THEME_DIR="$THEME_DIR/$SELECTED_THEME"
COLOURS_FILE="$SELECTED_THEME_DIR/colours.css"

if [ ! -d "$SELECTED_THEME_DIR" ]; then
    echo "Error: Theme directory '$SELECTED_THEME_DIR' not found."
    exit 1
fi

if [ ! -f "$COLOURS_FILE" ]; then
    echo "Error: colours.css not found in '$SELECTED_THEME_DIR'."
    exit 1
fi

# --- Color Parsing ---
# Function to parse colours.css and export variables
parse_colors() {
    # Extract the :root block, remove comments and newlines
    local css_vars=$(sed -n '/:root/,/}/p' "$COLOURS_FILE" | grep -v '/\*' | tr -d '\n' | sed 's/.*{//; s/}.*//')

    # Read variables separated by semicolons
    IFS=';' read -ra VARS <<< "$css_vars"
    for var in "${VARS[@]}"; do
        if [[ "$var" == *":"* ]]; then
            # Extract key and value
            local key=$(echo "$var" | cut -d':' -f1 | sed 's/--//; s/^[[:space:]]*//; s/[[:space:]]*$//' | tr '-' '_')
            local value=$(echo "$var" | cut -d':' -f2 | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
            
            if [ -n "$key" ]; then
                # Export color with hash
                export "$key=$value"
                # Export color without hash
                export "${key}_no_hash=${value#\#}"
            fi
        fi
    done
}

# Parse colors and export them as environment variables
parse_colors

# --- Log parsed colors for debugging ---
echo "Parsed colors from $COLOURS_FILE:"
env | grep -E '^(bg|text|blue|cyan|purple|pink|green|orange|red)='
echo "-------------------------------------"

# --- Verify Colors and Set Defaults ---
check_and_set_defaults() {
    local required_vars=("bg_primary" "bg_secondary" "text_primary" "text_accent" "blue" "cyan" "purple" "pink" "green" "orange" "red")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            echo "Warning: Color '--${var//_/-}' not found in colours.css. Using a default."
            case "$var" in
                bg_primary) bg_primary="#1e1e2e" ;;
                bg_secondary) bg_secondary="#181825" ;;
                text_primary) text_primary="#cdd6f4" ;;
                *) declare "$var"="#ff00ff" ;; # Default to magenta for missing accents
            esac
            # Re-export the _no_hash version
            declare "${var}_no_hash=${!var#\#}"
        fi
    done
}

check_and_set_defaults

# --- Theme Generation Functions ---

generate_mako_conf() {
    local MakoFile="$SELECTED_THEME_DIR/mako.conf"
    if [ -f "$MakoFile" ]; then
        mv "$MakoFile" "$MakoFile.bak-$(date +%Y%m%d-%H%M%S)"
    fi
    echo "Generating $MakoFile..."
    cat > "$MakoFile" << EOF
background_color=$bg_primary
text_color=$text_primary
border_color=$purple
progress_color=$purple
EOF
}

generate_btop_theme() {
    local BtopThemeFile="$SELECTED_THEME_DIR/btop.theme"
    if [ -f "$BtopThemeFile" ]; then
        mv "$BtopThemeFile" "$BtopThemeFile.bak-$(date +%Y%m%d-%H%M%S)"
    fi
    echo "Generating $BtopThemeFile..."
    cat > "$BtopThemeFile" << EOF
# Btop theme generated from colours.css

# Main background, empty for terminal default, need to be empty if you want transparent background
theme[main_bg]="$bg_primary"

# Main text color
theme[main_fg]="$text_primary"

# Title color for boxes
theme[title]="$text_primary"

# Highlight color for keyboard shortcuts
theme[hi_fg]="$blue"

# Background color of selected item in processes box
theme[selected_bg]="$bg_secondary"

# Foreground color of selected item in processes box
theme[selected_fg]="$blue"

# Color of inactive/disabled text
theme[inactive_fg]="$text_secondary" # Assumed fallback

# Color of text appearing on top of graphs, i.e uptime and current network graph scaling
theme[graph_text]="$text_primary"

# Background color of the percentage meters
theme[meter_bg]="$bg_secondary"

# Misc colors for processes box including mini cpu graphs, details memory graph and details status text
theme[proc_misc]="$text_primary"

# CPU, Memory, Network, Proc box outline colors
theme[cpu_box]="$purple"
theme[mem_box]="$green"
theme[net_box]="$red"
theme[proc_box]="$blue"

# Box divider line and small boxes line color
theme[div_line]="$text_secondary" # Assumed fallback

# Temperature graph color (Green -> Yellow -> Red)
theme[temp_start]="$green"
theme[temp_mid]="$orange" # Fallback for yellow
theme[temp_end]="$red"

# CPU graph colors (Teal -> Lavender)
theme[cpu_start]="$cyan"
theme[cpu_mid]="$text_accent"
theme[cpu_end]="$blue"

# Mem/Disk free meter (Mauve -> Lavender -> Blue)
theme[free_start]="$purple"
theme[free_mid]="$purple" # No lavender
theme[free_end]="$blue"

# Mem/Disk cached meter (Sapphire -> Lavender)
theme[cached_start]="$text_accent"
theme[cached_mid]="$blue"
theme[cached_end]="$purple" # No lavender

# Mem/Disk available meter (Peach -> Red)
theme[available_start]="$orange"
theme[available_mid]="$red"
theme[available_end]="$red"

# Mem/Disk used meter (Green -> Sky)
theme[used_start]="$green"
theme[used_mid]="$cyan"
theme[used_end]="$text_accent" # No sky

# Download graph colors (Peach -> Red)
theme[download_start]="$orange"
theme[download_mid]="$red"
theme[download_end]="$red"

# Upload graph colors (Green -> Sky)
theme[upload_start]="$green"
theme[upload_mid]="$cyan"
theme[upload_end]="$text_accent" # No sky

# Process box color gradient for threads, mem and cpu usage (Sapphire -> Mauve)
theme[process_start]="$text_accent"
theme[process_mid]="$blue"
theme[process_end]="$purple"
EOF
}

generate_fuzzel_conf() {
    local FuzzelFile="$SELECTED_THEME_DIR/fuzzel.conf"
    if [ -f "$FuzzelFile" ]; then
        mv "$FuzzelFile" "$FuzzelFile.bak-$(date +%Y%m%d-%H%M%S)"
    fi
    echo "Generating $FuzzelFile..."
    cat > "$FuzzelFile" << EOF
fuzzel_background=${bg_primary_no_hash}${ALPHA_HIGH}
fuzzel_text=${text_primary_no_hash}${ALPHA_OPAQUE}
fuzzel_match=${cyan_no_hash}${ALPHA_OPAQUE}
fuzzel_selection=${blue_no_hash}${ALPHA_OPAQUE}
fuzzel_selection_match=${text_primary_no_hash}${ALPHA_OPAQUE}
fuzzel_selection_text=${bg_primary_no_hash}${ALPHA_OPAQUE}
fuzzel_border=${blue_no_hash}${ALPHA_OPAQUE}
EOF
}

generate_hypr_conf() {
    local HyprFile="$SELECTED_THEME_DIR/hypr.conf"
    if [ -f "$HyprFile" ]; then
        mv "$HyprFile" "$HyprFile.bak-$(date +%Y%m%d-%H%M%S)"
    fi
    echo "Generating $HyprFile..."
    cat > "$HyprFile" << EOF
# Hyprland colors generated from colours.css
\$col_active_border = rgba(${blue_no_hash}${ALPHA_HIGH}) rgba(${purple_no_hash}${ALPHA_HIGH}) 45deg
\$col_inactive_border = rgba(${text_primary_no_hash}${ALPHA_MED})
EOF
}

generate_waybar_css() {
    local WaybarFile="$SELECTED_THEME_DIR/waybar.css"
    if [ -f "$WaybarFile" ]; then
        mv "$WaybarFile" "$WaybarFile.bak-$(date +%Y%m%d-%H%M%S)"
    fi
    echo "Generating $WaybarFile..."
    cat > "$WaybarFile" << EOF
/* Waybar CSS generated from colours.css */
@define-color background ${bg_primary};
@define-color foreground ${text_primary};
@define-color text-secondary ${text_secondary:-$bg_secondary}; /* Fallback */
@define-color accent-blue ${text_accent};
@define-color accent-pink ${purple};
@define-color accent-yellow ${orange}; /* Fallback */
@define-color accent-orange ${orange};
@define-color github-0 ${bg_secondary};
@define-color github-1 ${text_accent};
@define-color github-2 ${cyan}; /* Fallback for sky */
@define-color github-3 ${cyan};
@define-color github-4 ${green};
EOF
}

generate_obsidian_css() {
    local ObsidianFile="$SELECTED_THEME_DIR/obsidian.css"
    if [ -f "$ObsidianFile" ]; then
        mv "$ObsidianFile" "$ObsidianFile.bak-$(date +%Y%m%d-%H%M%S)"
    fi
    echo "Generating $ObsidianFile..."
    cat > "$ObsidianFile" << EOF
/* Obsidian CSS generated from colours.css */
.theme-dark,
.theme-light {
  --background-primary: ${bg_primary};
  --background-primary-alt: ${bg_secondary};
  --background-secondary: var(--background-primary);
  --background-secondary-alt: var(--background-primary-alt);
  --text-normal: ${text_primary};
  --text-on-accent: ${bg_primary};
  --text-title-h1: ${purple};    /* Mauve */
  --text-title-h2: ${orange};    /* Peach */
  --text-title-h3: ${green};    /* Green */
  --text-title-h4: ${red};    /* Red */
  --text-title-h5: ${orange};    /* Yellow fallback */
  --text-title-h6: ${purple};    /* Mauve */
  --text-link: ${blue};        /* Blue */
  --text-a: ${pink};           /* Pink */
  --text-a-hover: ${pink};      /* Pink */
  --interactive-accent: var(--text-title-h3);
  --blockquote-border: ${purple}; /* Mauve */

  /* Code view */
  --code-normal: var(--text-normal);
  --code-background: var(--background-primary);
  --modular-foreground: var(--text-normal);
  --modular-Comment: #a6adc8;  /* Subtext0, hardcoded */
  --modular-keyword: var(--text-a);
  --modular-definition: var(--text-title-h3);
  --modular-variable: var(--text-normal);
  --modular-number: var(--text-title-h1);
  --modular-function: ${cyan}; /* Teal */
  --modular-string: var(--text-title-h5);
}
EOF
}

# --- Main Execution ---
generate_mako_conf
generate_btop_theme
generate_fuzzel_conf
generate_hypr_conf
generate_waybar_css
generate_obsidian_css

echo "Theme generation for '$SELECTED_THEME' completed."
