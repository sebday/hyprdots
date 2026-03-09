#!/bin/bash
# Shared helpers for theme scripts

toml_val() {
    local key="$1" toml="$2"
    grep "^$key " "$toml" 2>/dev/null | sed 's/.*= *"//;s/".*//' | tr -d '\n'
}

# Darken hex color by 20% (multiply RGB by 0.8)
darken_hex() {
    local hex="$1"
    hex="${hex#\#}"
    [ ${#hex} -eq 6 ] || return 1
    local r=$((0x${hex:0:2})) g=$((0x${hex:2:2})) b=$((0x${hex:4:2}))
    r=$((r * 80 / 100)); [ $r -lt 0 ] && r=0; [ $r -gt 255 ] && r=255
    g=$((g * 80 / 100)); [ $g -lt 0 ] && g=0; [ $g -gt 255 ] && g=255
    b=$((b * 80 / 100)); [ $b -lt 0 ] && b=0; [ $b -gt 255 ] && b=255
    printf '#%02x%02x%02x' "$r" "$g" "$b"
}
