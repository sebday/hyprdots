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

# Fetch recent public activity (last 30 events by default)
API_URL="https://api.github.com/users/${USERNAME}/events/public"

# Use -s for silent, -L to follow redirects
RESPONSE=$(curl -s -L -H "Authorization: token ${TOKEN}" -H "Accept: application/vnd.github.v3+json" "${API_URL}")

# Check if curl command was successful and response is not empty
if [[ -z "$RESPONSE" ]]; then
    echo '{"text": " Error", "tooltip": "Failed to fetch GitHub activity or empty response", "class": "error"}'
    exit 1
fi

# Count the number of events.
EVENT_COUNT=$(echo "${RESPONSE}" | jq '. | length')

# Check if jq command was successful and EVENT_COUNT is a number
if ! [[ "$EVENT_COUNT" =~ ^[0-9]+$ ]]; then
    ERROR_MSG=$(echo "${RESPONSE}" | jq -r '.message // "Unknown error parsing response"')
    echo '{"text": " Error", "tooltip": "Failed to parse GitHub activity: '${ERROR_MSG}'", "class": "error"}'
    exit 1
fi

if [[ "$EVENT_COUNT" != "0" ]]; then
    # Output JSON for Waybar
    # Text: GitHub icon () followed by event count
    # Tooltip: Shows "X recent activities"
    echo "{\"text\": \" ${EVENT_COUNT}\", \"tooltip\": \"${EVENT_COUNT} recent public GitHub activities for ${USERNAME}\", \"class\": \"github-activity\"}"
else
    # No recent activity or count is zero
    echo "{\"text\": \" 0\", \"tooltip\": \"No recent public GitHub activity for ${USERNAME}\", \"class\": \"github-activity-none\"}"
fi 