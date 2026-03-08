#!/bin/bash
# Set yazi icon theme from shared template + current theme's colours.css

THEME_DIR="$HOME/.themes"
CURRENT_LINK="$THEME_DIR/current"
YAZI_CONFIG_DIR="$HOME/.config/yazi"
TEMPLATE="$THEME_DIR/shared/yazi-theme.toml.template"

# Get current theme name
if [[ -L "$CURRENT_LINK" ]]; then
  CURRENT_THEME=$(basename "$(readlink -f "$CURRENT_LINK")")
else
  echo "Error: No current theme symlink found"
  exit 1
fi

COLOURS="$THEME_DIR/$CURRENT_THEME/colours.css"
if [[ ! -f "$COLOURS" ]]; then
  echo "Warning: No colours.css found for: $CURRENT_THEME"
  exit 0
fi

if [[ ! -f "$TEMPLATE" ]]; then
  echo "Warning: Shared template not found: $TEMPLATE"
  exit 0
fi

# Extract hex value for a CSS variable (e.g. --blue: #89b4fa;)
get_css_var() {
  local var=$1
  grep -F -e "--$var:" "$COLOURS" | sed -E 's/.*:\s*(#[a-fA-F0-9]+)\s*;.*/\1/' | tr -d ' \t'
}

# Read template and substitute placeholders
output=$(cat "$TEMPLATE")
for var in bg-primary bg-secondary text-primary text-accent blue cyan purple pink green orange red; do
  value=$(get_css_var "$var")
  if [[ -n "$value" ]]; then
    output="${output//\{\{$var\}\}/$value}"
  fi
done

# Ensure yazi config directory exists
mkdir -p "$YAZI_CONFIG_DIR"

# Write generated theme
echo "$output" > "$YAZI_CONFIG_DIR/theme.toml"
echo "Set yazi theme to: $CURRENT_THEME (from colours.css)"
