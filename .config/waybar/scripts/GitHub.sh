#!/bin/bash

# --- Logging Setup ---
# To debug, check this log file. It is cleared on each run.
LOG_FILE="/tmp/github-waybar.log"
echo "--- GitHub Waybar Script Execution --- $(date)" > "${LOG_FILE}"

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
echo "Token loaded, length: ${#TOKEN}" >> "${LOG_FILE}"

if [[ -z "$TOKEN" ]]; then
    echo '{"text": " Error", "tooltip": "GitHub token is empty in '${TOKEN_PATH}'", "class": "error"}' >&2
    echo '{"text": " Empty Token Err", "tooltip": "Token file is empty."}'
    exit 1
fi

# --- Define Contribution Colors (for Pango markup) ---
declare -A CONTRIB_COLORS
CONTRIB_COLORS[0]="#1f2335"
CONTRIB_COLORS[1]="#033a16"
CONTRIB_COLORS[2]="#196c2e"
CONTRIB_COLORS[3]="#2ea043"
CONTRIB_COLORS[4]="#56d364"

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
echo "GraphQL Payload: ${JSON_PAYLOAD}" >> "${LOG_FILE}"

RESPONSE=$(curl -s -L \
    -H "Authorization: bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -X POST \
    -d "${JSON_PAYLOAD}" \
    "https://api.github.com/graphql")

echo "--- Full API Response ---" >> "${LOG_FILE}"
echo "${RESPONSE}" >> "${LOG_FILE}"
echo "-------------------------" >> "${LOG_FILE}"

# --- Response Handling & Initial Parsing ---
if [[ -z "$RESPONSE" ]]; then
    echo "Error: curl returned an empty response." >> "${LOG_FILE}"
    echo '{"text": " Curl Err", "tooltip": "GraphQL Curl returned empty."}'
    exit 1
fi

if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    ERROR_MESSAGE=$(echo "$RESPONSE" | jq -r '.errors[0].message // "Unknown GraphQL error"')
    echo "GraphQL Error: ${ERROR_MESSAGE}" >> "${LOG_FILE}"
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

echo "--- Extracted Contribution Data (ALL_DAYS_DATA) ---" >> "${LOG_FILE}"
echo "${ALL_DAYS_DATA}" >> "${LOG_FILE}"
echo "----------------------------------------------------" >> "${LOG_FILE}"

ACTIVITY_BOXES_STRING_FOR_JSON=""

if [[ -z "$ALL_DAYS_DATA" ]]; then
    echo "No contribution data extracted from response. Generating empty graph." >> "${LOG_FILE}"
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
    for i in {6..0}; do
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