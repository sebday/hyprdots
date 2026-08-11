#!/bin/bash

source "${HOME}/.local/bin/evo-bar-common.sh"

if cached=$(evo_bar_cache_read "github" 300 2>/dev/null); then
    printf '%s\n' "$cached"
    exit 0
fi

# GitHub username
USERNAME="sebday"

# Secrets: ~/.local/share/evo-shell/secrets.env (chmod 600), e.g. GITHUB_TOKEN=ghp_...
SECRETS_FILE="$EVO_SECRETS_FILE"
if [[ -f "$SECRETS_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$SECRETS_FILE"
fi

TOKEN="${GITHUB_TOKEN:-}"

json_github() {
    jq -cn \
        --arg text "$1" \
        --argjson today "$2" \
        --argjson cells "$3" \
        --arg class "$4" \
        '{text: $text, today: $today, cells: $cells, class: $class}'
}

json_error() {
    local text="$1"
    local tooltip="${2:-}"
    jq -cn --arg text "$text" --arg tooltip "$tooltip" '{text: $text, tooltip: $tooltip, class: "error"}'
}

contribution_level() {
    local count="${1:-0}"
    if [[ "$count" -ge 30 ]]; then echo 4; return
    elif [[ "$count" -ge 18 ]]; then echo 3; return
    elif [[ "$count" -ge 10 ]]; then echo 2; return
    elif [[ "$count" -ge 1 ]]; then echo 1; return
    fi
    echo 0
}

build_heatmap_json() {
    local -a counts=("$@")
    local level color count line
    local lines=""

    for count in "${counts[@]}"; do
        level=$(contribution_level "$count")
        color="${GITHUB_COLORS[$level]}"
        line=$(jq -cn --argjson level "$level" --argjson count "$count" --arg color "$color" \
            '{level: $level, count: $count, color: $color}')
        lines+="$line"$'\n'
    done

    printf '%s' "$lines" | jq -s '.'
}

# --- Token Validation ---
if [[ -z "$TOKEN" ]]; then
    json_error " Token Err" "Set GITHUB_TOKEN in ~/.local/share/evo-shell/secrets.env (chmod 600)"
    exit 1
fi

evo_bar_load_heatmap_colors

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
    json_error " Curl Err" "GraphQL Curl returned empty."
    exit 1
fi

if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    ERROR_MESSAGE=$(echo "$RESPONSE" | jq -r '.errors[0].message // "Unknown GraphQL error"')
    json_error " GQL Err" "GraphQL Error: ${ERROR_MESSAGE}"
    exit 1
fi

declare -A contribs_by_date
ALL_DAYS_DATA=$(echo "$RESPONSE" | jq -r '
    .data.user.contributionsCollection.contributionCalendar.weeks[]?.contributionDays[]? |
    select(.date != null and .contributionCount != null) |
    "\(.date)_\(.contributionCount)"
')

LOCAL_TODAY_ISO=$(date +'%Y-%m-%d')
declare -a day_counts=()
declare -a heatmap_chars=()

if [[ -z "$ALL_DAYS_DATA" ]]; then
    TODAY_CONTRIBUTION_COUNT=0
    for i in {1..14}; do
        day_counts+=(0)
        heatmap_chars+=("<span foreground='${GITHUB_COLORS[0]}'>■</span>")
    done
else
    while IFS=_ read -r date_val count_val; do
        contribs_by_date["$date_val"]=$count_val
    done <<< "$ALL_DAYS_DATA"

    for i in {13..0}; do
        DAY_ISO=$(date -d "${LOCAL_TODAY_ISO} - ${i} days" +'%Y-%m-%d')
        COUNT_FOR_DAY=${contribs_by_date["$DAY_ISO"]:-0}
        LEVEL=$(contribution_level "$COUNT_FOR_DAY")
        day_counts+=("$COUNT_FOR_DAY")
        heatmap_chars+=("<span foreground='${GITHUB_COLORS[$LEVEL]}'>■</span>")
    done

    TODAY_CONTRIBUTION_COUNT=${contribs_by_date["$LOCAL_TODAY_ISO"]:-0}
fi

TODAY_LEVEL=$(contribution_level "$TODAY_CONTRIBUTION_COUNT")
HEATMAP_JSON=$(build_heatmap_json "${day_counts[@]}")
ACTIVITY_BOXES_STRING_FOR_JSON=$(printf '%s' "${heatmap_chars[@]}")

TEXT_OUTPUT="  ${TODAY_CONTRIBUTION_COUNT} ${ACTIVITY_BOXES_STRING_FOR_JSON}"
CLASS="github-level-${TODAY_LEVEL}"

output=$(json_github "$TEXT_OUTPUT" "$TODAY_CONTRIBUTION_COUNT" "$HEATMAP_JSON" "$CLASS")
printf '%s\n' "$output" | evo_bar_cache_write "github"
printf '%s\n' "$output"
