# evo-player-lib.sh — shared paths and helpers for evo-player
[[ -n "${EVO_PLAYER_LIB_LOADED:-}" ]] && return 0
EVO_PLAYER_LIB_LOADED=1

PATH="${HOME}/.local/bin:${PATH}"

EVOSHELL_BIN="${EVOSHELL_BIN:-$HOME/.local/bin}"
EVOSHELL_CONFIG="${EVOSHELL_CONFIG:-$HOME/.config/evoshell}"
EVOSHELL_STATE="${EVOSHELL_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/evoshell}"

MUSIC_CONFIG="${EVOSHELL_CONFIG}/music.toml"
MUSIC_ROOT="${EVO_MUSIC_ROOT:-/mnt/external/music}"
MUSIC_CACHE="${EVO_MUSIC_CACHE:-${MUSIC_ROOT}/.cache}"
MUSIC_STATE="${EVO_MUSIC_STATE:-${MUSIC_CACHE}}"
SYNC_ARCHIVE="${MUSIC_STATE}/sync-archive.txt"
PLAYLIST_DIR="${MUSIC_STATE}/playlists"
WAVEFORM_DIR="${MUSIC_STATE}/waveforms"
ART_DIR="${MUSIC_STATE}/art"
TRACKS_CACHE_DIR="${MUSIC_STATE}/tracks"
PLAYER_STATE="${MUSIC_STATE}/player.json"
LIKES_FILE="${MUSIC_STATE}/likes.json"
PLAYLIST_STARS="${MUSIC_STATE}/playlist-stars.json"
JOB_LOCK="${MUSIC_STATE}/.job.lock"
JOB_STATE="${MUSIC_STATE}/job.json"
LEGACY_STATE="${EVOSHELL_STATE}/music"
PLAYER_SOCKET_DEFAULT="${XDG_RUNTIME_DIR:-/tmp}/evo-player.sock"
LEGACY_MPV_SOCKET="${XDG_RUNTIME_DIR:-/tmp}/evo-music.sock"
if [[ -n "${EVO_PLAYER_SOCKET:-}" ]]; then
  MPV_SOCKET="$EVO_PLAYER_SOCKET"
elif [[ -n "${EVO_MUSIC_SOCKET:-}" ]]; then
  MPV_SOCKET="$EVO_MUSIC_SOCKET"
elif [[ -S "$LEGACY_MPV_SOCKET" ]] && [[ ! -S "$PLAYER_SOCKET_DEFAULT" ]]; then
  MPV_SOCKET="$LEGACY_MPV_SOCKET"
else
  MPV_SOCKET="$PLAYER_SOCKET_DEFAULT"
fi
AUDIO_EXTS="mp3 flac ogg m4a opus wav"

ensure_dirs() {
  mkdir -p "$MUSIC_STATE" "${MUSIC_ROOT}/incoming"
  migrate_cache
  mkdir -p "$PLAYLIST_DIR" "$WAVEFORM_DIR" "$ART_DIR" "$TRACKS_CACHE_DIR"
}

run_exclusive_job() {
  local command="$1"
  local label="$2"
  shift 2
  ensure_dirs
  local running run_label
  running="$(library_job_running "$$")"
  if [[ -n "$running" ]]; then
    case "${running##* }" in
      rebuild) run_label="rebuild library" ;;
      build) run_label="build library" ;;
      warm) run_label="warm cache" ;;
      soundcloud) run_label="sync soundcloud" ;;
      import) run_label="import incoming" ;;
      *) run_label="${running##* }" ;;
    esac
    echo "evo-player: busy — ${run_label} already running" >&2
    return 2
  fi
  (
    exec 200>"$JOB_LOCK"
    if ! flock -n 200; then
      local who
      who="$(jq -r '.label // .command // "library task"' "$JOB_STATE" 2>/dev/null || echo "library task")"
      echo "evo-player: busy — ${who} already running" >&2
      exit 2
    fi
    jq -n \
      --arg command "$command" \
      --arg label "$label" \
      --argjson pid "$$" \
      --arg started "$(date -Iseconds)" \
      '{command:$command,label:$label,pid:$pid,started:$started}' >"$JOB_STATE"
    set +e
    "$@"
    local rc=$?
    set -e
    rm -f "$JOB_STATE"
    exit "$rc"
  )
}

library_job_running() {
  local exclude="${1:-}"
  ps -eo pid=,ppid=,args= | awk -v exclude="$exclude" '
    /\/evo-player (rebuild|build|warm|soundcloud|import)$/ {
      pid=$1
      gsub(/^[[:space:]]+/, "", pid)
      ppid=$2
      gsub(/^[[:space:]]+/, "", ppid)
      cmd=$NF
      sub(/.*\//, "", cmd)
      rows[pid]=ppid "|" cmd
      order[++n]=pid
    }
    END {
      for (i=1; i<=n; i++) {
        pid=order[i]
        if (pid == exclude) continue
        split(rows[pid], parts, "|")
        ppid=parts[1]
        if (ppid in rows) continue
        print pid, parts[2]
        exit
      }
    }
  '
}

cmd_job_status() {
  local json="${1:-}"
  if [[ -f "$JOB_STATE" ]]; then
    if [[ "$json" == --json ]]; then
      jq -c '. + {busy:true}' "$JOB_STATE"
    else
      jq -r '.label // .command // "library task"' "$JOB_STATE"
    fi
    return 0
  fi
  local running pid cmd label
  running="$(library_job_running)"
  if [[ -n "$running" ]]; then
    pid="${running%% *}"
    cmd="${running##* }"
    case "$cmd" in
      rebuild) label="rebuild library" ;;
      build) label="build library" ;;
      warm) label="warm cache" ;;
      soundcloud) label="sync soundcloud" ;;
      import) label="import incoming" ;;
      *) label="$cmd" ;;
    esac
    if [[ "$json" == --json ]]; then
      jq -n \
        --arg command "$cmd" \
        --arg label "$label" \
        --argjson pid "$pid" \
        --arg started "" \
        '{busy:true,command:$command,label:$label,pid:$pid,started:$started,external:true}'
    else
      printf '%s\n' "$label"
    fi
    return 0
  fi
  if [[ "$json" == --json ]]; then
    jq -n '{busy:false}'
  else
    printf 'idle\n'
  fi
}

likes_init() {
  [[ -f "$LIKES_FILE" ]] || printf '{}\n' >"$LIKES_FILE"
}

is_liked() {
  local path="$1"
  [[ -n "$path" ]] || return 1
  likes_init
  jq -e --arg p "$path" 'has($p)' "$LIKES_FILE" >/dev/null 2>&1
}

migrate_cache() {
  local old="$LEGACY_STATE"
  [[ -d "$old" ]] || return 0
  local name
  for name in sync-archive.txt player.json; do
    [[ -f "$MUSIC_STATE/$name" ]] || [[ ! -f "$old/$name" ]] || cp "$old/$name" "$MUSIC_STATE/$name"
  done
  if [[ -d "$old/playlists" ]] && [[ -z "$(find "$MUSIC_STATE/playlists" -maxdepth 1 -name '*.m3u' -print -quit 2>/dev/null)" ]]; then
    mkdir -p "$MUSIC_STATE/playlists"
    cp -an "$old/playlists/." "$MUSIC_STATE/playlists/" 2>/dev/null || true
  fi
  if [[ -d "$old/waveforms" ]]; then
    mkdir -p "$MUSIC_STATE/waveforms"
    cp -an "$old/waveforms/." "$MUSIC_STATE/waveforms/" 2>/dev/null || true
  fi
  if [[ -d "$old/art" ]]; then
    mkdir -p "$MUSIC_STATE/art"
    cp -an "$old/art/." "$MUSIC_STATE/art/" 2>/dev/null || true
  fi
  [[ -f "$MUSIC_STATE/library.db" ]] || [[ ! -f "$old/library.db" ]] || cp "$old/library.db" "$MUSIC_STATE/library.db"
  likes_migrate_from_m3u
}

likes_migrate_from_m3u() {
  local m3u="${PLAYLIST_DIR}/favorites.m3u"
  [[ -f "$m3u" ]] || return 0
  likes_init
  [[ "$(jq 'length' "$LIKES_FILE" 2>/dev/null || echo 0)" -gt 0 ]] && return 0
  local path title artist now
  now="$(date -Iseconds)"
  while IFS= read -r path; do
    [[ -f "$path" ]] || continue
    is_liked "$path" && continue
    title="$(ffprobe_meta "$path" title)"
    artist="$(ffprobe_meta "$path" artist)"
    [[ -z "$title" ]] && title="$(basename "${path%.*}")"
    jq --arg p "$path" --arg title "$title" --arg artist "$artist" --arg at "$now" \
      '.[$p] = {title:$title, artist:$artist, liked_at:$at}' \
      "$LIKES_FILE" >"${LIKES_FILE}.tmp" && mv "${LIKES_FILE}.tmp" "$LIKES_FILE"
  done < <(grep -v '^#' "$m3u" 2>/dev/null || true)
}

config_val() {
  local key="$1"
  local default="${2:-}"
  if [[ -f "$MUSIC_CONFIG" ]]; then
    local val
    val="$(grep -E "^${key}[[:space:]]*=" "$MUSIC_CONFIG" 2>/dev/null | head -1 | sed -E 's/^[^=]+=[[:space:]]*"?([^"]*)"?/\1/')" || true
    if [[ -n "$val" ]]; then
      printf '%s' "$val"
      return 0
    fi
  fi
  printf '%s' "$default"
}

is_audio() {
  local path="$1"
  [[ -f "$path" ]] || return 1
  local ext="${path##*.}"
  ext="${ext,,}"
  local allowed
  for allowed in $AUDIO_EXTS; do
    if [[ "$ext" == "$allowed" ]]; then
      return 0
    fi
  done
  return 1
}

file_hash() {
  local path="$1"
  sha256sum "$path" | awk '{print $1}'
}

cache_key() {
  local path="$1"
  local rel="${path#${MUSIC_ROOT}/}"
  [[ "$rel" == "$path" ]] && rel="$(basename "$path")"
  track_cache_slug "$rel"
}

cache_asset_find() {
  local path="$1"
  local ext="$2"
  local dir="$3"
  local key legacy hash candidate
  [[ -f "$path" ]] || return 1
  key="$(cache_key "$path")"
  candidate="${dir}/${key}.${ext}"
  [[ -f "$candidate" ]] && {
    printf '%s' "$candidate"
    return 0
  }
  legacy="$(track_cache_slug "${path#${MUSIC_ROOT}/}")"
  candidate="${dir}/${legacy}.${ext}"
  [[ -f "$candidate" ]] && {
    printf '%s' "$candidate"
    return 0
  }
  hash="$(file_hash "$path")"
  candidate="${dir}/${hash}.${ext}"
  [[ -f "$candidate" ]] && {
    printf '%s' "$candidate"
    return 0
  }
  return 1
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/}"
  printf '%s' "$s"
}

skip_dir() {
  local name="$1"
  case "$name" in
    incoming) return 0 ;;
  esac
  return 1
}

list_genres() {
  local dir name
  for dir in "$MUSIC_ROOT"/*; do
    [[ -d "$dir" ]] || continue
    name="$(basename "$dir")"
    skip_dir "$name" && continue
    printf '%s\n' "$name"
  done | sort
}

genre_track_count() {
  local genre="$1"
  local dir="$MUSIC_ROOT/$genre"
  local count=0
  local f
  [[ -d "$dir" ]] || { printf '0'; return; }
  while IFS= read -r -d '' f; do
    is_audio "$f" && count=$((count + 1))
  done < <(find "$dir" -type f -print0 2>/dev/null)
  printf '%d' "$count"
}

genre_track_count_cached() {
  local genre="$1"
  local cache count count_file
  cache="$(tracks_cache_path "$genre")"
  count_file="${cache%.tags.json}.count"
  if [[ -f "$count_file" ]]; then
    count="$(<"$count_file")"
    if [[ "$count" =~ ^[0-9]+$ ]]; then
      printf '%d' "$count"
      return
    fi
  fi
  if [[ -f "$cache" && -s "$cache" ]]; then
    count="$(jq 'length' "$cache" 2>/dev/null || echo "")"
    if [[ "$count" =~ ^[0-9]+$ && "$count" -gt 0 ]]; then
      printf '%s\n' "$count" >"$count_file"
      printf '%d' "$count"
      return
    fi
    rm -f "$cache" "$count_file"
  fi
  genre_track_count "$genre"
}

ffprobe_meta() {
  local path="$1"
  local field="$2"
  ffprobe -v quiet -show_entries "format_tags=$field" -of default=nw=1:nk=1 "$path" 2>/dev/null | head -1 || true
}

ffprobe_year() {
  local path="$1"
  local raw=""
  for field in date YEAR year originaldate ORIGINALDATE TYER; do
    raw="$(ffprobe_meta "$path" "$field")"
    [[ -n "$raw" ]] && break
  done
  if [[ "$raw" =~ ([0-9]{4}) ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  fi
}

track_tags_read() {
  local path="$1"
  python3 - "$path" <<'PY'
import json, os, subprocess, sys
path = sys.argv[1]
title = artist = genre = album = year = ""
try:
    proc = subprocess.run(
        ["ffprobe", "-v", "quiet", "-print_format", "json", "-show_format", path],
        capture_output=True, text=True, check=False,
    )
    if proc.returncode == 0 and proc.stdout.strip():
        tags = json.loads(proc.stdout).get("format", {}).get("tags", {}) or {}

        def pick(*keys):
            lookup = {k.lower(): str(v).strip() for k, v in tags.items() if v}
            for key in keys:
                val = lookup.get(key.lower())
                if val:
                    return val
            return ""

        title = pick("title")
        artist = pick("artist", "album_artist", "albumartist")
        genre = pick("genre")
        album = pick("album")
        year = pick("date", "year", "originaldate", "original_year", "tyer")
        import re
        m = re.search(r"(\d{4})", year or "")
        year = m.group(1) if m else ""
except Exception:
    pass
if not title:
    title = os.path.splitext(os.path.basename(path))[0]
print(json.dumps({"title": title, "artist": artist, "genre": genre, "album": album, "year": year}, ensure_ascii=False))
PY
}

track_meta_json() {
  local path="$1"
  local tags title artist genre album
  tags="$(track_tags_read "$path")"
  title="$(jq -r '.title // ""' <<<"$tags")"
  artist="$(jq -r '.artist // ""' <<<"$tags")"
  genre="$(jq -r '.genre // ""' <<<"$tags")"
  album="$(jq -r '.album // ""' <<<"$tags")"
  printf '{"path":"%s","title":"%s","artist":"%s","genre":"%s","album":"%s"}' \
    "$(json_escape "$path")" \
    "$(json_escape "$title")" \
    "$(json_escape "$artist")" \
    "$(json_escape "$genre")" \
    "$(json_escape "$album")"
}

track_list_json() {
  local path="$1"
  local tags title artist genre album art="" liked_json=false
  tags="$(track_tags_read "$path")"
  title="$(jq -r '.title // ""' <<<"$tags")"
  artist="$(jq -r '.artist // ""' <<<"$tags")"
  genre="$(jq -r '.genre // ""' <<<"$tags")"
  album="$(jq -r '.album // ""' <<<"$tags")"
  art="$(art_path_cached "$path")"
  is_liked "$path" && liked_json=true
  printf '{"path":"%s","title":"%s","artist":"%s","genre":"%s","album":"%s","art":"%s","liked":%s}' \
    "$(json_escape "$path")" \
    "$(json_escape "$title")" \
    "$(json_escape "$artist")" \
    "$(json_escape "$genre")" \
    "$(json_escape "$album")" \
    "$(json_escape "$art")" \
    "$liked_json"
}

genre_from_path() {
  local path="$1"
  local rel="${path#${MUSIC_ROOT}/}"
  [[ "$rel" == "$path" ]] && return 0
  printf '%s' "${rel%%/*}"
}

track_cache_slug() {
  printf '%s' "$1" | sed 's/[^a-zA-Z0-9&_-]/_/g'
}

tracks_cache_path() {
  printf '%s/%s.tags.json' "$TRACKS_CACHE_DIR" "$(track_cache_slug "$1")"
}

tracks_cache_stale() {
  local genre="$1"
  local cache="$2"
  local dir="$MUSIC_ROOT/$genre"
  [[ ! -f "$cache" ]] && return 0
  [[ ! -s "$cache" ]] && return 0
  jq -e 'type == "array"' "$cache" >/dev/null 2>&1 || return 0
  [[ ! -d "$dir" ]] && return 0
  [[ -n "$(find "$dir" -type f -newer "$cache" -print -quit 2>/dev/null)" ]] && return 0
  return 1
}

tracks_cache_invalidate() {
  rm -f "${TRACKS_CACHE_DIR}/"*.tags.json 2>/dev/null || true
}

tracks_cache_invalidate_genre() {
  local genre="$1"
  [[ -n "$genre" ]] || return 0
  rm -f "$(tracks_cache_path "$genre")" "${TRACKS_CACHE_DIR}/$(track_cache_slug "$genre").count" 2>/dev/null || true
}

build_tracks_json_impl() {
  local genre="$1"
  local force="${2:-0}"
  local dir="$MUSIC_ROOT/$genre"
  local cache tmpdir
  cache="$(tracks_cache_path "$genre")"
  mkdir -p "$TRACKS_CACHE_DIR"

  if [[ "$force" -eq 1 ]] || [[ ! -f "$cache" ]] || [[ ! -s "$cache" ]]; then
    tmpdir="$(mktemp -d "${TRACKS_CACHE_DIR}/.build.XXXXXX")"
    local -a files=()
    local f
    while IFS= read -r -d '' f; do
      is_audio "$f" || continue
      files+=("$f")
    done < <(find "$dir" -type f -print0 2>/dev/null | sort -z)

    local i=0 n=${#files[@]} batch=32
    for f in "${files[@]}"; do
      track_list_json "$f" >"${tmpdir}/${i}.json" &
      i=$((i + 1))
      if (( i % batch == 0 )); then
        wait
      fi
    done
    wait

    {
      printf '['
      local first=1 j=0
      for ((j = 0; j < n; j++)); do
        [[ -f "${tmpdir}/${j}.json" ]] || continue
        [[ "$first" -eq 1 ]] || printf ','
        first=0
        cat "${tmpdir}/${j}.json"
      done
      printf ']\n'
    } >"${cache}.tmp" && mv "${cache}.tmp" "$cache"
    rm -rf "$tmpdir"
  else
    tmpdir="$(mktemp -d "${TRACKS_CACHE_DIR}/.build.XXXXXX")"
    local -a update_files=()
    local f
    while IFS= read -r -d '' f; do
      is_audio "$f" || continue
      if ! jq -e --arg p "$f" 'map(select(.path == $p)) | length > 0' "$cache" >/dev/null 2>&1; then
        update_files+=("$f")
      elif [[ "$f" -nt "$cache" ]]; then
        update_files+=("$f")
      fi
    done < <(find "$dir" -type f -print0 2>/dev/null)

    jq --arg dir "$dir/" '[.[] | select(.path | startswith($dir))]' "$cache" >"${tmpdir}/base.json"

    local i=0 n=${#update_files[@]} batch=32
    for f in "${update_files[@]}"; do
      track_list_json "$f" >"${tmpdir}/${i}.json" &
      i=$((i + 1))
      if (( i % batch == 0 )); then
        wait
      fi
    done
    wait

    python3 - "${tmpdir}/base.json" "${tmpdir}" "$n" "$cache" <<'PY'
import json, os, sys

base_path, workdir, update_count, out_path = sys.argv[1:5]
update_count = int(update_count)
with open(base_path, encoding="utf-8") as fh:
    base = json.load(fh)
by_path = {
    item.get("path"): item
    for item in base
    if item.get("path") and os.path.isfile(item.get("path"))
}
for i in range(update_count):
    path = os.path.join(workdir, f"{i}.json")
    try:
        with open(path, encoding="utf-8") as fh:
            item = json.load(fh)
    except (OSError, json.JSONDecodeError):
        continue
    p = item.get("path")
    if p:
        by_path[p] = item
merged = sorted(by_path.values(), key=lambda item: item.get("path", ""))
with open(out_path, "w", encoding="utf-8") as fh:
    json.dump(merged, fh, ensure_ascii=False)
PY
    rm -rf "$tmpdir"
  fi

  local count
  count="$(jq 'length' "$cache" 2>/dev/null || echo 0)"
  [[ "$count" =~ ^[0-9]+$ ]] || count=0
  printf '%s\n' "$count" >"${cache%.tags.json}.count"
  cat "$cache"
}

build_tracks_json() {
  local genre="$1"
  local force="${2:-0}"
  local cache lock
  cache="$(tracks_cache_path "$genre")"
  lock="${TRACKS_CACHE_DIR}/.$(track_cache_slug "$genre").lock"
  mkdir -p "$TRACKS_CACHE_DIR"

  if [[ "$force" -ne 1 ]] && [[ -f "$cache" ]] && ! tracks_cache_stale "$genre" "$cache"; then
    cat "$cache"
    return 0
  fi

  (
    flock -w 120 200 || {
      echo "evo-player: cache build already running for ${genre}" >&2
      exit 1
    }
    if [[ "$force" -ne 1 ]] && [[ -f "$cache" ]] && ! tracks_cache_stale "$genre" "$cache"; then
      cat "$cache"
      exit 0
    fi
    build_tracks_json_impl "$genre" "$force"
  ) 200>"$lock"
}

cache_paths_for() {
  local path="$1"
  local wf art
  wf="$(waveform_cache_find "$path" 2>/dev/null || waveform_cache_canonical "$path")"
  art="$(cache_asset_find "$path" "jpg" "$ART_DIR" 2>/dev/null || art_path_canonical "$path")"
  printf '%s\n' "$(cache_key "$path")" "$wf" "$art"
}

waveform_cache_canonical() {
  local path="$1"
  printf '%s/%s.json' "$WAVEFORM_DIR" "$(cache_key "$path")"
}

waveform_cache_find() {
  local path="$1"
  cache_asset_find "$path" "json" "$WAVEFORM_DIR"
}

waveform_cache_path() {
  local path="$1"
  local found
  found="$(waveform_cache_find "$path" 2>/dev/null || true)"
  if [[ -n "$found" ]]; then
    printf '%s' "$found"
    return 0
  fi
  waveform_cache_canonical "$path"
}

waveform_build_impl() {
  local path="$1"
  local wf="$2"
  [[ -f "$path" ]] || return 1
  [[ -f "$wf" ]] && return 0
  mkdir -p "$WAVEFORM_DIR"
  python3 - "$path" "$wf" <<'PY'
import json, struct, subprocess, sys

path, out = sys.argv[1], sys.argv[2]
dur = 0.0
try:
    proc = subprocess.run(
        ["ffprobe", "-v", "quiet", "-show_entries", "format=duration",
         "-of", "default=nw=1:nk=1", path],
        capture_output=True, text=True, check=False,
    )
    dur = float((proc.stdout or "0").strip() or 0)
except Exception:
    dur = 0.0

target = int(max(180, min(2400, dur * 12 if dur > 0 else 900)))
audio = subprocess.run(
    ["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", path,
     "-ac", "1", "-ar", "11025", "-f", "s16le", "-"],
    capture_output=True, check=False,
)
if audio.returncode != 0 or len(audio.stdout) < 4:
    sys.exit(1)

raw = audio.stdout[: len(audio.stdout) // 2 * 2]
samples = struct.unpack("<" + "h" * (len(raw) // 2), raw)
count = len(samples)
group = max(1, count // target)
data = []
for i in range(0, count, group):
    chunk = samples[i : i + group]
    if not chunk:
        continue
    peak = max(abs(s) for s in chunk)
    data.append(min(255, int(peak / 32768 * 255)))

if not data:
    sys.exit(1)

payload = {
    "version": 2,
    "channels": 1,
    "sample_rate": 11025,
    "samples_per_pixel": group,
    "bits": 8,
    "length": len(data),
    "data": data,
}
with open(out, "w", encoding="utf-8") as fh:
    json.dump(payload, fh)
PY
  [[ -f "$wf" ]]
}

waveform_build() {
  local path="$1"
  local wf lock
  [[ -f "$path" ]] || return 1
  wf="$(waveform_cache_find "$path" 2>/dev/null || true)"
  [[ -n "$wf" && -f "$wf" ]] && return 0
  wf="$(waveform_cache_canonical "$path")"
  mkdir -p "$WAVEFORM_DIR"
  lock="${WAVEFORM_DIR}/.$(cache_key "$path").wf.lock"
  (
    if command -v flock >/dev/null 2>&1; then
      flock -x 9 || exit 1
    fi
    waveform_build_impl "$path" "$wf"
  ) 9>"$lock"
}

waveform_ensure_async() {
  local path="$1"
  [[ -f "$path" ]] || return 0
  [[ -n "$(waveform_cache_find "$path" 2>/dev/null || true)" ]] && return 0
  (waveform_build "$path" >/dev/null 2>&1 &)
  disown
}

art_ensure_async() {
  local path="$1"
  local art
  [[ -f "$path" ]] || return 0
  art="$(art_path_resolve "$path")"
  [[ -n "$art" && -f "$art" ]] && return 0
  (art_path_for "$path" >/dev/null 2>&1 &)
  disown
}

browse_warm_art_async() {
  local lines="$1"
  [[ -n "$lines" ]] || return 0
  (
    while IFS= read -r track_line; do
      [[ -n "$track_line" ]] || continue
      local path art
      path="$(jq -r '.path // ""' <<<"$track_line")"
      art="$(jq -r '.art // ""' <<<"$track_line")"
      [[ -n "$path" && -f "$path" ]] || continue
      [[ -n "$art" && -f "$art" ]] && continue
      art_ensure_async "$path"
    done <<<"$lines"
  ) >/dev/null 2>&1 &
  disown
}

art_path_canonical() {
  local path="$1"
  printf '%s/%s.jpg' "$ART_DIR" "$(cache_key "$path")"
}

art_path_for() {
  local path="$1"
  local art
  [[ -f "$path" ]] || return 0
  art="$(art_path_cached "$path")"
  if [[ -z "$art" ]]; then
    art="$(art_path_canonical "$path")"
    ffmpeg -y -loglevel error -i "$path" -an -vcodec copy "$art" 2>/dev/null || true
  fi
  [[ -f "$art" ]] && printf '%s' "$art"
}

art_path_resolve() {
  local path="$1"
  local art
  [[ -f "$path" ]] || return 0
  art="$(art_path_cached "$path")"
  if [[ -n "$art" ]]; then
    printf '%s' "$art"
    return 0
  fi
  art_path_canonical "$path"
}

art_path_cached() {
  local path="$1"
  local art
  [[ -f "$path" ]] || return 0
  art="$(cache_asset_find "$path" "jpg" "$ART_DIR" 2>/dev/null || true)"
  if [[ -n "$art" ]]; then
    printf '%s' "$art"
  fi
  return 0
}

