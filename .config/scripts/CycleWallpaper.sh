#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/OneDrive/Pictures/Wallpapers"
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

# Get the path of the current wallpaper from the active list. This is more reliable.
# It might look like: "Wallpaper /path/to/foo.jpg is active on monitor DP-1"
# We parse the path from it.
current_wallpaper_path=$(hyprctl hyprpaper listactive | head -n 1 | sed -n 's/^Wallpaper \(.*\) is active on monitor.*$/\1/p')

# Fallback to listloaded if listactive is empty (e.g., on initial run)
if [ -z "$current_wallpaper_path" ]; then
    echo "Info: hyprctl listactive was empty. Falling back to listloaded." >&2
    current_wallpaper_path=$(hyprctl hyprpaper listloaded | head -n 1)
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

target_wallpaper="${wallpapers[$target_idx]}"

# Ensure next_wallpaper is not empty
if [ -z "$target_wallpaper" ]; then
    echo "Error: Failed to determine target wallpaper." >&2
    if command -v notify-send &> /dev/null; then
        notify-send "Wallpaper Cycler Error" "Failed to determine target wallpaper."
    fi
    exit 1
fi

# Preload the target wallpaper
if ! hyprctl hyprpaper preload "$target_wallpaper"; then
    err_msg="Error: Failed to preload wallpaper: $target_wallpaper"
    echo "$err_msg" >&2
    if command -v notify-send &> /dev/null; then
        notify-send "Wallpaper Cycler Error" "$err_msg"
    fi
    exit 1
fi

# Get monitor names from hyprctl
mapfile -t monitors < <(hyprctl monitors | grep "Monitor " | awk '{print $2}')

wallpaper_set_successfully=false
# Set the wallpaper for each monitor. Fallback to global if no monitors found.
if [ ${#monitors[@]} -eq 0 ]; then
    echo "Warning: No monitors found by hyprctl. Attempting to set wallpaper globally." >&2
    if hyprctl hyprpaper wallpaper ",$target_wallpaper"; then
        wallpaper_set_successfully=true
    fi
else
    all_monitors_succeeded=true
    for monitor_name in "${monitors[@]}"; do
        echo "Setting wallpaper for $monitor_name to $target_wallpaper"
        if ! hyprctl hyprpaper wallpaper "$monitor_name,$target_wallpaper"; then
            error_code=$?
            err_msg="Error setting wallpaper for $monitor_name. Exit code: $error_code"
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

if $wallpaper_set_successfully; then
    echo "Wallpaper set successfully."
else
    echo "Error: Failed to set wallpaper on any monitor." >&2
    # Even if setting wallpaper fails, we should still try to unload
fi

# Unload unused wallpapers to free up memory
if ! hyprctl hyprpaper unload unused; then
    echo "Warning: Failed to unload unused wallpapers." >&2
fi 