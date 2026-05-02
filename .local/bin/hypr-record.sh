#!/usr/bin/env bash
# https://www.zolkos.com/2025/07/18/screen-recording-omarchy

# Parse command line arguments
COMPRESS=true
FULLSCREEN=false
while [[ $# -gt 0 ]]; do
  case $1 in
  --no-compress)
    COMPRESS=false
    shift
    ;;
  --fullscreen)
    FULLSCREEN=true
    shift
    ;;
  *)
    echo "Unknown option: $1"
    echo "Usage: $0 [--no-compress] [--fullscreen]"
    exit 1
    ;;
  esac
done

SAVE_DIR="$HOME/"
#mkdir -p "$SAVE_DIR"

# ── Stop if already recording ──────────────────────────────────────────────
if pgrep -x wf-recorder >/dev/null; then
  pkill -INT wf-recorder
  
  # Wait up to 3 seconds for graceful shutdown
  for i in {1..15}; do
    pgrep -x wf-recorder >/dev/null || break
    sleep 0.2
  done
  
  # Force kill if still running (prevents infinite loops with stuck processes)
  if pgrep -x wf-recorder >/dev/null; then
    pkill -9 wf-recorder
    sleep 0.5
  fi
  
  LATEST=$(ls -t "$SAVE_DIR"/*.mp4 "$SAVE_DIR"/*.mkv 2>/dev/null | head -n1)

  # Compress the video if enabled
  if [[ "$COMPRESS" == true ]] && command -v ffmpeg >/dev/null && [ -n "$LATEST" ]; then
    notify-send "Compressing video..." "Please wait" --expire-time=2000
    
    BASE_NAME=$(basename "$LATEST")
    FILENAME="${BASE_NAME%.*}"
    
    COMPRESSED="$SAVE_DIR/${FILENAME}_compressed.mp4"

    if ffmpeg -i "$LATEST" -c:v libx264 -crf 23 -preset medium -c:a copy -movflags +faststart "$COMPRESSED" -y 2>/dev/null; then
      # Get file sizes for comparison
      ORIG_SIZE=$(du -h "$LATEST" | cut -f1)
      COMP_SIZE=$(du -h "$COMPRESSED" | cut -f1)
      
      # Replace original with compressed version, ensuring final is .mp4
      FINAL_OUTPUT="$SAVE_DIR/${FILENAME}.mp4"
      
      # Remove original if it was different
      if [ "$LATEST" != "$FINAL_OUTPUT" ]; then
        rm "$LATEST"
      fi
      mv "$COMPRESSED" "$FINAL_OUTPUT"
      
      notify-send "Recording finished & compressed" "Size: $ORIG_SIZE → $COMP_SIZE" --expire-time=2500
      LATEST="$FINAL_OUTPUT"
    else
      notify-send "Recording finished" "Compression failed, keeping original" --expire-time=2500
    fi
  elif [ -n "$LATEST" ]; then
    notify-send "Recording finished" "Path copied: $(basename "$LATEST")" --expire-time=1500
  fi

  if [ -n "$LATEST" ]; then
    # Copy the file path to clipboard as text
    echo "$LATEST" | wl-copy

    # Also try to open the file location in file manager for easy drag-and-drop
    #if command -v xdg-open >/dev/null; then
    #  xdg-open "$(dirname "$LATEST")" &
    #fi
  fi

  # Signal waybar to update
  pkill -RTMIN+8 waybar 2>/dev/null || true
  
  exit 0
fi

# ── Pick region or fullscreen ──────────────────────────────────────────────
WF_RECORDER_OPTS=()
if [[ "$FULLSCREEN" == true ]]; then
  OUTPUT=$(hyprctl monitors | awk '/focused: yes/{print prev} /Monitor/{prev=$2}')
  if [ -z "$OUTPUT" ]; then
    notify-send "Error: Could not find focused monitor."
    exit 1
  fi
  WF_RECORDER_OPTS+=(-o "$OUTPUT")
  NOTIFY_MSG_GEOMETRY="fullscreen"
else
  REGION=$(slurp) || exit 1
  WF_RECORDER_OPTS+=(-g "$REGION")
  NOTIFY_MSG_GEOMETRY="region"
fi

FILE="$SAVE_DIR/$(date +'%Y-%m-%d_%H-%M-%S').mp4"
WF_RECORDER_OPTS+=(-f "$FILE")

# ── Choose which ONE source to record ──────────────────────────────────────
MIC_SRC=$(pactl info | awk -F': ' '/Default Source/ {print $2}')
WF_RECORDER_OPTS+=(--audio="$MIC_SRC")
DESC=$(pactl list sources | awk -v s="$MIC_SRC" '$2==s {getline;sub(/^\s*Description: /,"");print;exit}')
notify-send "Recording $NOTIFY_MSG_GEOMETRY… (source: $DESC)" --expire-time=1000

wf-recorder "${WF_RECORDER_OPTS[@]}" &


# Signal waybar to update
pkill -RTMIN+8 waybar 2>/dev/null || true
