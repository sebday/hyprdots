#!/bin/bash
# Media Player submenu script

# Define media options with Nerd Font icons
options="🎬 Movie Mode\n📺 YouTube\n📺 BBC iPlayer\n📺 Channel 4"

# Use fuzzel to get the user's choice
selected_option=$(echo -e "$options" | fuzzel -d -p "Select media option: ")

case "$selected_option" in
    "🎬 Movie Mode")
        bash ~/.local/bin/fuzzympv.sh
        ;;
    "📺 YouTube")
        brave --app=https://www.youtube.com &
        ;;
    "📺 BBC iPlayer")
        brave --app=https://www.bbc.co.uk/iplayer/continue-watching &
        ;;
    "📺 Channel 4")
        brave --app=https://www.channel4.com/my4/watching &
        ;;
    *)
        # Exit gracefully if nothing was selected
        exit 0
        ;;
esac
