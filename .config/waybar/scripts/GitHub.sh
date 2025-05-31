#!/bin/bash

# GitHub username
USERNAME="sebday"

# Path to your GitHub personal access token
TOKEN_PATH="${HOME}/.ssh/github"

# --- Token Validation ---
if [[ ! -f "${TOKEN_PATH}" ]]; then
    echo '{"text": " Error", "tooltip": "GitHub token file not found at '${TOKEN_PATH}'", "class": "error"}' >&2
    echo '{"text": " Token File Err", "tooltip": "Token file missing."}'
    exit 1
fi

TOKEN=$(cat "${TOKEN_PATH}")

if [[ -z "$TOKEN" ]]; then
    echo '{"text": " Error", "tooltip": "GitHub token is empty in '${TOKEN_PATH}'", "class": "error"}' >&2
    echo '{"text": " Empty Token Err", "tooltip": "Token file is empty."}'
    exit 1
fi

# --- Fetch Contribution Count for Today (UTC) using GraphQL ---
TODAY_UTC_ISO=$(date -u +'%Y-%m-%d')

# GraphQL query to get the contribution calendar for the last year
GRAPHQL_QUERY_RAW='
query GetUserContributionCalendar($username: String!) {
  user(login: $username) {
    contributionsCollection {
      contributionCalendar {
        weeks {
          contributionDays {
            contributionCount
            date
          }
        }
      }
    }
  }
}
'

# Prepare JSON payload for curl
# 1. Replace newlines with spaces, escape double quotes for the query string itself.
# 2. Construct the JSON payload string.
GRAPHQL_QUERY_ESCAPED=$(echo "$GRAPHQL_QUERY_RAW" | tr '\n' ' ' | sed 's/"/\\"/g')
JSON_PAYLOAD=$(printf '{ "query": "%s", "variables": { "username": "%s" } }' "$GRAPHQL_QUERY_ESCAPED" "$USERNAME")

# Make the GraphQL API call
RESPONSE=$(curl -s -L \
    -H "Authorization: bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -X POST \
    -d "${JSON_PAYLOAD}" \
    "https://api.github.com/graphql")

# --- Response Handling & Output ---
# Check for empty curl response
if [[ -z "$RESPONSE" ]]; then
    echo '{"text": " Error", "tooltip": "Failed to fetch GitHub contributions (empty GraphQL response)", "class": "error"}' >&2
    echo '{"text": " Curl Err", "tooltip": "GraphQL Curl returned empty."}'
    exit 1
fi

# Check for errors in the GraphQL response (e.g., .errors array)
if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    ERROR_MESSAGE=$(echo "$RESPONSE" | jq -r '.errors[0].message // "Unknown GraphQL error"')
    echo "{\"text\": \" GQL Err\", \"tooltip\": \"GraphQL Error: ${ERROR_MESSAGE}\", \"class\": \"error\"}" >&2
    echo "{\"text\": \" GQL Err (${ERROR_MESSAGE:0:10})\", \"tooltip\": \"GraphQL Error: ${ERROR_MESSAGE}\"}"
    exit 1
fi

# Extract today's contribution count from the calendar
# If jq processing fails or path is not found, result might be null or empty string.
TODAY_CONTRIBUTION_COUNT=$(echo "$RESPONSE" | jq --arg today_date "$TODAY_UTC_ISO" -r '
  .data.user.contributionsCollection.contributionCalendar.weeks[].contributionDays[] |
  select(.date == $today_date) |
  .contributionCount
')

# Default to 0 if count is empty (no entry for today / user just created) or not a number
if ! [[ "$TODAY_CONTRIBUTION_COUNT" =~ ^[0-9]+$ ]]; then
    echo "DEBUG: Failed to parse today contribution count or no entry for today. Count set to 0. JQ Output: '$TODAY_CONTRIBUTION_COUNT'" >&2
    TODAY_CONTRIBUTION_COUNT=0
fi

# --- Prepare Waybar Output ---
TEXT_OUTPUT=" Today: ${TODAY_CONTRIBUTION_COUNT}"
TOOLTIP_TEXT="${TODAY_CONTRIBUTION_COUNT} contributions today (as per GitHub graph, UTC ${TODAY_UTC_ISO}, by ${USERNAME})."
CLASS="github-contributions"

echo "{\"text\": \"${TEXT_OUTPUT}\", \"tooltip\": \"${TOOLTIP_TEXT}\", \"class\": \"${CLASS}\"}" 