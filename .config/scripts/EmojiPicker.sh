#!/bin/bash
# A script to select an emoji with fuzzel and copy it to the clipboard.

EMOJI_FILE="$HOME/.config/scripts/Emojis.txt"

# Check if the emoji file exists
if [ ! -f "$EMOJI_FILE" ]; then
    notify-send "Emoji Picker Error" "Emoji file not found at:\n$EMOJI_FILE"
    exit 1
fi

# Use fuzzel to select an emoji
# The output is the full line, e.g., "😀 grinning face"
selected_line=$(cat "$EMOJI_FILE" | fuzzel --dmenu --width=50 --prompt='Search emoji: ')

# If a line was selected, extract the emoji and copy it to the clipboard
if [ -n "$selected_line" ]; then
    # awk prints the first field (the emoji)
    emoji=$(echo "$selected_line" | awk '{print $1}')
    
    # Copy to clipboard using wl-copy
    echo -n "$emoji" | wl-copy
    
    # Notify the user
    notify-send "Emoji Copied" "$emoji has been copied to the clipboard."
fi 