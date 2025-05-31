#!/bin/bash

# GitHub username
USERNAME="sebday"

# Path to your GitHub personal access token
TOKEN_PATH="${HOME}/.ssh/github"

if [[ ! -f "${TOKEN_PATH}" ]]; then
    echo '{"text": " Error", "tooltip": "GitHub token not found at '${TOKEN_PATH}'", "class": "error"}'
    exit 1
fi

TOKEN=$(cat "${TOKEN_PATH}")

# Fetch recent public activity (up to 100 events)
# We fetch more to get a better view for the 7-day history
API_URL="https://api.github.com/users/${USERNAME}/events/public?per_page=100"

RESPONSE=$(curl -s -L -H "Authorization: token ${TOKEN}" -H "Accept: application/vnd.github.v3+json" "${API_URL}")

if [[ -z "$RESPONSE" ]]; then
    echo '{"text": " Error", "tooltip": "Failed to fetch GitHub activity or empty response", "class": "error"}'
    exit 1
fi

# Extract just the created_at dates for easier processing
EVENT_DATES_JSON=$(echo "${RESPONSE}" | jq -r '[.[] .created_at]')

if [[ -z "$EVENT_DATES_JSON" ]] || [[ "$EVENT_DATES_JSON" == "null" ]] || [[ "$EVENT_DATES_JSON" == "[]" ]]; then
    # Handle case where no events are returned or jq fails to parse dates
    TODAY_COUNT=0
    ACTIVITY_BOXES="□□□□□□□" # 7 empty boxes
    echo "{\"text\": \" Today: ${TODAY_COUNT} ${ACTIVITY_BOXES}\", \"tooltip\": \"No public GitHub activity found for ${USERNAME}\", \"class\": \"github-activity-none\"}"
    exit 0
fi

# Calculate today's contribution count
TODAY_ISO=$(date -u +'%Y-%m-%d')
TODAY_COUNT=$(echo "${EVENT_DATES_JSON}" | jq --arg day_iso "${TODAY_ISO}" '[.[] | select(. | startswith($day_iso))] | length')

# Check if jq failed for TODAY_COUNT (e.g. if EVENT_DATES_JSON was not valid array)
if ! [[ "$TODAY_COUNT" =~ ^[0-9]+$ ]]; then
    TODAY_COUNT=0 # Default to 0 on error
fi

# Generate 7-day activity boxes (rightmost is today)
ACTIVITY_BOXES=""
for i in {6..0}; do # Iterate from 6 days ago to today
    DAY_ISO=$(date -u -d "${i} days ago" +'%Y-%m-%d')
    HAS_ACTIVITY_ON_DAY=$(echo "${EVENT_DATES_JSON}" | jq --arg day_iso "${DAY_ISO}" 'map(select(. | startswith($day_iso))) | length > 0')

    if [[ "$HAS_ACTIVITY_ON_DAY" == "true" ]]; then
        ACTIVITY_BOXES="■${ACTIVITY_BOXES}" # Prepend to reverse order for display
    else
        ACTIVITY_BOXES="□${ACTIVITY_BOXES}" # Prepend
    fi
done
# The loop builds boxes in reverse, so Day6 Day5 ... Today. To make rightmost today, we need to build Today, Yesterday ... Day6
# Corrected loop for rightmost is today:
ACTIVITY_BOXES=""
for i in {0..6}; do # Iterate from today (0) to 6 days ago
    DAY_ISO=$(date -u -d "${i} days ago" +'%Y-%m-%d')
    # Check if any event date string starts with DAY_ISO
    MATCHING_EVENTS=$(echo "${EVENT_DATES_JSON}" | jq --arg day_iso "$DAY_ISO" '[.[] | select(. | startswith($day_iso))]')
    if [[ $(echo "$MATCHING_EVENTS" | jq 'length') -gt 0 ]]; then
        ACTIVITY_BOXES_TEMP="■"
    else
        ACTIVITY_BOXES_TEMP="□"
    fi
    # To make the rightmost box today, we build the string from left (6 days ago) to right (today)
    # So, for i=0 (today), it's the last char. For i=6 (6 days ago), it's the first.
    # Let's build it in order: Day6, Day5, ..., Day0 (Today)
    if [[ $i -eq 0 ]]; then
      TODAY_BOX=$ACTIVITY_BOXES_TEMP
    elif [[ $i -eq 1 ]]; then
      YESTERDAY_BOX=$ACTIVITY_BOXES_TEMP
    elif [[ $i -eq 2 ]]; then
      DAY2_BOX=$ACTIVITY_BOXES_TEMP
    elif [[ $i -eq 3 ]]; then
      DAY3_BOX=$ACTIVITY_BOXES_TEMP
    elif [[ $i -eq 4 ]]; then
      DAY4_BOX=$ACTIVITY_BOXES_TEMP
    elif [[ $i -eq 5 ]]; then
      DAY5_BOX=$ACTIVITY_BOXES_TEMP
    elif [[ $i -eq 6 ]]; then
      DAY6_BOX=$ACTIVITY_BOXES_TEMP
    fi
done
ACTIVITY_BOXES="${DAY6_BOX}${DAY5_BOX}${DAY4_BOX}${DAY3_BOX}${DAY2_BOX}${YESTERDAY_BOX}${TODAY_BOX}"


# Prepare output
TEXT_OUTPUT=" Today: ${TODAY_COUNT} ${ACTIVITY_BOXES}"
TOOLTIP_TEXT="${TODAY_COUNT} contributions today. 7-day activity for ${USERNAME} (oldest to newest)."

echo "{\"text\": \"${TEXT_OUTPUT}\", \"tooltip\": \"${TOOLTIP_TEXT}\", \"class\": \"github-activity\"}" 