#!/bin/bash
# A script to find a file with fuzzel and open it in a terminal editor, with history.

HISTORY_FILE="/tmp/fuzzyeditor_favs"
touch "$HISTORY_FILE" # Ensure the history file exists

# Get the top 10 most used files from history
# 1. sort history | 2. count unique lines | 3. sort numerically reversed | 4. take top 10 | 5. remove the count part
MOST_USED=$(sort "$HISTORY_FILE" | uniq -c | sort -rn | head -n 10 | sed 's/^[ ]*[0-9]* //')

# A function to locate all files, excluding unwanted directories
get_all_files() {
    find ~ \( \
        -path '*/.git' -o \
        -path '*/.cache' -o \
        -path '*/node_modules' -o \
        -path '*/target' -o \
        -path '*/__pycache__' -o \
        -path '*/.local/share' -o \
        -path '*/globalStorage' -o \
        -path '*/workspaceStorage' -o \
        -path '*/Cursor' -o \
        -path '*/Brave-Browser' -o \
        -path '*/.var/app' \
        \) -prune -o -type f -print 2>/dev/null
}

# Combine most used and all files, filter out duplicates, and pipe to fuzzel
# The awk '!seen[$0]++' is a robust way to get unique lines while preserving order.
FILE=$( ( (echo "$MOST_USED"; get_all_files) | awk '!seen[$0]++' ) | fuzzel -d --width=80 -p "Search file: " )

# If a file was selected, log it and open it in the terminal editor
if [ -n "$FILE" ]; then
    echo "$FILE" >> "$HISTORY_FILE"
    DIR=$(dirname "$FILE")
    ghostty -e bash -c "cd '$DIR' && nvim . '$FILE' -c 'buffer 2' -c 'bdelete 1' -c 'cd '$DIR''"
fi
