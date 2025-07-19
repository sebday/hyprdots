#!/bin/bash
# A script to find a file with fuzzel and open it in a terminal editor.

# Find a file using find and pipe it to fuzzel.
# Exclude common unwanted directories.
FILE=$(find ~ \( \
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
    \) -prune -o -type f -print 2>/dev/null | fuzzel -d --width=80 -p "Search file: ")

# If a file was selected, open it in the terminal editor
if [ -n "$FILE" ]; then
    eval "$1" "'$FILE'"
fi