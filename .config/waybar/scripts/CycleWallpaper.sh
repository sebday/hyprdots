#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/OneDrive/Pictures/Wallpapers"
STATE_FILE="$HOME/.cache/current_wallpaper_path.txt" # Stores the path of the current wallpaper
DIRECTION=${1:-next} # Default to 'next' if no argument is provided

# Ensure the wallpaper directory exists
if [ ! -d "$WALLPAPER_DIR" ]; then
    echo "Error: Wallpaper directory '$WALLPAPER_DIR' not found." >&2
    if command -v notify-send &> /dev/null; then
        notify-send "Wallpaper Cycler Error" "Directory '$WALLPAPER_DIR' not found."
    fi
    exit 1
fi

# Get a sorted list of wallpaper files
# Using null delimiter for safety with filenames containing spaces, etc.
mapfile -d $'\0' wallpapers < <(find "$WALLPAPER_DIR" -type f \( \
    -iname "*.png" -o \
    -iname "*.jpg" -o \
    -iname "*.jpeg" -o \
    -iname "*.gif" -o \
    -iname "*.bmp" -o \
    -iname "*.webp" \
    \) -print0 | sort -z)

# Check if any wallpapers were found
if [ ${#wallpapers[@]} -eq 0 ]; then
    echo "No wallpapers found in '$WALLPAPER_DIR'." >&2
    if command -v notify-send &> /dev/null; then
        notify-send "Wallpaper Cycler" "No wallpapers found in '$WALLPAPER_DIR'."
    fi
    exit 0 # Not an error, just nothing to do
fi

# Read the path of the previously set wallpaper
current_wallpaper_path=""
if [ -f "$STATE_FILE" ]; then
    current_wallpaper_path=$(cat "$STATE_FILE")
fi

# Find the index of the current wallpaper in the list
current_idx=-1
if [[ "$DIRECTION" != "random" ]]; then # No need to find current if we're going random
    for i in "${!wallpapers[@]}"; do
        if [[ "${wallpapers[$i]}" == "$current_wallpaper_path" ]]; then
            current_idx=$i
            break
        fi
    done
fi

# Determine the index of the target wallpaper
target_idx=0
if [[ "$DIRECTION" == "random" ]]; then
    if [ ${#wallpapers[@]} -gt 0 ]; then
        target_idx=$(( RANDOM % ${#wallpapers[@]} ))
    else 
        target_idx=0 # Should be caught by earlier check, but defensive
    fi
elif [ "$current_idx" -ne -1 ]; then
    if [[ "$DIRECTION" == "next" ]]; then
        target_idx=$(( (current_idx + 1) % ${#wallpapers[@]} ))
    elif [[ "$DIRECTION" == "prev" ]]; then
        target_idx=$(( (current_idx - 1 + ${#wallpapers[@]}) % ${#wallpapers[@]} ))
    else
        echo "Invalid direction: $DIRECTION. Use 'next', 'prev', or 'random'." >&2
        exit 1
    fi
else
    # If current wallpaper not found in list or state file empty (and not 'random')
    if [[ "$DIRECTION" == "next" ]]; then
        target_idx=0
    elif [[ "$DIRECTION" == "prev" ]]; then
        target_idx=$(( ${#wallpapers[@]} - 1 ))
    else
        echo "Invalid direction: $DIRECTION. Use 'next', 'prev', or 'random'." >&2
        exit 1
    fi
fi

if [ "$target_idx" -lt 0 ]; then # Should not happen with modulo if array not empty
    target_idx=$(( ${#wallpapers[@]} - 1 ))
fi

next_wallpaper="${wallpapers[$target_idx]}"

# Ensure next_wallpaper is not empty
if [ -z "$next_wallpaper" ]; then
    echo "Error: Failed to determine target wallpaper." >&2
    if command -v notify-send &> /dev/null; then
        notify-send "Wallpaper Cycler Error" "Failed to determine target wallpaper."
    fi
    exit 1
fi

# Preload the selected wallpaper
echo "Preloading: $next_wallpaper"
if ! hyprctl hyprpaper preload "$next_wallpaper"; then
    echo "Warning: Failed to preload wallpaper. 'hyprctl hyprpaper preload \"$next_wallpaper\"' command failed." >&2
    # Continue regardless, as wallpaper setting might still work
fi

# Get monitor names
mapfile -t monitors < <(hyprctl monitors | grep "Monitor " | awk '{print $2}')

wallpaper_set_successfully=false
if [ ${#monitors[@]} -eq 0 ]; then
    echo "Warning: No monitors found by hyprctl. Attempting to set wallpaper globally using ',PATH'." >&2
    echo "Attempting global: hyprctl hyprpaper wallpaper \",$next_wallpaper\"" # DEBUG
    if hyprctl hyprpaper wallpaper ",$next_wallpaper"; then
        wallpaper_set_successfully=true
    else
        error_code=$?
        err_msg="Error setting wallpaper globally. 'hyprctl hyprpaper wallpaper \",$next_wallpaper\"' failed with exit code $error_code. Ensure hyprpaper is running."
        echo "$err_msg" >&2
        if command -v notify-send &> /dev/null; then
            notify-send "Wallpaper Cycler Error" "Could not set wallpaper globally. Exit code: $error_code"
        fi
    fi
else
    # Set the wallpaper for each monitor
    all_monitors_succeeded=true
    for monitor_name in "${monitors[@]}"; do
        echo "Setting wallpaper for $monitor_name to $next_wallpaper"
        echo "Attempting: hyprctl hyprpaper wallpaper \"$monitor_name,$next_wallpaper\"" # DEBUG
        if ! hyprctl hyprpaper wallpaper "$monitor_name,$next_wallpaper"; then
            error_code=$?
            err_msg="Error setting wallpaper for $monitor_name. 'hyprctl hyprpaper wallpaper \"$monitor_name,$next_wallpaper\"' failed with exit code $error_code."
            echo "$err_msg" >&2
            if command -v notify-send &> /dev/null; then
                notify-send "Wallpaper Cycler Error" "Could not set wallpaper for $monitor_name. Exit code: $error_code"
            fi
            all_monitors_succeeded=false
        fi
    done
    if $all_monitors_succeeded; then
        wallpaper_set_successfully=true
    fi
fi

# Save the path of the new wallpaper to the state file only if successfully set
if $wallpaper_set_successfully; then
    echo -n "$next_wallpaper" > "$STATE_FILE"
    exit 0
else
    echo "Wallpaper was not set successfully on any monitor." >&2
    exit 1
fi 