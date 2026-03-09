#!/bin/bash
# Update fuzzel theme from current/fuzzel.conf (parse key=value, no source)

FUZZEL_CONFIG="$HOME/.config/fuzzel/fuzzel.ini"
FUZZEL_THEME="$HOME/.themes/current/fuzzel.conf"

[ -f "$FUZZEL_THEME" ] || exit 0
[ -f "$FUZZEL_CONFIG" ] || exit 0

get_val() { grep "^$1=" "$FUZZEL_THEME" 2>/dev/null | cut -d= -f2- | tr -d '\n'; }

bg=$(get_val fuzzel_background)
txt=$(get_val fuzzel_text)
match=$(get_val fuzzel_match)
sel=$(get_val fuzzel_selection)
sel_match=$(get_val fuzzel_selection_match)
sel_txt=$(get_val fuzzel_selection_text)
border=$(get_val fuzzel_border)

[ -n "$bg" ] && sed -i "s|^background=.*|background=$bg|" "$FUZZEL_CONFIG"
[ -n "$txt" ] && sed -i "s|^text=.*|text=$txt|" "$FUZZEL_CONFIG"
[ -n "$match" ] && sed -i "s|^match=.*|match=$match|" "$FUZZEL_CONFIG"
[ -n "$sel" ] && sed -i "s|^selection=.*|selection=$sel|" "$FUZZEL_CONFIG"
[ -n "$sel_match" ] && sed -i "s|^selection-match=.*|selection-match=$sel_match|" "$FUZZEL_CONFIG"
[ -n "$sel_txt" ] && sed -i "s|^selection-text=.*|selection-text=$sel_txt|" "$FUZZEL_CONFIG"
[ -n "$border" ] && sed -i "s|^border=.*|border=$border|" "$FUZZEL_CONFIG"
