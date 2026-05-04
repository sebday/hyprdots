#!/bin/bash
# Generate VS Code theme extension from colors.toml (Catppuccin Mocha base)
# Usage: themes-generate-vscode.sh <theme_dir>
# Output: theme_dir/vscode-theme/ with package.json + themes/color-theme.json

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/themes-common.sh"

SHARED_VSCODE="$THEME_DIR/shared/vscode"

theme_dir="$1"
[ -z "$theme_dir" ] && exit 1

toml="$theme_dir/colors.toml"
[ ! -f "$toml" ] && exit 0

[ ! -f "$SHARED_VSCODE/color-theme.json" ] && exit 0

# Use .theme-name (set during apply) so we get the source theme name even when theme_dir is next/
theme_name=""
[ -f "$theme_dir/.theme-name" ] && theme_name=$(tr -d '\n' < "$theme_dir/.theme-name")
[ -z "$theme_name" ] && theme_name=$(basename "$theme_dir")
display_name=$(theme_display_name "$theme_name")

# Read colors
bg=$(toml_val background "$toml")
mantle=$(toml_val mantle "$toml")
[ -z "$mantle" ] && mantle="$bg"
c0=$(toml_val color0 "$toml")
fg=$(toml_val foreground "$toml")
accent=$(toml_val accent "$toml")
c1=$(toml_val color1 "$toml")
c2=$(toml_val color2 "$toml")
c3=$(toml_val color3 "$toml")
c4=$(toml_val color4 "$toml")
c5=$(toml_val color5 "$toml")
c6=$(toml_val color6 "$toml")
c7=$(toml_val color7 "$toml")
c8=$(toml_val color8 "$toml")
c12=$(toml_val color12 "$toml")
c13=$(toml_val color13 "$toml")
c14=$(toml_val color14 "$toml")
cursor_c=$(toml_val cursor "$toml")

# Catppuccin Mocha -> colors.toml mapping (replace hex, alpha suffix preserved by sed)
# Base (editor) -> bg; mantle/crust/surfaces (sidebar, chat, tabs) -> mantle
# 1e1e2e=base -> bg
# 181825=mantle, 11111b=crust, 0e0e16=crust -> mantle
# 313244, 45475a, 585b70, 686b84, 28283d = surfaces -> mantle
# 6c7086, 7f849c, 9399b2, a6adc8, bac2de = overlay/subtext (foregrounds)
# Accent/colors: cba6f7=mauve, dec7fa=mauve-light
# f38ba8=red, a6e3a1=green, fab387=peach, 89b4fa=blue
# f5c2e7=pink, 94e2d5=teal, 89dceb=sky, 74c7ec=sapphire, b4befe=lavender
# f5e0dc=rosewater, cdd6f4=text
# Variants: a6738c, eba0ac, f37799, 71a4f9, 74a8fc, 6bd7ca, 89d88b, 93dd8d
# ebd391, f9e2af, f2aede, f2cdcd, 3e5767, 5e3f53

out_dir="$theme_dir/vscode-theme"
rm -rf "$out_dir"
mkdir -p "$out_dir/themes"
cp "$SHARED_VSCODE/color-theme.json" "$out_dir/themes/color-theme.json"

# Sed replacements: Catppuccin hex -> our color (case-insensitive for hex)
# Order: replace longer/specific first to avoid partial matches
for css in "$out_dir/themes/color-theme.json"; do
    [ -f "$css" ] || continue
    # Base (editor) -> bg; mantle/crust (chrome) -> mantle
    sed -i "s/#1e1e2e/$bg/gi" "$css"
    sed -i "s/#181825/$mantle/gi" "$css"
    sed -i "s/#11111b/$mantle/gi" "$css"
    sed -i "s/#0e0e16/$mantle/gi" "$css"
    # Text
    sed -i "s/#cdd6f4/$fg/gi" "$css"
    sed -i "s/#bac2de/$fg/gi" "$css"
    sed -i "s/#f5e0dc/$cursor_c/gi" "$css"
    # Accent
    sed -i "s/#dec7fa/$accent/gi" "$css"
    sed -i "s/#cba6f7/$accent/gi" "$css"
    # Semantic colors
    sed -i "s/#f38ba8/$c1/gi" "$css"
    sed -i "s/#a6e3a1/$c2/gi" "$css"
    sed -i "s/#fab387/$c3/gi" "$css"
    sed -i "s/#f9e2af/$c3/gi" "$css"
    sed -i "s/#ebd391/$c3/gi" "$css"
    sed -i "s/#89b4fa/$c4/gi" "$css"
    sed -i "s/#71a4f9/$c4/gi" "$css"
    sed -i "s/#74a8fc/$c4/gi" "$css"
    sed -i "s/#94e2d5/$c6/gi" "$css"
    sed -i "s/#6bd7ca/$c6/gi" "$css"
    sed -i "s/#89dceb/$c7/gi" "$css"
    sed -i "s/#74c7ec/$c14/gi" "$css"
    sed -i "s/#f5c2e7/$c13/gi" "$css"
    sed -i "s/#f2aede/$c13/gi" "$css"
    sed -i "s/#f2cdcd/$c13/gi" "$css"
    sed -i "s/#b4befe/$c12/gi" "$css"
    # Surfaces (sidebar, chat, list, input, etc.) -> mantle
    sed -i "s/#313244/$mantle/gi" "$css"
    sed -i "s/#45475a/$mantle/gi" "$css"
    sed -i "s/#585b70/$mantle/gi" "$css"
    sed -i "s/#686b84/$mantle/gi" "$css"
    sed -i "s/#28283d/$mantle/gi" "$css"
    # Overlay (inactive text, borders) -> c7 (avoid c8 since it equals 585b70 which we map to bg)
    sed -i "s/#6c7086/$c7/gi" "$css"
    sed -i "s/#7f849c/$c7/gi" "$css"
    sed -i "s/#9399b2/$c7/gi" "$css"
    sed -i "s/#a6adc8/$c7/gi" "$css"
    # Muted variants
    sed -i "s/#a6738c/$c1/gi" "$css"
    sed -i "s/#eba0ac/$c1/gi" "$css"
    sed -i "s/#f37799/$c1/gi" "$css"
    sed -i "s/#89d88b/$c2/gi" "$css"
    sed -i "s/#93dd8d/$c2/gi" "$css"
    # Find/highlight (use c8; run after 585b70->bg so these stay visible)
    sed -i "s/#3e5767/$c8/gi" "$css"
    sed -i "s/#5e3f53/$c8/gi" "$css"
done

# Editor panel: use background; chrome (sidebar, tabs, etc.) uses mantle from sed above
jq --arg bg "$bg" '
  .colors["editor.background"] = $bg |
  .colors["editorGroup.emptyBackground"] = $bg |
  .colors["editorGutter.background"] = $bg
' "$out_dir/themes/color-theme.json" > "$out_dir/themes/color-theme.json.tmp" && mv "$out_dir/themes/color-theme.json.tmp" "$out_dir/themes/color-theme.json"

# Update theme name in JSON
sed -i "s/\"name\": \"Catppuccin Mocha\"/\"name\": \"$display_name\"/" "$out_dir/themes/color-theme.json"

# If we updated current theme, sync to editors so manual regens propagate
if [ "$theme_dir" = "$HOME/.themes/current" ] || paths_resolved_equal "$theme_dir" "$HOME/.themes/current"; then
    "$HOME/.local/bin/themes-set-vscode.sh" 2>/dev/null || true
fi

# package.json
cat > "$out_dir/package.json" << EOF
{
  "name": "generated-$theme_name",
  "displayName": "$display_name",
  "publisher": "sebday",
  "version": "1.0.0",
  "engines": { "vscode": "^1.70.0" },
  "categories": ["Themes"],
  "contributes": {
    "themes": [
      {
        "label": "$display_name",
        "uiTheme": "vs-dark",
        "path": "./themes/color-theme.json"
      }
    ]
  }
}
EOF
