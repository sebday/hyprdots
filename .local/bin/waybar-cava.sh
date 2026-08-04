#!/bin/bash
# Cava visualiser for waybar (JSON). Hidden when idle via hide-empty-text + exec-if.

bar="⠀⠁⠃⠇⡏⡟⡿⣿"
dict="s/;//g"
bar_length=${#bar}

for ((i = 0; i < bar_length; i++)); do
    dict+=";s/$i/${bar:$i:1}/g"
done

json_line() {
    jq -cn --arg text "$1" '{text: $text}'
}

# Silent = only blank braille (index 0) and whitespace.
is_silent() {
    local line="$1"
    local stripped="${line//$'\n'/}"
    stripped="${stripped//[[:space:]]/}"
    [[ -z "$stripped" ]] && return 0
    local c ch all_blank=1
    for ((c = 0; c < ${#stripped}; c++)); do
        ch=${stripped:c:1}
        if [[ "$ch" != "⠀" ]]; then
            all_blank=0
            break
        fi
    done
    ((all_blank))
}

config_file="/tmp/bar_cava_config"
cat >"$config_file" <<EOF
[general]
bars = 10

[input]
method = pulse
source = auto
monstercat = true

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
EOF

pkill -f "cava -p $config_file" 2>/dev/null || true

silent_streak=0
cava -p "$config_file" 2>/dev/null | sed -u -e "$dict" | while IFS= read -r line; do
    if is_silent "$line"; then
        json_line ""
        silent_streak=$((silent_streak + 1))
        # Exit so waybar re-runs exec-if and can drop the module when idle.
        if ((silent_streak >= 8)); then
            exit 0
        fi
    else
        silent_streak=0
        json_line "$line"
    fi
done
