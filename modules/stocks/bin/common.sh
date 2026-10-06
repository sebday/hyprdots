#!/usr/bin/env bash
# Shared helpers for evo.stocks bar scripts.

_evo_paths_lib="${EVOSHELL_LIB:-$HOME/.local/lib/evoshell/bin}/evo-paths-lib"
[[ -r "$_evo_paths_lib" ]] || _evo_paths_lib="${EVOSHELL_BIN:-}/evo-paths-lib"
# shellcheck source=/dev/null
[[ -r "$_evo_paths_lib" ]] && source "$_evo_paths_lib"
EVOSHELL_CACHE="${EVOSHELL_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/evoshell}"

EVO_BAR_CACHE_DIR="${EVO_BAR_CACHE_DIR:-${EVOSHELL_CACHE}/stocks/bar}"
BAR_HISTORY_DIR="${BAR_HISTORY_DIR:-${EVOSHELL_CACHE}/stocks/history}"
EVO_BAR_THEME_CSS="${EVO_BAR_THEME_CSS:-$HOME/.themes/current/evo-bar.css}"

declare -gA GITHUB_COLORS=()

evo_bar_history_path() {
  mkdir -p "$BAR_HISTORY_DIR"
  printf '%s/%s-history.json' "$BAR_HISTORY_DIR" "$1"
}

evo_secrets_get() {
  local key="$1"
  local rel="$2"
  local value prefix
  local -a prefixes=()
  command -v pass >/dev/null 2>&1 || return 1
  # Credentials on this machine live under omarchy/. Keep evoshell/ first so a
  # migrated store still wins.
  prefixes+=("${EVOSHELL_PASS_PREFIX:-evoshell}")
  [[ "${prefixes[0]}" == "omarchy" ]] || prefixes+=(omarchy)
  for prefix in "${prefixes[@]}"; do
    [[ -n "$prefix" ]] || continue
    value="$(pass show "${prefix}/${rel}" 2>/dev/null || true)"
    if [[ -n "$value" ]]; then
      printf '%s' "$value"
      return 0
    fi
  done
  return 1
}

evo_bar_load_secrets() {
  local key value
  declare -A _secret_paths=(
    [KRAKEN_API_KEY]="kraken/api-key"
    [KRAKEN_SECRET]="kraken/api-secret"
    [T212_API_KEY]="trading212/api-key"
    [T212_API_SECRET]="trading212/api-secret"
  )
  for key in "$@"; do
    [[ -n "${_secret_paths[$key]:-}" ]] || continue
    value="$(evo_secrets_get "$key" "${_secret_paths[$key]}")" || continue
    printf -v "$key" '%s' "$value"
  done
}

evo_bar_load_heatmap_colors() {
  declare -gA GITHUB_COLORS=()
  local i color
  if [[ -f "$EVO_BAR_THEME_CSS" ]]; then
    for i in {0..4}; do
      color=$(grep "@define-color github-$i" "$EVO_BAR_THEME_CSS" | awk '{print $3}' | tr -d ';' || true)
      [[ -n "$color" ]] && GITHUB_COLORS[$i]="$color"
    done
  fi
  : "${GITHUB_COLORS[0]:=#45475a}"
  : "${GITHUB_COLORS[1]:=#89b4fa}"
  : "${GITHUB_COLORS[2]:=#74c7ec}"
  : "${GITHUB_COLORS[3]:=#89dceb}"
  : "${GITHUB_COLORS[4]:=#cba6f7}"
}

evo_bar_cache_path() {
  printf '%s/%s.json' "$EVO_BAR_CACHE_DIR" "$1"
}

evo_private_dir() {
  local dir="$1"
  mkdir -p -m 700 "$dir" || return 1
  [[ ! -L "$dir" ]] || return 1
  [[ -d "$dir" ]] || return 1
  [[ "$(stat -c %u "$dir")" == "$(id -u)" ]] || return 1
  find "$dir" -mindepth 1 -maxdepth 1 ! -type f -exec rm -rf -- {} + 2>/dev/null || true
  find "$dir" -mindepth 1 -maxdepth 1 -type f -exec chmod 600 -- {} + 2>/dev/null || true
}

evo_read_bounded() {
  local file="$1" max="${2:-65536}" data
  [[ -e "$file" ]] || return 1
  data=$(/usr/bin/dd if="$file" iflag=nofollow,nonblock,count_bytes,fullblock bs=1 count=$((max + 1)) status=none) || return 1
  [ ${#data} -le "$max" ] || return 1
  printf '%s' "$data"
}

evo_bar_cache_read() {
  local key="$1" ttl="${2:-60}"
  local path now mtime age content
  path="$(evo_bar_cache_path "$key")"
  [[ -e "$path" ]] || return 1
  now=$(date +%s)
  mtime=$(stat -c %Y "$path" 2>/dev/null || echo 0)
  age=$((now - mtime))
  (( age < ttl )) || return 1
  content="$(evo_read_bounded "$path")" || return 1
  [[ -n "${content//[[:space:]]/}" ]] || return 1
  printf '%s' "$content"
}

evo_bar_cache_write() {
  local key="$1" path tmp
  evo_private_dir "$EVO_BAR_CACHE_DIR" || return 1
  path="$(evo_bar_cache_path "$key")"
  umask 077
  tmp="$(/usr/bin/mktemp -p "$EVO_BAR_CACHE_DIR" .cache.XXXXXXXXXX)" || return 1
  cat >"$tmp" || { rm -f -- "$tmp"; return 1; }
  mv -f -T -- "$tmp" "$path"
}

kraken_secret_hex() {
  local secret_b64="$1"
  if command -v xxd >/dev/null 2>&1; then
    printf '%s' "$secret_b64" | base64 -d | xxd -p -c 256
    return
  fi
  printf '%s' "$secret_b64" | base64 -d | od -An -tx1 | tr -d ' \n'
}

kraken_api_errors() {
  local resp="$1"
  jq -r '.error // [] | .[]' <<<"$resp" 2>/dev/null || true
}

evo_bar_build_candles_json() {
  local -a rows=("$@")
  local row day_iso open high low close lines

  if ((${#rows[@]} == 0)); then
    printf '[]'
    return
  fi

  lines=""
  for row in "${rows[@]}"; do
    IFS='|' read -ra parts <<< "$row"
    day_iso="${parts[0]}"
    if ((${#parts[@]} >= 5)); then
      open="${parts[1]}"
      high="${parts[2]}"
      low="${parts[3]}"
      close="${parts[4]}"
    elif ((${#parts[@]} >= 2)); then
      close="${parts[1]}"
      open="$close"
      high="$close"
      low="$close"
    else
      continue
    fi
    lines+="$(jq -cn \
      --arg date "$day_iso" \
      --argjson open "${open:-0}" \
      --argjson high "${high:-0}" \
      --argjson low "${low:-0}" \
      --argjson close "${close:-0}" \
      '{date: $date, open: $open, high: $high, low: $low, close: $close, value: $close}')"
    lines+=$'\n'
  done

  if [[ -z "$lines" ]]; then
    printf '[]'
    return
  fi
  printf '%s' "$lines" | jq -s '.'
}

evo_bar_period_stats_json() {
  local -a rows=("$@")
  if ((${#rows[@]} == 0)); then
    printf '{}'
    return
  fi

  awk -F'|' -v n="${#rows[@]}" '
    BEGIN {
      first = ""
      last = ""
      minV = ""
      maxV = ""
    }
    {
      d = $1
      if (NF >= 5) v = ($5 == "" ? 0 : $5 + 0)
      else v = ($2 == "" ? 0 : $2 + 0)
      if (first == "") first = v
      last = v
      if (minV == "" || v < minV) minV = v
      if (maxV == "" || v > maxV) maxV = v
    }
    END {
      change = 0
      if (first + 0 != 0)
        change = (last - first) / first * 100
      printf "{\"days\":%d,\"high\":%.8f,\"low\":%.8f,\"changePct\":%.4f,\"start\":%.8f,\"end\":%.8f}\n",
        n, maxV + 0, minV + 0, change, first + 0, last + 0
    }
  ' <<<"$(printf '%s\n' "${rows[@]}")"
}

evo_bar_merge_history() {
  local path="$1"
  local keep="${2:-30}"
  local stdin_data existing merged tmp line d
  mkdir -p "$(dirname "$path")"
  stdin_data="$(cat)"

  if [[ -f "$path" ]]; then
    existing=$(jq -c 'if type == "array" then map(select(type == "object" and (.date // "") != "")) else [] end' "$path" 2>/dev/null || echo '[]')
  else
    existing='[]'
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line//$'\r'/}"
    [[ "$line" == *"|"* ]] || continue
    d="${line%%|*}"
    d="${d//[[:space:]]/}"
    [[ -n "$d" ]] || continue
    IFS='|' read -ra parts <<< "$line"
    if ((${#parts[@]} >= 5)); then
      existing=$(jq -c --arg d "$d" \
        --argjson open "${parts[1]}" \
        --argjson high "${parts[2]}" \
        --argjson low "${parts[3]}" \
        --argjson close "${parts[4]}" '
        (map(select(.date != $d)) + [{
          date: $d,
          value: $close,
          open: $open,
          high: $high,
          low: $low,
          close: $close
        }])
      ' <<<"$existing" 2>/dev/null || echo "$existing")
    fi
  done <<<"$stdin_data"

  merged=$(jq -c --argjson keep "$keep" 'sort_by(.date) | .[-$keep:]' <<<"$existing")
  tmp="$(mktemp)"
  printf '%s\n' "$merged" | jq '.' >"$tmp"
  mv "$tmp" "$path"
  jq -r '
    .[]
    | if (.open != null and .high != null and .low != null and .close != null) then
        "\(.date)|\(.open)|\(.high)|\(.low)|\(.close)"
      else
        "\(.date)|\(.value)"
      end
  ' <<<"$merged"
}
