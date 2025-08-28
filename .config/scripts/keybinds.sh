#!/bin/bash

# Display Hyprland keybindings using fuzzel
# Uses hyprctl to get the active keybindings & temp files to avoid pipeline issues

# Create temp files
HYPRCTL_OUTPUT=$(mktemp)
AWK_OUTPUT=$(mktemp)
SORTED_OUTPUT=$(mktemp)

# Ensure temporary files are cleaned up on exit
trap 'rm -f "$HYPRCTL_OUTPUT" "$AWK_OUTPUT" "$SORTED_OUTPUT"' EXIT

hyprctl binds > "$HYPRCTL_OUTPUT"
awk '
    BEGIN { RS = "\n\n" }
    {
        mod_str = ""; key = ""; description = "";
        split($0, lines, "\n");
        for (i in lines) {
            line = lines[i];
            if (match(line, /modmask: ([0-9]+)/, m)) { mod_mask = m[1]; }
            if (match(line, /key: (.*)/, m)) { key = m[1]; }
            if (match(line, /description: (.*)/, m)) { description = m[1]; }
        }
        if (mod_mask > 0) {
            if (mod_mask >= 64) { mod_str = mod_str "SUPER "; mod_mask -= 64; }
            if (mod_mask >= 8)  { mod_str = mod_str "ALT ";   mod_mask -= 8;  }
            if (mod_mask >= 4)  { mod_str = mod_str "CTRL ";  mod_mask -= 4;  }
            if (mod_mask >= 1)  { mod_str = mod_str "SHIFT "; mod_mask -= 1;  }
            sub(/ $/, "", mod_str);
        }
        key_combo = mod_str != "" ? mod_str " + " key : key;
        if (key != "" && description != "") {
            printf "%-25s → %s\n", key_combo, description;
        }
    }
' "$HYPRCTL_OUTPUT" > "$AWK_OUTPUT"
sort "$AWK_OUTPUT" > "$SORTED_OUTPUT"
fuzzel --width=55 -d -p "󰌌 Keybinds: " < "$SORTED_OUTPUT"