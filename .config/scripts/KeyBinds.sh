#!/bin/bash

# A script to display Hyprland keybindings defined in your configuration
# using wofi for an interactive search menu.

USER_HYPRLAND_CONF="$HOME/.config/hypr/hyprland.conf"

# Process the configuration file to extract and format keybindings
# 1. `grep` finds all lines starting with 'bind' (allowing for leading spaces).
# 2. The first `sed` removes comments (anything after a '#').
# 3. `awk` does the heavy lifting of formatting the output.
#    - It sets the field separator to a comma ','.
#    - It removes the 'bind... =' part from the beginning of the line.
#    - It joins the key combination (e.g., "SUPER + Q").
#    - It joins the command that the key executes.
#    - It prints everything in a nicely aligned format.
# 4. The final `sed` cleans up any leftover commas from the end of lines.
grep -h '^[[:space:]]*bind' $USER_HYPRLAND_CONF |
  sed '/^[[:space:]]*$/d' |
  sort -u |
  awk -F, '
{
    # Extract friendly name from comment
    friendly_name = "";
    if (match($0, /#[ \t]*(.*)/, arr)) {
        friendly_name = arr[1];
        gsub(/^[ \t]+|[ \t]+$/, "", friendly_name);
    }

    # Strip trailing comments from the line to not interfere with parsing
    sub(/#.*/, "");

    # Remove the "bind... =" part and surrounding whitespace
    sub(/^[[:space:]]*bind[^=]*=(\+[[:space:]])?(exec, )?[[:space:]]*/, "", $1);

    # Combine the modifier and key (first two fields)
    key_combo = $1 " + " $2;

    # Clean up: strip leading "+" if present, trim spaces
    gsub(/^[ \t]*\+?[ \t]*/, "", key_combo);
    gsub(/[ \t]+$/, "", key_combo);

    # Reconstruct the command from the remaining fields
    action = "";
    for (i = 3; i <= NF; i++) {
        action = action $i (i < NF ? "," : "");
    }

    # Clean up trailing commas, remove leading "exec, ", and trim
    sub(/,$/, "", action);
    gsub(/(^|,)[[:space:]]*exec[[:space:]]*,?/, "", action);
    gsub(/^[ \t]+|[ \t]+$/, "", action);
    gsub(/[ \t]+/, " ", key_combo);  # Collapse multiple spaces to one

    # Use friendly name if available, otherwise use the action
    display_action = friendly_name != "" ? friendly_name : action;

    if (action != "") {
        printf "%-25s → %s\n", key_combo, display_action;
    }
}' |
  fuzzel --dmenu --width=80