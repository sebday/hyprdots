#!/bin/bash
# Generate Neovim theme from colors.toml (Modular palette)
# Usage: evo-theme-generate-neovim.sh <theme_dir>
# Output: theme_dir/neovim.lua

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/evo-theme-common.sh"

theme_dir="$1"
[ -z "$theme_dir" ] && exit 1

toml="$theme_dir/colors.toml"
[ ! -f "$toml" ] && exit 0

bg=$(toml_val background "$toml")
mantle=$(toml_val mantle "$toml")
[ -z "$mantle" ] && mantle="$bg"
fg=$(toml_val foreground "$toml")
accent=$(toml_val accent "$toml")
cursor_c=$(toml_val cursor "$toml")
c1=$(toml_val color1 "$toml")
c2=$(toml_val color2 "$toml")
c3=$(toml_val color3 "$toml")
c4=$(toml_val color4 "$toml")
c6=$(toml_val color6 "$toml")
c7=$(toml_val color7 "$toml")
c12=$(toml_val color12 "$toml")
c13=$(toml_val color13 "$toml")
c14=$(toml_val color14 "$toml")

# Modular palette: colors.toml -> semantic keys (mirror former Catppuccin mapping)
# base -> bg; mantle/crust/surfaces -> mantle; text/subtext1 -> fg
# rosewater -> cursor; mauve -> accent; red/maroon -> c1; green -> c2
# peach/yellow -> c3; blue -> c4; teal -> c6; sky -> c7; sapphire -> c14
# pink/flamingo -> c13; lavender -> c12; overlay/subtext0 -> c7

cat > "$theme_dir/neovim.lua" << EOF
return {
	palette = {
		base = "$bg",
		mantle = "$mantle",
		crust = "$mantle",
		surface0 = "$mantle",
		surface1 = "$mantle",
		surface2 = "$mantle",
		text = "$fg",
		subtext1 = "$fg",
		subtext0 = "$c7",
		overlay2 = "$c7",
		overlay1 = "$c7",
		overlay0 = "$c7",
		rosewater = "$cursor_c",
		flamingo = "$c13",
		pink = "$c13",
		mauve = "$accent",
		red = "$c1",
		maroon = "$c1",
		peach = "$c3",
		yellow = "$c3",
		green = "$c2",
		teal = "$c6",
		sky = "$c7",
		sapphire = "$c14",
		blue = "$c4",
		lavender = "$c12",
	},
	spec = {
		{
			"LazyVim/LazyVim",
			opts = { colorscheme = "modular" },
		},
	},
}
EOF
