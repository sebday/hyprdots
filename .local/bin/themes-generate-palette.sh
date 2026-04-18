#!/usr/bin/env bash
# Generate colors.toml from a wallpaper image.
# Usage: themes-generate-palette.sh <wallpaper_path> <output_colors_toml>
# Output: 23-key schema compatible with themes-process-templates.sh

set -e

wallpaper_path="$1"
output_toml="$2"

[ -z "$wallpaper_path" ] || [ -z "$output_toml" ] && exit 1
[ ! -f "$wallpaper_path" ] && exit 1

# Everforest fallback palette (used when extraction fails or for guardrails)
EVERFOREST=(
    accent="#7fbbb3"
    cursor="#d3c6aa"
    foreground="#d3c6aa"
    background="#2d353b"
    mantle="#252b30"
    selection_foreground="#2d353b"
    selection_background="#d3c6aa"
    color0="#475258"
    color1="#e67e80"
    color2="#a7c080"
    color3="#dbbc7f"
    color4="#7fbbb3"
    color5="#d699b6"
    color6="#83c092"
    color7="#d3c6aa"
    color8="#475258"
    color9="#e67e80"
    color10="#a7c080"
    color11="#dbbc7f"
    color12="#7fbbb3"
    color13="#d699b6"
    color14="#83c092"
    color15="#d3c6aa"
)

# Extract colors via ImageMagick
colors_raw=$(convert "$wallpaper_path" -resize 150x150 -colors 32 -unique-colors txt:- 2>/dev/null) || true
if [ -z "$colors_raw" ]; then
    for entry in "${EVERFOREST[@]}"; do
        key="${entry%%=*}"
        val="${entry#*=}"
        printf '%s = "%s"\n' "$key" "$val"
    done > "$output_toml"
    exit 0
fi

# Parse hex colors from ImageMagick output
# Format: "0,0: (r,g,b)  #RRGGBB  srgb(...)"
hex_list=()
while IFS= read -r line; do
    [[ "$line" =~ \#([0-9A-Fa-f]{6}) ]] && hex_list+=("#${BASH_REMATCH[1]}")
done <<< "$colors_raw"

# Need at least a few colors
if [ ${#hex_list[@]} -lt 3 ]; then
    for entry in "${EVERFOREST[@]}"; do
        key="${entry%%=*}"
        val="${entry#*=}"
        printf '%s = "%s"\n' "$key" "$val"
    done > "$output_toml"
    exit 0
fi

# Python helper for scoring and semantic mapping (avoids complex bash math)
# Pass: output_toml, hex1 hex2 ..., accent=#xxx key=val ...
python3 - "$output_toml" "${hex_list[@]}" "${EVERFOREST[@]}" << 'PYEOF'
import sys
import re

def hex_to_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def rgb_to_hex(r, g, b):
    return '#{:02x}{:02x}{:02x}'.format(
        max(0, min(255, int(r))),
        max(0, min(255, int(g))),
        max(0, min(255, int(b)))
    )

def darken(hex_str, factor):
    r, g, b = hex_to_rgb(hex_str)
    return rgb_to_hex(r*factor, g*factor, b*factor)

def luminance(r, g, b):
    return 0.299 * r + 0.587 * g + 0.114 * b

def saturation(r, g, b):
    mx, mn = max(r, g, b), min(r, g, b)
    if mx == 0: return 0
    return (mx - mn) / mx if mx else 0

def hue(r, g, b):
    r, g, b = r/255, g/255, b/255
    mx, mn = max(r, g, b), min(r, g, b)
    if mx == mn: return 0
    d = mx - mn
    if mx == r: h = (g - b) / d + (6 if g < b else 0)
    elif mx == g: h = (b - r) / d + 2
    else: h = (r - g) / d + 4
    return (h / 6) % 1  # 0-1

HUE_RANGES = [(0.92, 0.08), (0.25, 0.45), (0.08, 0.25), (0.55, 0.75), (0.75, 0.92), (0.45, 0.55)]
EVERFOREST_ANSI = ['#e67e80', '#a7c080', '#dbbc7f', '#7fbbb3', '#d699b6', '#83c092']

def in_hue_range(h, lo, hi):
    if lo <= hi:
        return lo <= h <= hi
    return h >= lo or h <= hi

def write_fallback(output_toml, everforest):
    defaults = [('accent','#7fbbb3'),('cursor','#d3c6aa'),('foreground','#d3c6aa'),('background','#2d353b'),
                ('mantle','#252b30'),('selection_foreground','#2d353b'),('selection_background','#d3c6aa'),
                ('color0','#475258'),('color1','#e67e80'),('color2','#a7c080'),('color3','#dbbc7f'),
                ('color4','#7fbbb3'),('color5','#d699b6'),('color6','#83c092'),('color7','#d3c6aa'),
                ('color8','#475258'),('color9','#e67e80'),('color10','#a7c080'),('color11','#dbbc7f'),
                ('color12','#7fbbb3'),('color13','#d699b6'),('color14','#83c092'),('color15','#d3c6aa')]
    with open(output_toml, 'w') as f:
        for k, v in defaults:
            f.write(f'{k} = "{everforest.get(k, v)}"\n')

def main():
    output_toml = sys.argv[1]
    hex_list = []
    everforest = {}
    for s in sys.argv[2:]:
        if '=' in s:
            k, v = s.split('=', 1)
            everforest[k] = v
        elif re.match(r'^#[0-9A-Fa-f]{6}$', s):
            hex_list.append(s)

    if len(hex_list) < 3:
        write_fallback(output_toml, everforest)
        return

    colors = []
    for h in hex_list:
        r, g, b = hex_to_rgb(h)
        colors.append({
            'hex': h, 'r': r, 'g': g, 'b': b,
            'lum': luminance(r, g, b), 'sat': saturation(r, g, b), 'hue': hue(r, g, b),
        })

    dark = sorted(colors, key=lambda c: (c['lum'], -c['sat']))
    bg = dark[0]
    bg_hex = everforest.get('background', '#2d353b') if bg['lum'] > 80 else bg['hex']

    mantle_hex = everforest.get('mantle', '#252b30')
    if len(dark) > 1 and dark[1]['lum'] < bg['lum'] + 20:
        mantle_hex = dark[1]['hex']
    else:
        mantle_hex = darken(bg_hex, 0.85)

    light = sorted(colors, key=lambda c: -c['lum'])
    fg_hex = everforest.get('foreground', '#d3c6aa')
    fg_candidates = [c for c in light if c['lum'] > 120 and c['sat'] < 0.6]
    if fg_candidates:
        cand = fg_candidates[0]
        fg_hex = cand['hex'] if cand['lum'] - bg['lum'] >= 100 else fg_hex
    elif light and light[0]['lum'] - bg['lum'] >= 100:
        fg_hex = light[0]['hex']

    saturated = [c for c in colors if c['sat'] > 0.2 and 30 < c['lum'] < 200]
    accent_hex = everforest.get('accent', '#7fbbb3')
    # Accent must be visible: luminance 60-220, distinct from bg, avoid skin-tone
    accent_candidates = [c for c in saturated
        if 60 < c['lum'] < 220
        and c['hex'] != bg_hex
        and (abs(c['hue'] - 0.02) > 0.1 or c['sat'] < 0.4)]
    if accent_candidates:
        best_accent = max(accent_candidates, key=lambda c: c['sat'])
        accent_hex = best_accent['hex']
    else:
        best = next((c for c in saturated if 60 < c['lum'] < 220 and c['hex'] != bg_hex), None)
        accent_hex = best['hex'] if best else accent_hex

    ansi = list(EVERFOREST_ANSI)
    for idx, (lo, hi) in enumerate(HUE_RANGES):
        for c in saturated:
            if in_hue_range(c['hue'], lo, hi):
                score = c['sat'] * 2 + (1 - abs(c['lum'] - 140) / 140)
                if score > 0:
                    ansi[idx] = c['hex']
                break

    color0_hex = dark[2]['hex'] if len(dark) > 2 else mantle_hex
    if len(dark) > 1 and dark[0]['lum'] < 50:
        color0_hex = dark[1]['hex']

    out = f'''accent = "{accent_hex}"
cursor = "{fg_hex}"
foreground = "{fg_hex}"
background = "{bg_hex}"
mantle = "{mantle_hex}"
selection_foreground = "{bg_hex}"
selection_background = "{fg_hex}"

color0 = "{color0_hex}"
color1 = "{ansi[0]}"
color2 = "{ansi[1]}"
color3 = "{ansi[2]}"
color4 = "{ansi[3]}"
color5 = "{ansi[4]}"
color6 = "{ansi[5]}"
color7 = "{fg_hex}"
color8 = "{color0_hex}"
color9 = "{ansi[0]}"
color10 = "{ansi[1]}"
color11 = "{ansi[2]}"
color12 = "{ansi[3]}"
color13 = "{ansi[4]}"
color14 = "{ansi[5]}"
color15 = "{fg_hex}"
'''
    with open(output_toml, 'w') as f:
        f.write(out)

if __name__ == '__main__':
    main()
PYEOF
