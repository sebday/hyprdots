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

# Mix two #rrggbb colours. t=0 keeps $1, t=1 is $2.
mix_hex() {
    python3 -c '
import sys
a, b, t = sys.argv[1], sys.argv[2], float(sys.argv[3])

def rgb(h):
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)

ar, ag, ab = rgb(a)
br, bg, bb = rgb(b)
r = round(ar + (br - ar) * t)
g = round(ag + (bg - ag) * t)
bl = round(ab + (bb - ab) * t)
print("#%02x%02x%02x" % (r, g, bl))
' "$1" "$2" "$3"
}

# Surfaces/overlays must sit between bg and fg so dim UI text stays readable.
surface0=$(mix_hex "$bg" "$fg" 0.12)
surface1=$(mix_hex "$bg" "$fg" 0.22)
surface2=$(mix_hex "$bg" "$fg" 0.32)
overlay0=$(mix_hex "$bg" "$fg" 0.42)
overlay1=$(mix_hex "$bg" "$fg" 0.52)
overlay2=$(mix_hex "$bg" "$fg" 0.62)
subtext0=$(mix_hex "$bg" "$fg" 0.74)
subtext1=$(mix_hex "$bg" "$fg" 0.86)
[ -z "$c7" ] && c7="$subtext1"

# Modular palette: colors.toml -> semantic keys (mirror former Catppuccin mapping)
# base -> bg; mantle/crust -> mantle; surfaces/overlays mixed bg→fg
# rosewater -> cursor; mauve -> accent; red/maroon -> c1; green -> c2
# peach/yellow -> c3; blue -> c4; teal -> c6; sky -> c7; sapphire -> c14
# pink/flamingo -> c13; lavender -> c12

cat > "$theme_dir/neovim.lua" << EOF
return {
	palette = {
		base = "$bg",
		mantle = "$mantle",
		crust = "$mantle",
		surface0 = "$surface0",
		surface1 = "$surface1",
		surface2 = "$surface2",
		text = "$fg",
		subtext1 = "$subtext1",
		subtext0 = "$subtext0",
		overlay2 = "$overlay2",
		overlay1 = "$overlay1",
		overlay0 = "$overlay0",
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
