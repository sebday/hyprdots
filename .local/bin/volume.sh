#!/bin/bash
# ~/.config/waybar/scripts/volume.sh

# Usage: $0 {up|down|mute}

# Gets volume, and whether the default sink is muted
get_volume_info() {
    # We need to read the volume and mute status of the default audio sink.
    STATE=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
    # Extract the volume percentage.
    VOLUME=$(echo "$STATE" | awk '{print int($2 * 100)}')
    # Check if the sink is muted.
    MUTED=$(echo "$STATE" | grep -q MUTED && echo "yes" || echo "no")
}

send_notification() {
    get_volume_info
    
    if [ "$MUTED" = "yes" ]; then
        icon="audio-volume-muted"
        text="Muted"
    else
        if [ "$VOLUME" -eq 0 ]; then
            icon="audio-volume-muted"
        elif [ "$VOLUME" -lt 34 ]; then
            icon="audio-volume-low"
        elif [ "$VOLUME" -lt 67 ]; then
            icon="audio-volume-medium"
        else
            icon="audio-volume-high"
        fi
        text="$VOLUME%"
    fi

    # The -h option provides a hint to the notification server.
    # It allows creating progress-bar-like notifications.
    # -r replaces previous notifications from this script.
    notify-send -i "$icon" -r 9993 -h "int:value:$VOLUME" "Volume" "$text" -t 1500
}

case "$1" in
    up)
        # Increase volume and send notification.
        wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+
        send_notification
        ;;
    down)
        # Decrease volume and send notification.
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
        send_notification
        ;;
    mute)
        # Toggle mute and send notification.
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        send_notification
        ;;
    *)
        # Print usage information for invalid arguments.
        echo "Usage: $0 {up|down|mute}"
        exit 1
esac 