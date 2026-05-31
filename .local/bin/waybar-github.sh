#!/bin/bash

# GitHub username
USERNAME="sebday"

# --- Token Validation ---
if ! TOKEN=$(pass show github/token 2>/dev/null); then
    echo '{"text": " Error", "tooltip": "GitHub token not found in pass (github/token)", "class": "error"}' >&2
    echo '{"text": " Pass Err", "tooltip": "Run: pass insert github/token"}'
    exit 1
fi

if [[ -z "$TOKEN" ]]; then
    echo '{"text": " Error", "tooltip": "GitHub token is empty in pass (github/token)", "class": "error"}' >&2
    echo '{"text": " Empty Token Err", "tooltip": "Token is empty."}'
    exit 1
fi

# --- Get Contribution Colors ---
WAYBAR_CSS="$HOME/.themes/current/waybar.css"
declare -A CONTRIB_COLORS

if [ -f "$WAYBAR_CSS" ]; then
    for i in {0..4}; do
        color=$(grep "@define-color github-$i" "$WAYBAR_CSS" | awk '{print $3}' | tr -d ';')
        if [ -n "$color" ]; then
            CONTRIB_COLORS[$i]="$color"
        fi
    done
fi

# If colors weren't loaded completely, use defaults
if [ "${#CONTRIB_COLORS[@]}" -ne 5 ]; then
    CONTRIB_COLORS=(
        [0]="#ebedf0" # Level 0
        [1]="#9be9a8" # Level 1
        [2]="#40c463" # Level 2
        [3]="#30a14e" # Level 3
        [4]="#216e39" # Level 4
    )
fi

# --- Fetch Contribution Data using GraphQL ---
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
GRAPHQL_QUERY_ESCAPED=$(echo "$GRAPHQL_QUERY_RAW" | tr '\n' ' ' | sed 's/"/\\"/g')
JSON_PAYLOAD=$(printf '{ "query": "%s", "variables": { "username": "%s" } }' "$GRAPHQL_QUERY_ESCAPED" "$USERNAME")

RESPONSE=$(curl -s -L \
    -H "Authorization: bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -X POST \
    -d "${JSON_PAYLOAD}" \
    "https://api.github.com/graphql")

# --- Response Handling & Initial Parsing ---
if [[ -z "$RESPONSE" ]]; then
    echo '{"text": " Curl Err", "tooltip": "GraphQL Curl returned empty."}'
    exit 1
fi

if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    ERROR_MESSAGE=$(echo "$RESPONSE" | jq -r '.errors[0].message // "Unknown GraphQL error"')
    echo "{\"text\": \" GQL Err (${ERROR_MESSAGE:0:10})\", \"tooltip\": \"GraphQL Error: ${ERROR_MESSAGE}\"}"
    exit 1
fi

# Extract all contribution days and store in an associative array
declare -A contribs_by_date
ALL_DAYS_DATA=$(echo "$RESPONSE" | jq -r '
    .data.user.contributionsCollection.contributionCalendar.weeks[]?.contributionDays[]? |
    select(.date != null and .contributionCount != null) |
    "\(.date)_\(.contributionCount)"
')

ACTIVITY_BOXES_STRING_FOR_JSON=""

if [[ -z "$ALL_DAYS_DATA" ]]; then
    TODAY_CONTRIBUTION_COUNT=0
    COLOR_LEVEL_0=${CONTRIB_COLORS[0]}
    for i in {1..14}; do ACTIVITY_BOXES_STRING_FOR_JSON+="<span fgcolor='${COLOR_LEVEL_0}'>■</span>"; done
else
    while IFS=_ read -r date_val count_val; do
        contribs_by_date["$date_val"]=$count_val
    done <<< "$ALL_DAYS_DATA"

    LOCAL_TODAY_ISO=$(date +'%Y-%m-%d') # Determine today based on local timezone

    TEMP_BOXES_STRING=""
    # Iterate from 6 days prior to local today, up to local today
    for i in {13..0}; do
        DAY_ISO=$(date -d "${LOCAL_TODAY_ISO} - ${i} days" +'%Y-%m-%d') # Calculate date relative to local today
        COUNT_FOR_DAY=${contribs_by_date["$DAY_ISO"]:-0}

        LEVEL=0 # Default for 0 contributions
        if [[ "$COUNT_FOR_DAY" -ge 1 && "$COUNT_FOR_DAY" -le 9 ]]; then
            LEVEL=1
        elif [[ "$COUNT_FOR_DAY" -ge 10 && "$COUNT_FOR_DAY" -le 17 ]]; then
            LEVEL=2
        elif [[ "$COUNT_FOR_DAY" -ge 18 && "$COUNT_FOR_DAY" -le 29 ]]; then
            LEVEL=3
        elif [[ "$COUNT_FOR_DAY" -ge 30 ]]; then
            LEVEL=4
        fi
        COLOR=${CONTRIB_COLORS[$LEVEL]}
        TEMP_BOXES_STRING+="<span fgcolor='${COLOR}'>■</span>"
    done
    ACTIVITY_BOXES_STRING_FOR_JSON=$TEMP_BOXES_STRING

    TODAY_CONTRIBUTION_COUNT=${contribs_by_date["$LOCAL_TODAY_ISO"]:-0} # Use local today's date to get count
fi

# Determine level for today's contribution count
TODAY_LEVEL=0 # Default for 0 contributions
if [[ "$TODAY_CONTRIBUTION_COUNT" -ge 1 && "$TODAY_CONTRIBUTION_COUNT" -le 9 ]]; then
    TODAY_LEVEL=1
elif [[ "$TODAY_CONTRIBUTION_COUNT" -ge 10 && "$TODAY_CONTRIBUTION_COUNT" -le 17 ]]; then
    TODAY_LEVEL=2
elif [[ "$TODAY_CONTRIBUTION_COUNT" -ge 18 && "$TODAY_CONTRIBUTION_COUNT" -le 29 ]]; then
    TODAY_LEVEL=3
elif [[ "$TODAY_CONTRIBUTION_COUNT" -ge 30 ]]; then
    TODAY_LEVEL=4
fi

# --- Prepare Waybar Output ---
TEXT_OUTPUT="  ${TODAY_CONTRIBUTION_COUNT} ${ACTIVITY_BOXES_STRING_FOR_JSON}"
CLASS="github-level-${TODAY_LEVEL}"

# Escape double quotes from Pango markup for final JSON output
ESCAPED_TEXT_OUTPUT=$(echo "$TEXT_OUTPUT" | sed 's/"/\\"/g')

echo "{\"text\": \"${ESCAPED_TEXT_OUTPUT}\", \"class\": \"${CLASS}\"}" 