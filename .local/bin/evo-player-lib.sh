# evo-player-lib.sh — shared paths and helpers for evo-player
[[ -n "${EVO_PLAYER_LIB_LOADED:-}" ]] && return 0
EVO_PLAYER_LIB_LOADED=1

export PYTHONDONTWRITEBYTECODE=1

PATH="${HOME}/.local/bin:${PATH}"

EVOSHELL_BIN="${EVOSHELL_BIN:-$HOME/.local/bin}"
EVOSHELL_CONFIG="${EVOSHELL_CONFIG:-$HOME/.config/quickshell/evoshell}"
EVOSHELL_STATE="${EVOSHELL_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/evoshell}"
EVO_PLAYER_STATE="${EVO_PLAYER_STATE:-${EVOSHELL_STATE}/panel/player}"
EVO_PLAYER_CACHE="${EVO_PLAYER_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/evoshell/panel/player}"

MUSIC_ROOT_DEFAULT="/mnt/external/music"
MUSIC_ROOT=""
MUSIC_CACHE=""
MUSIC_STATE=""
MUSIC_CONFIG=""
LEGACY_MUSIC_CONFIG="${EVOSHELL_CONFIG}/music.toml"
SYNC_ARCHIVE=""
PLAYLIST_DIR=""
WAVEFORM_DIR=""
ART_DIR=""
ART_DIRTY=""
TRACKS_CACHE_DIR=""
PLAYER_STATE=""
CURRENT_M3U=""
CURRENT_TRACKS_JSON=""
LIKES_FILE=""
PLAYLIST_STARS=""
JOB_LOCK=""
JOB_STATE=""
SCROBBLE_LOG=""
LEGACY_STATE="${EVOSHELL_STATE}/music"
PLAYER_SOCKET_DEFAULT="${XDG_RUNTIME_DIR:-/tmp}/evo-player.sock"
LEGACY_MPV_SOCKET="${XDG_RUNTIME_DIR:-/tmp}/evo-music.sock"
if [[ -n "${EVO_PLAYER_SOCKET:-}" ]]; then
  MPV_SOCKET="$EVO_PLAYER_SOCKET"
elif [[ -n "${EVO_PLAYER_MUSIC_SOCKET:-}" ]]; then
  MPV_SOCKET="$EVO_PLAYER_MUSIC_SOCKET"
elif [[ -S "$LEGACY_MPV_SOCKET" ]] && [[ ! -S "$PLAYER_SOCKET_DEFAULT" ]]; then
  MPV_SOCKET="$LEGACY_MPV_SOCKET"
else
  MPV_SOCKET="$PLAYER_SOCKET_DEFAULT"
fi
EVO_PLAYER_MPV_CLIENT_NAME="${EVO_PLAYER_MPV_CLIENT_NAME:-evo.panel.player}"
AUDIO_EXTS="mp3 flac ogg m4a opus wav"

music_config_read_root() {
  local cfg root
  for cfg in "$@"; do
    [[ -f "$cfg" ]] || continue
    root="$(python3 - "$cfg" <<'PY'
import sys
try:
    import tomllib
except ImportError:
    import tomli as tomllib
path = sys.argv[1]
with open(path, "rb") as fh:
    data = tomllib.load(fh)
root = data.get("paths", {}).get("root")
if root:
    print(root, end="")
PY
)"
    if [[ -n "$root" ]]; then
      printf '%s' "$root"
      return 0
    fi
  done
  return 1
}

music_paths_apply() {
  local root="${1:-}"
  if [[ -z "$root" ]]; then
    if [[ -n "${EVO_PLAYER_MUSIC_ROOT:-}" ]]; then
      root="$EVO_PLAYER_MUSIC_ROOT"
    else
      root="$(music_config_read_root "${MUSIC_ROOT_DEFAULT}/.cache/music.toml" "$LEGACY_MUSIC_CONFIG" || true)"
      [[ -z "$root" ]] && root="$MUSIC_ROOT_DEFAULT"
    fi
  fi
  root="${root%/}"
  MUSIC_ROOT="$root"
  MUSIC_CACHE="${EVO_PLAYER_MUSIC_CACHE:-$EVO_PLAYER_CACHE}"
  MUSIC_STATE="${EVO_PLAYER_MUSIC_STATE:-$EVO_PLAYER_STATE}"
  MUSIC_CONFIG="${EVO_PLAYER_MUSIC_CONFIG:-${MUSIC_STATE}/music.toml}"
  SYNC_ARCHIVE="${MUSIC_STATE}/sync-archive.txt"
  PLAYLIST_DIR="${MUSIC_STATE}/playlists"
  WAVEFORM_DIR="${MUSIC_CACHE}/waveforms"
  ART_DIR="${MUSIC_CACHE}/art"
  ART_DIRTY="${MUSIC_CACHE}/art-dirty.json"
  TRACKS_CACHE_DIR="${MUSIC_CACHE}/tracks"
  PLAYER_STATE="${MUSIC_STATE}/player.json"
  CURRENT_M3U="${PLAYLIST_DIR}/current.m3u"
  CURRENT_TRACKS_JSON="${PLAYLIST_DIR}/current.tracks.json"
  LIKES_FILE="${MUSIC_STATE}/likes.json"
  PLAYLIST_STARS="${MUSIC_STATE}/playlist-stars.json"
  JOB_LOCK="${MUSIC_STATE}/.job.lock"
  JOB_STATE="${MUSIC_STATE}/job.json"
  SCROBBLE_LOG="${MUSIC_STATE}/scrobble.jsonl"
  PLACEMENT_LOG="${MUSIC_STATE}/placement.jsonl"
}

music_paths_apply ""

ensure_dirs() {
  if [[ -d "${MUSIC_ROOT}/incoming" && ! -e "${MUSIC_ROOT}/.incoming" ]]; then
    mv "${MUSIC_ROOT}/incoming" "${MUSIC_ROOT}/.incoming"
  fi
  mkdir -p "$MUSIC_STATE" "$MUSIC_CACHE" "${MUSIC_ROOT}/.incoming"
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
      build) run_label="build" ;;
      soundcloud) run_label="soundcloud" ;;
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
    function job_cmd() {
      if ($4 !~ /\/evo-player$/)
        return ""
      if ($5 == "art" && ($6 == "maintain" || $6 == "embed"))
        return $6
      if ($5 == "build" || $5 == "sort" || $5 == "soundcloud")
        return $5
      return ""
    }
    {
      pid=$1
      gsub(/^[[:space:]]+/, "", pid)
      ppid=$2
      gsub(/^[[:space:]]+/, "", ppid)
      cmd=job_cmd()
      if (cmd == "")
        next
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

kill_job_tree() {
  local pid="$1"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null || return 0
  pkill -TERM -P "$pid" 2>/dev/null || true
  kill -TERM "$pid" 2>/dev/null || true
  sleep 0.15
  pkill -KILL -P "$pid" 2>/dev/null || true
  kill -KILL "$pid" 2>/dev/null || true
}

cmd_job_stop() {
  local json="${1:-}" stopped=0 label="" pid running
  ensure_dirs
  if [[ -f "$JOB_STATE" ]]; then
    label="$(jq -r '.label // .command // "library task"' "$JOB_STATE" 2>/dev/null || echo "library task")"
    pid="$(jq -r '.pid // empty' "$JOB_STATE" 2>/dev/null || echo "")"
    [[ -n "$pid" ]] && kill_job_tree "$pid" && stopped=1
    rm -f "$JOB_STATE"
  fi
  while true; do
    running="$(library_job_running)"
    [[ -n "$running" ]] || break
    pid="${running%% *}"
    [[ -z "$label" ]] && label="${running##* }"
    kill_job_tree "$pid"
    stopped=1
    sleep 0.05
  done
  if [[ "$json" == --json ]]; then
    jq -n \
      --argjson stopped "$stopped" \
      --arg label "${label:-library task}" \
      '{stopped:($stopped == 1),label:$label}'
    [[ "$stopped" -eq 1 ]]
    return
  fi
  if [[ "$stopped" -eq 1 ]]; then
    printf 'stopped %s\n' "${label:-library task}"
    return 0
  fi
  echo "evo-player: no library job running" >&2
  return 1
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
      build) label="build" ;;
      soundcloud) label="soundcloud" ;;
      sort) label="sort" ;;
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

migrate_intermediate_player_paths() {
  local src
  for src in \
    "${EVOSHELL_STATE}/evopanel/evoplayer" \
    "${EVOSHELL_STATE}/evopanel/evo-player"; do
    [[ -d "$src" ]] || continue
    mkdir -p "$MUSIC_STATE"
    cp -an "$src/." "$MUSIC_STATE/" 2>/dev/null || true
  done

  for src in \
    "${XDG_CACHE_HOME:-$HOME/.cache}/evoshell/evopanel/evoplayer" \
    "${XDG_CACHE_HOME:-$HOME/.cache}/evoshell/evopanel/evo-player"; do
    [[ -d "$src" ]] || continue
    mkdir -p "$MUSIC_CACHE"
    cp -an "$src/." "$MUSIC_CACHE/" 2>/dev/null || true
  done
}

migrate_cache() {
  migrate_intermediate_player_paths
  local old="$LEGACY_STATE"
  local legacy_music_cache="${MUSIC_ROOT}/.cache"
  [[ -f "$MUSIC_CONFIG" ]] || [[ ! -f "$LEGACY_MUSIC_CONFIG" ]] || cp "$LEGACY_MUSIC_CONFIG" "$MUSIC_CONFIG"
  [[ -f "$MUSIC_CONFIG" ]] || [[ ! -f "${legacy_music_cache}/music.toml" ]] || cp "${legacy_music_cache}/music.toml" "$MUSIC_CONFIG"
  [[ -d "$old" ]] || old=""
  local name
  for name in sync-archive.txt player.json likes.json playlist-stars.json scrobble.jsonl placement.jsonl job.json; do
    if [[ -f "$MUSIC_STATE/$name" ]]; then
      continue
    fi
    if [[ -n "$old" && -f "$old/$name" ]]; then
      cp "$old/$name" "$MUSIC_STATE/$name"
      continue
    fi
    if [[ -f "${legacy_music_cache}/$name" ]]; then
      cp "${legacy_music_cache}/$name" "$MUSIC_STATE/$name"
    fi
  done
  if [[ -z "$(find "$MUSIC_STATE/playlists" -maxdepth 1 -name '*.m3u' -print -quit 2>/dev/null)" ]]; then
    mkdir -p "$MUSIC_STATE/playlists"
    if [[ -n "$old" && -d "$old/playlists" ]]; then
      cp -an "$old/playlists/." "$MUSIC_STATE/playlists/" 2>/dev/null || true
    fi
    if [[ -d "${legacy_music_cache}/playlists" ]]; then
      cp -an "${legacy_music_cache}/playlists/." "$MUSIC_STATE/playlists/" 2>/dev/null || true
    fi
  fi
  if [[ -z "$(find "$WAVEFORM_DIR" -maxdepth 1 -type f -print -quit 2>/dev/null)" ]]; then
    mkdir -p "$WAVEFORM_DIR"
    if [[ -n "$old" && -d "$old/waveforms" ]]; then
      cp -an "$old/waveforms/." "$WAVEFORM_DIR/" 2>/dev/null || true
    fi
    if [[ -d "${legacy_music_cache}/waveforms" ]]; then
      cp -an "${legacy_music_cache}/waveforms/." "$WAVEFORM_DIR/" 2>/dev/null || true
    fi
  fi
  if [[ -z "$(find "$ART_DIR" -maxdepth 1 -type f -print -quit 2>/dev/null)" ]]; then
    mkdir -p "$ART_DIR"
    if [[ -n "$old" && -d "$old/art" ]]; then
      cp -an "$old/art/." "$ART_DIR/" 2>/dev/null || true
    fi
    if [[ -d "${legacy_music_cache}/art" ]]; then
      cp -an "${legacy_music_cache}/art/." "$ART_DIR/" 2>/dev/null || true
    fi
  fi
  if [[ -z "$(find "$TRACKS_CACHE_DIR" -maxdepth 1 -name '*.tags.json' -print -quit 2>/dev/null)" ]]; then
    mkdir -p "$TRACKS_CACHE_DIR"
    if [[ -n "$old" && -d "$old/tracks" ]]; then
      cp -an "$old/tracks/." "$TRACKS_CACHE_DIR/" 2>/dev/null || true
    fi
    if [[ -d "${legacy_music_cache}/tracks" ]]; then
      cp -an "${legacy_music_cache}/tracks/." "$TRACKS_CACHE_DIR/" 2>/dev/null || true
    fi
  fi
  [[ -f "$ART_DIRTY" ]] || [[ ! -f "${legacy_music_cache}/art-dirty.json" ]] || cp "${legacy_music_cache}/art-dirty.json" "$ART_DIRTY"
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

config_toml_get() {
  local section="$1" key="$2" default="${3:-}"
  python3 - "$MUSIC_CONFIG" "$section" "$key" "$default" <<'PY'
import sys
try:
    import tomllib
except ImportError:
    import tomli as tomllib

path, section, key, default = sys.argv[1:5]
try:
    with open(path, "rb") as fh:
        data = tomllib.load(fh)
    val = data.get(section, {}).get(key)
    if val is None:
        print(default, end="")
    elif isinstance(val, bool):
        print("true" if val else "false", end="")
    else:
        print(val, end="")
except FileNotFoundError:
    print(default, end="")
PY
}

config_toml_set() {
  local section="$1" key="$2" value="$3"
  ensure_dirs
  python3 - "$MUSIC_CONFIG" "$section" "$key" "$value" <<'PY'
import os, sys
try:
    import tomllib
except ImportError:
    import tomli as tomllib

path, section, key, value = sys.argv[1:5]

def load(path):
    if not os.path.isfile(path):
        return {}
    with open(path, "rb") as fh:
        return tomllib.load(fh)

def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')

def write(path, data):
    lines = []
    for sec, vals in data.items():
        lines.append(f"[{sec}]")
        for k, v in vals.items():
            if isinstance(v, str):
                lines.append(f'{k} = "{esc(v)}"')
            elif isinstance(v, bool):
                lines.append(f'{k} = {"true" if v else "false"}')
            elif isinstance(v, list):
                items = ", ".join(f'"{esc(str(x))}"' for x in v)
                lines.append(f"{k} = [{items}]")
            else:
                lines.append(f"{k} = {v}")
        lines.append("")
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines).rstrip() + "\n")

data = load(path)
data.setdefault(section, {})[key] = value
sc = data.get("soundcloud")
if isinstance(sc, dict):
    sc.pop("likes_url", None)
write(path, data)
PY
}

soundcloud_likes_url() {
  local user
  user="$(config_toml_get soundcloud user seb-day)"
  printf 'https://soundcloud.com/%s/likes' "$user"
}

config_toml_json() {
  config_toml_prune_derived
  python3 - "$MUSIC_CONFIG" "$MUSIC_ROOT" <<'PY'
import json, os, sys
try:
    import tomllib
except ImportError:
    import tomli as tomllib

path, music_root = sys.argv[1:3]
try:
    with open(path, "rb") as fh:
        data = tomllib.load(fh)
except FileNotFoundError:
    data = {}
sc = data.get("soundcloud", {})
user = sc.get("user") or "seb-day"
paths = data.get("paths", {})
root = paths.get("root") or music_root or "/mnt/external/music"
print(json.dumps({
    "soundcloud": {
        "user": user,
        "cookies_from": sc.get("cookies_from") or "brave",
    },
    "paths": {
        "root": root,
    },
}, ensure_ascii=False))
PY
}

config_toml_prune_derived() {
  python3 - "$MUSIC_CONFIG" <<'PY'
import os, sys
try:
    import tomllib
except ImportError:
    import tomli as tomllib

path = sys.argv[1]
if not os.path.isfile(path):
    sys.exit(0)

def load(path):
    with open(path, "rb") as fh:
        return tomllib.load(fh)

def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')

def write(path, data):
    lines = []
    for sec, vals in data.items():
        lines.append(f"[{sec}]")
        for k, v in vals.items():
            if isinstance(v, str):
                lines.append(f'{k} = "{esc(v)}"')
            elif isinstance(v, bool):
                lines.append(f'{k} = {"true" if v else "false"}')
            elif isinstance(v, list):
                items = ", ".join(f'"{esc(str(x))}"' for x in v)
                lines.append(f"{k} = [{items}]")
            else:
                lines.append(f"{k} = {v}")
        lines.append("")
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines).rstrip() + "\n")

data = load(path)
sc = data.get("soundcloud")
if not isinstance(sc, dict) or "likes_url" not in sc:
    sys.exit(0)
del sc["likes_url"]
write(path, data)
PY
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

incoming_normalize_mp3() {
  local incoming="${MUSIC_ROOT}/.incoming"
  [[ -d "$incoming" ]] || return 0
  local f base mp3 ext
  for f in "$incoming"/*; do
    [[ -f "$f" ]] || continue
    base="${f%.*}"
    ext="${f##*.}"
    ext="${ext,,}"
    case "$ext" in
      mp3) continue ;;
      part|ytdl|temp|jpg|jpeg|png|webp|gif)
        mp3="${base}.mp3"
        [[ -f "$mp3" ]] && rm -f "$f"
        continue ;;
    esac
    is_audio "$f" || continue
    mp3="${base}.mp3"
    if [[ -f "$mp3" ]]; then
      rm -f "$f"
      continue
    fi
    if ffmpeg -y -hide_banner -loglevel error -i "$f" -codec:a libmp3lame -q:a 0 "$mp3"; then
      rm -f "$f"
      echo "evo-player: converted to mp3: $(basename "$mp3")" >&2
    else
      echo "evo-player: warn: mp3 convert failed: $f" >&2
    fi
  done
}

PLACE_MIX_SECONDS=1200

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
  local key legacy candidate rel
  [[ -f "$path" ]] || return 1
  key="$(cache_key "$path")"
  candidate="${dir}/${key}.${ext}"
  [[ -f "$candidate" ]] && {
    printf '%s' "$candidate"
    return 0
  }
  rel="${path#${MUSIC_ROOT}/}"
  [[ "$rel" == "$path" ]] && rel="$(basename "$path")"
  legacy="$(track_cache_slug_legacy "$rel")"
  candidate="${dir}/${legacy}.${ext}"
  [[ -f "$candidate" ]] && {
    printf '%s' "$candidate"
    return 0
  }
  legacy="$(track_cache_slug "$rel")"
  candidate="${dir}/${legacy}.${ext}"
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

skip_dirs_list() {
  if [[ -f "$MUSIC_CONFIG" ]]; then
    python3 - "$MUSIC_CONFIG" <<'PY'
import re, sys
text = open(sys.argv[1]).read()
match = re.search(r'^\s*skip\s*=\s*\[(.*?)\]', text, re.M | re.S)
if match:
    for item in re.findall(r'"([^"]+)"', match.group(1)):
        print(item)
PY
  fi
}

skip_dir() {
  local name="$1"
  local skip
  while IFS= read -r skip; do
    [[ -n "$skip" && "$name" == "$skip" ]] && return 0
  done < <(skip_dirs_list)
  case "$name" in
    .incoming|incoming) return 0 ;;
  esac
  return 1
}

genre_tag_to_folder() {
  local tag="$1"
  local lower
  lower="$(printf '%s' "$tag" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [[ -z "$lower" ]] && return 1
  case "$lower" in
    *drum*|*dnb*|*jungle*) printf 'drum&bass'; return 0 ;;
    *dub*) printf 'dubstep'; return 0 ;;
    *house*) printf 'house'; return 0 ;;
    *grime*) printf 'grime'; return 0 ;;
    *hip*hop*|*hiphop*) printf 'hiphop'; return 0 ;;
    liquid) printf 'drum&bass'; return 0 ;;
  esac
  return 1
}

mixes_override_genre() {
  local path="$1"
  local stem="${path##*/}"
  stem="${stem%.*}"
  case "$stem" in
    ant_tc1_mc_visionobi*) printf 'drum&bass'; return 0 ;;
    calibre-essential_mix_*) printf 'drum&bass'; return 0 ;;
    chase_status_boiler_room_london*) printf 'drum&bass'; return 0 ;;
    dj_d-send_fizzy_comp_mix*) printf 'drum&bass'; return 0 ;;
    future_beats_radio_show_04-06-15*) printf 'drum&bass'; return 0 ;;
    hospital_records_with_lens*) printf 'drum&bass'; return 0 ;;
    huscher-subtle_radio*) printf 'drum&bass'; return 0 ;;
    jdizz_vol_1*) printf 'drum&bass'; return 0 ;;
    jook*) printf 'drum&bass'; return 0 ;;
    cream_live_mixed_by_paul_oakenfold*) printf 'house'; return 0 ;;
    bufera_beats_w_limmz*) printf 'grime'; return 0 ;;
    excision-darkside_dubstep_2006*) printf 'dubstep'; return 0 ;;
  esac
  return 1
}

mixes_resolve_genre() {
  local path="$1"
  local tag genre=""
  if genre="$(mixes_override_genre "$path")"; then
    printf '%s' "$genre"
    return 0
  fi
  tag="$(ffprobe_meta "$path" genre)"
  if genre="$(genre_tag_to_folder "$tag")"; then
    printf '%s' "$genre"
    return 0
  fi
  return 1
}

likes_add() {
  local path="$1"
  [[ -f "$path" ]] || return 1
  likes_init
  is_liked "$path" && return 0
  local title artist now
  title="$(ffprobe_meta "$path" title)"
  artist="$(ffprobe_meta "$path" artist)"
  [[ -z "$title" ]] && title="$(basename "${path%.*}")"
  now="$(date -Iseconds)"
  jq --arg p "$path" --arg title "$title" --arg artist "$artist" --arg at "$now" \
    '.[$p] = {title:$title, artist:$artist, liked_at:$at}' \
    "$LIKES_FILE" >"${LIKES_FILE}.tmp" && mv "${LIKES_FILE}.tmp" "$LIKES_FILE"
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

ffprobe_duration() {
  local path="$1"
  ffprobe -v quiet -show_entries format=duration -of default=nw=1:nk=1 "$path" 2>/dev/null \
    | head -1 \
    | awk '{d=$1+0; if (d>0) printf "%d", int(d); else print 0}'
}

year_is_valid() {
  local y="$1"
  [[ "$y" =~ ^[0-9]{4}$ ]] || return 1
  (( y >= 1985 && y <= 2026 ))
}

path_year_resolve() {
  local path="$1"
  local root="${MUSIC_ROOT:-/mnt/external/music}"
  local rel stem part next i yy y mo d
  root="${root%/}"
  if [[ "$path" == "$root"/* ]]; then
    rel="${path#"$root"/}"
  else
    rel="$(basename "$path")"
  fi
  stem="${rel##*/}"
  stem="${stem%.*}"

  if [[ "$stem" =~ (^|[-_])([0-9]{4})([0-9]{2})([0-9]{2})$ ]]; then
    y="${BASH_REMATCH[2]}"; mo="${BASH_REMATCH[3]}"; d="${BASH_REMATCH[4]}"
    if year_is_valid "$y" && (( 10#$mo >= 1 && 10#$mo <= 12 && 10#$d >= 1 && 10#$d <= 31 )); then
      printf '%s' "$y"
      return 0
    fi
  fi
  if [[ "$stem" =~ ([0-9]{2})[.-]([0-9]{2})[.-](20[0-9]{2}) ]]; then
    d="${BASH_REMATCH[1]}"; mo="${BASH_REMATCH[2]}"; y="${BASH_REMATCH[3]}"
    if year_is_valid "$y" && (( 10#$mo >= 1 && 10#$mo <= 12 && 10#$d >= 1 && 10#$d <= 31 )); then
      printf '%s' "$y"
      return 0
    fi
  fi
  if [[ "$stem" =~ ([0-9]{2})\.([0-9]{2})\.([0-9]{2})$ ]]; then
    d="${BASH_REMATCH[1]}"; mo="${BASH_REMATCH[2]}"; yy="${BASH_REMATCH[3]}"
    if (( 10#$mo >= 1 && 10#$mo <= 12 && 10#$d >= 0 && 10#$d <= 31 )); then
      if (( 10#$yy < 70 )); then y=$((2000 + 10#$yy)); else y=$((1900 + 10#$yy)); fi
      if year_is_valid "$y"; then
        printf '%s' "$y"
        return 0
      fi
    fi
  fi
  if [[ "$stem" =~ (^|[-_])([0-9]{2})[.-]([0-9]{2})[.-]([0-9]{2})([^0-9]|$) ]]; then
    yy="${BASH_REMATCH[2]}"; mo="${BASH_REMATCH[3]}"; d="${BASH_REMATCH[4]}"
    if (( 10#$mo >= 1 && 10#$mo <= 12 && 10#$d >= 0 && 10#$d <= 31 )); then
      if (( 10#$yy < 70 )); then y=$((2000 + 10#$yy)); else y=$((1900 + 10#$yy)); fi
      if year_is_valid "$y"; then
        printf '%s' "$y"
        return 0
      fi
    fi
  fi
  if [[ "$stem" =~ ([0-9]{2})([0-9]{2})([0-9]{4})$ ]]; then
    d="${BASH_REMATCH[1]}"; mo="${BASH_REMATCH[2]}"; y="${BASH_REMATCH[3]}"
    if year_is_valid "$y" && (( 10#$mo >= 1 && 10#$mo <= 12 && 10#$d >= 1 && 10#$d <= 31 )); then
      printf '%s' "$y"
      return 0
    fi
  fi

  local IFS='/'
  local -a parts
  read -ra parts <<<"$rel"
  for i in "${!parts[@]}"; do
    part="${parts[$i]}"
    if [[ "$part" == "mixes" ]]; then
      next="${parts[$((i + 1))]:-}"
      if year_is_valid "$next"; then
        printf '%s' "$next"
        return 0
      fi
    fi
  done
  for part in "${parts[@]}"; do
    if [[ "$part" =~ ^(19[0-9]{2}|20[0-9]{2})_ ]]; then
      y="${BASH_REMATCH[1]}"
      if year_is_valid "$y"; then
        printf '%s' "$y"
        return 0
      fi
    fi
    if [[ "$part" =~ (^|[-_])(19[0-9]{2}|20[0-9]{2})([^0-9]|$) ]]; then
      y="${BASH_REMATCH[2]}"
      if year_is_valid "$y"; then
        printf '%s' "$y"
        return 0
      fi
    fi
  done
  return 1
}

resolve_year() {
  local path="$1"
  local year tags
  year="$(path_year_resolve "$path")"
  if year_is_valid "$year"; then
    printf '%s' "$year"
    return 0
  fi
  tags="$(track_tags_read "$path")"
  year="$(jq -r '.year // ""' <<<"$tags")"
  if year_is_valid "$year"; then
    printf '%s' "$year"
    return 0
  fi
  year="$(ffprobe_year "$path")"
  if year_is_valid "$year"; then
    printf '%s' "$year"
    return 0
  fi
  printf 'unknown'
}

resolve_genre_from_tags() {
  local path="$1"
  local tag genre="" path_genre
  tag="$(jq -r '.genre // ""' <<<"$(track_tags_read "$path")")"
  if mixes_override_genre "$path" >/dev/null; then
    genre="$(mixes_override_genre "$path")"
    printf '%s' "$genre"
    return 0
  fi
  if genre="$(genre_tag_to_folder "$tag")"; then
    printf '%s' "$genre"
    return 0
  fi
  path_genre="$(genre_from_path "$path")"
  if [[ -n "$path_genre" ]] && ! skip_dir "$path_genre"; then
    printf '%s' "$path_genre"
    return 0
  fi
  return 1
}

standardize_track_tags() {
  local path="$1"
  local script="${EVOSHELL_BIN:-$HOME/.local/bin}/evo-player-standardize-tags.py"
  [[ -f "$script" ]] || return 0
  MUSIC_ROOT="$MUSIC_ROOT" EVOSHELL_BIN="${EVOSHELL_BIN:-$HOME/.local/bin}" python3 -B "$script" "$path"
}

track_is_mix() {
  local path="$1"
  local dur stem lower
  dur="$(ffprobe_duration "$path")"
  dur="${dur%%.*}"
  [[ "$dur" =~ ^[0-9]+$ ]] || dur=0
  if (( dur > PLACE_MIX_SECONDS )); then
    return 0
  fi
  if (( dur > 0 )); then
    return 1
  fi
  stem="$(basename "${path%.*}")"
  lower="$(printf '%s' "$stem" | tr '[:upper:]' '[:lower:]')"
  case "$lower" in
    *mixed*|*essential*|*euphoria*|*session*|*boiler*|*radio_show*|*radio-show*|*-mix|*_mix|*live_mixed*)
      return 0
      ;;
  esac
  return 1
}

sort_folder_collect_audio() {
  local dir="$1"
  find "$dir" -maxdepth 1 -type f -print0 2>/dev/null
}

paths_equal() {
  local a="$1" b="$2"
  [[ -n "$a" && -n "$b" ]] || return 1
  a="$(realpath -m "$a" 2>/dev/null || printf '%s' "$a")"
  b="$(realpath -m "$b" 2>/dev/null || printf '%s' "$b")"
  [[ "$a" == "$b" ]]
}

canonical_track_dest() {
  local path="$1"
  local genre year dest_dir basename
  genre="$(resolve_genre_from_tags "$path")" || return 1
  basename="$(track_filename_from_tags "$path")" || return 1
  if track_is_mix "$path"; then
    year="$(resolve_year "$path")"
    dest_dir="${MUSIC_ROOT}/${genre}/mixes/${year}"
  else
    dest_dir="${MUSIC_ROOT}/${genre}/soundcloud"
  fi
  printf '%s/%s' "$dest_dir" "$basename"
}

placement_log_append() {
  local op="$1" from="$2" to="$3"
  ensure_dirs
  local id at
  at="$(date -Iseconds)"
  id="${at}-$$-${RANDOM}"
  jq -nc \
    --arg id "$id" \
    --arg at "$at" \
    --arg op "$op" \
    --arg from "$from" \
    --arg to "$to" \
    '{id:$id,at:$at,op:$op,from:$from,to:$to}' >>"$PLACEMENT_LOG"
}

place_track() {
  local src="$1"
  local dest src_genre dest_genre op="${PLACE_TRACK_OP:-place}"
  [[ -f "$src" ]] || return 1
  is_audio "$src" || return 1
  dest="$(canonical_track_dest "$src")" || return 1
  if paths_equal "$src" "$dest"; then
    printf '%s' "$dest"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  if [[ -e "$dest" ]]; then
    echo "evo-player: skip existing dest: $dest" >&2
    return 1
  fi
  src_genre="$(genre_from_path "$src")"
  mv "$src" "$dest"
  dest_genre="$(genre_from_path "$dest")"
  [[ -n "$src_genre" ]] && tracks_cache_invalidate_genre "$src_genre"
  [[ -n "$dest_genre" ]] && tracks_cache_invalidate_genre "$dest_genre"
  placement_log_append "$op" "$src" "$dest"
  printf '%s' "$dest"
}

track_tags_read() {
  local path="$1"
  python3 - "$path" <<'PY'
import json, os, subprocess, sys
path = sys.argv[1]
title = artist = genre = album = album_artist = year = label = ""
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
        album_artist = pick("album_artist", "albumartist")
        label = pick("label", "publisher", "organization", "tpub")
        year = pick("date", "year", "originaldate", "original_year", "tyer")
        import re
        m = re.search(r"(\d{4})", year or "")
        year = m.group(1) if m else ""
except Exception:
    pass
if not title:
    title = os.path.splitext(os.path.basename(path))[0]
print(json.dumps({"title": title, "artist": artist, "genre": genre, "album": album, "album_artist": album_artist, "year": year, "label": label}, ensure_ascii=False))
PY
}

tag_set_metadata() {
  local path="$1" field="$2" value="$3"
  local meta_key tmp genre ext
  [[ -f "$path" ]] || return 1
  case "$field" in
    title|artist|album|genre) meta_key="$field" ;;
    year) meta_key="date" ;;
    *) return 1 ;;
  esac
  ext="${path##*.}"
  if [[ "$ext" == "$path" || -z "$ext" ]]; then
    ext="mp3"
  fi
  tmp="$(mktemp "${TMPDIR:-/tmp}/evo-music-tag.XXXXXX.${ext}")"
  if ffmpeg -y -hide_banner -loglevel error -i "$path" -metadata "${meta_key}=${value}" -codec copy "$tmp" 2>/dev/null; then
    mv "$tmp" "$path"
  else
    rm -f "$tmp"
    return 1
  fi
  genre="$(genre_from_path "$path")"
  [[ -n "$genre" ]] && tracks_cache_invalidate_genre "$genre"
  return 0
}

track_sanitize_filename_part() {
  local s="$1"
  python3 -c 'import re,sys
s = sys.argv[1]
s = re.sub(r"[/\\\\:*?\"<>|]+", " ", s)
s = re.sub(r"\s+", " ", s).strip()
print(s)' "$s"
}

track_slugify() {
  python3 -c 'import re, sys, unicodedata

def slug(value: str) -> str:
    value = unicodedata.normalize("NFKD", value or "")
    value = "".join(c for c in value if not unicodedata.combining(c))
    value = value.lower()
    value = re.sub(r"[^a-z0-9]+", "_", value)
    value = re.sub(r"_+", "_", value).strip("_")
    return value

print(slug(sys.argv[1]))' "$1"
}

track_filename_from_tags() {
  local path="$1"
  local tags title artist ext artist_slug title_slug base
  [[ -f "$path" ]] || return 1
  tags="$(track_tags_read "$path")"
  title="$(jq -r '.title // ""' <<<"$tags")"
  artist="$(jq -r '.artist // ""' <<<"$tags")"
  ext="${path##*.}"
  ext="${ext,,}"
  [[ -n "$ext" && "$ext" != "$path" ]] || ext="mp3"
  artist_slug="$(track_slugify "$artist")"
  title_slug="$(track_slugify "$title")"
  if [[ -n "$artist_slug" && -n "$title_slug" ]]; then
    if [[ "$title_slug" == "${artist_slug}" ]]; then
      title_slug=""
    elif [[ "$title_slug" == "${artist_slug}"_* ]]; then
      title_slug="${title_slug#${artist_slug}_}"
    fi
  fi
  if [[ -n "$artist_slug" && -n "$title_slug" ]]; then
    base="${artist_slug}-${title_slug}"
  elif [[ -n "$title_slug" ]]; then
    base="$title_slug"
  elif [[ -n "$artist_slug" ]]; then
    base="$artist_slug"
  else
    base="$(track_slugify "$(basename "${path%.*}")")"
  fi
  [[ -n "$base" ]] || return 1
  printf '%s.%s' "$base" "$ext"
}

track_filename_from_meta() {
  local artist="$1" title="$2" ext="$3"
  title="$(track_sanitize_filename_part "$title")"
  artist="$(track_sanitize_filename_part "$artist")"
  [[ -n "$title" ]] || return 1
  if [[ -n "$artist" ]]; then
    printf '%s - %s.%s' "$artist" "$title" "$ext"
  else
    printf '%s.%s' "$title" "$ext"
  fi
}

likes_relocate_path() {
  local old="$1" new="$2"
  likes_init
  jq -e --arg old "$old" 'has($old)' "$LIKES_FILE" >/dev/null 2>&1 || return 0
  local title artist
  title="$(ffprobe_meta "$new" title)"
  artist="$(ffprobe_meta "$new" artist)"
  [[ -z "$title" ]] && title="$(basename "${new%.*}")"
  jq --arg old "$old" --arg new "$new" --arg title "$title" --arg artist "$artist" \
    'if has($old) then .[$new] = (.[$old] + {title:$title, artist:$artist}) | del(.[$old]) else . end' \
    "$LIKES_FILE" >"${LIKES_FILE}.tmp" && mv "${LIKES_FILE}.tmp" "$LIKES_FILE"
}

art_relocate_legacy() {
  local old="$1" new="$2"
  local old_art new_art
  old_art="$(art_path_legacy "$old")"
  [[ -f "$old_art" ]] || return 0
  new_art="$(art_path_legacy "$new")"
  [[ -f "$new_art" ]] && return 0
  mkdir -p "$(dirname "$new_art")"
  mv "$old_art" "$new_art"
}

waveform_relocate_cache() {
  local old="$1" new="$2"
  local old_wf new_wf
  old_wf="$(waveform_cache_find "$old" 2>/dev/null || true)"
  [[ -n "$old_wf" && -f "$old_wf" ]] || return 0
  new_wf="$(waveform_cache_canonical "$new")"
  [[ -f "$new_wf" ]] || mv "$old_wf" "$new_wf" 2>/dev/null || true
}

track_relocate_path() {
  local old="$1" new="$2"
  [[ -f "$old" ]] || return 1
  if paths_equal "$old" "$new"; then
    printf '%s' "$new"
    return 0
  fi
  [[ -e "$new" ]] && return 1
  local src_genre dest_genre
  src_genre="$(genre_from_path "$old")"
  mv "$old" "$new"
  dest_genre="$(genre_from_path "$new")"
  likes_relocate_path "$old" "$new"
  art_relocate_legacy "$old" "$new"
  waveform_relocate_cache "$old" "$new"
  [[ -n "$src_genre" ]] && tracks_cache_invalidate_genre "$src_genre"
  [[ -n "$dest_genre" ]] && tracks_cache_invalidate_genre "$dest_genre"
  printf '%s' "$new"
}

track_set_title() {
  local path="$1" title="$2"
  local dir ext artist new_base new_path
  [[ -f "$path" ]] || return 1
  title="$(printf '%s' "$title" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [[ -n "$title" ]] || return 1
  tag_set_metadata "$path" title "$title" || return 1
  ext="${path##*.}"
  if [[ "$ext" == "$path" || -z "$ext" ]]; then
    ext="mp3"
  fi
  dir="$(dirname "$path")"
  artist="$(ffprobe_meta "$path" artist)"
  new_base="$(track_filename_from_meta "$artist" "$title" "$ext")" || return 1
  new_path="${dir}/${new_base}"
  if paths_equal "$path" "$new_path"; then
    printf '%s' "$path"
    return 0
  fi
  new_path="$(track_relocate_path "$path" "$new_path")" || return 1
  printf '%s' "$new_path"
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
  local tags title artist genre album year label art="" wf="" liked_json=false
  tags="$(track_tags_read "$path")"
  title="$(jq -r '.title // ""' <<<"$tags")"
  artist="$(jq -r '.artist // ""' <<<"$tags")"
  genre="$(jq -r '.genre // ""' <<<"$tags")"
  album="$(jq -r '.album // ""' <<<"$tags")"
  year="$(jq -r '.year // ""' <<<"$tags")"
  label="$(jq -r '.label // ""' <<<"$tags")"
  art="$(art_path_cached "$path")"
  wf="$(waveform_cache_path "$path")"
  is_liked "$path" && liked_json=true
  printf '{"path":"%s","title":"%s","artist":"%s","genre":"%s","album":"%s","year":"%s","label":"%s","art":"%s","waveform":"%s","liked":%s}' \
    "$(json_escape "$path")" \
    "$(json_escape "$title")" \
    "$(json_escape "$artist")" \
    "$(json_escape "$genre")" \
    "$(json_escape "$album")" \
    "$(json_escape "$year")" \
    "$(json_escape "$label")" \
    "$(json_escape "$art")" \
    "$(json_escape "$wf")" \
    "$liked_json"
}

track_list_cached_json() {
  local path="$1"
  local genre cache row art="" wf="" liked_json=false
  [[ -f "$path" ]] || return 1
  genre="$(genre_from_path "$path")"
  if [[ -n "$genre" ]]; then
    cache="$(tracks_cache_path "$genre")"
    if [[ -f "$cache" ]]; then
      row="$(jq -c --arg p "$path" '.[] | select(.path == $p) | .' "$cache" 2>/dev/null | head -1)"
      if [[ -n "$row" ]]; then
        art="$(art_path_cached "$path")"
        wf="$(waveform_cache_path "$path")"
        is_liked "$path" && liked_json=true
        jq -c --arg art "$art" --arg waveform "$wf" --argjson liked "$liked_json" \
          '. + {art:$art, waveform:$waveform, liked:$liked}' <<<"$row"
        return 0
      fi
    fi
  fi
  track_list_json "$path"
}

playlist_paths_collect() {
  local list="$1"
  local line
  [[ -f "$list" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line//$'\r'/}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    [[ -f "$line" ]] || continue
    printf '%s\0' "$line"
  done <"$list"
}

playlist_emit_tracks_page() {
  local list="$1" offset="${2:-0}" limit="${3:-0}"
  python3 - "$list" "$offset" "$limit" "$TRACKS_CACHE_DIR" "$LIKES_FILE" "$ART_DIR" "$MUSIC_ROOT" <<'PY'
import json, os, re, subprocess, sys

list_path, offset_s, limit_s, cache_dir, likes_file, art_dir, music_root = sys.argv[1:8]
offset = max(0, int(offset_s or 0))
limit = max(0, int(limit_s or 0))

paths = []
with open(list_path, encoding="utf-8", errors="replace") as fh:
    for line in fh:
        line = line.strip("\r\n")
        if not line or line.startswith("#"):
            continue
        if os.path.isfile(line):
            paths.append(line)

total = len(paths)
if limit > 0:
    paths = paths[offset:offset + limit]
else:
    paths = paths[offset:]

genre_cache = {}

def slug(value):
    return re.sub(r"[^a-zA-Z0-9&_-]", "_", value or "")

def load_genre(genre):
    if genre in genre_cache:
        return genre_cache[genre]
    path = os.path.join(cache_dir, f"{slug(genre)}.tags.json")
    lookup = {}
    if os.path.isfile(path):
        try:
            with open(path, encoding="utf-8") as fh:
                for row in json.load(fh):
                    p = row.get("path")
                    if p:
                        lookup[p] = row
        except Exception:
            pass
    genre_cache[genre] = lookup
    return lookup

def read_tags(path):
    try:
        proc = subprocess.run(
            ["ffprobe", "-v", "quiet", "-print_format", "json", "-show_format", path],
            capture_output=True, text=True, check=False,
        )
        if proc.returncode != 0 or not proc.stdout.strip():
            return {}
        tags = json.loads(proc.stdout).get("format", {}).get("tags", {}) or {}
        lower = {k.lower(): str(v).strip() for k, v in tags.items() if v}

        def pick(*keys):
            for key in keys:
                val = lower.get(key.lower())
                if val:
                    return val
            return ""

        title = pick("title") or os.path.splitext(os.path.basename(path))[0]
        year = pick("date", "year", "originaldate", "original_year", "tyer")
        m = re.search(r"(\d{4})", year or "")
        return {
            "title": title,
            "artist": pick("artist", "album_artist", "albumartist"),
            "genre": pick("genre"),
            "album": pick("album"),
            "year": m.group(1) if m else "",
            "label": pick("label", "publisher", "organization", "tpub"),
        }
    except Exception:
        return {"title": os.path.splitext(os.path.basename(path))[0]}

def art_path(path):
    rel = path[len(music_root) + 1:] if path.startswith(music_root + os.sep) else os.path.basename(path)
    key = slug(rel)
    candidate = os.path.join(art_dir, f"{key}.jpg")
    if os.path.isfile(candidate):
        return candidate
    legacy = slug(os.path.basename(path))
    candidate = os.path.join(art_dir, f"{legacy}.jpg")
    return candidate if os.path.isfile(candidate) else ""

likes = set()
if os.path.isfile(likes_file):
    try:
        with open(likes_file, encoding="utf-8") as fh:
            likes = set(json.load(fh).keys())
    except Exception:
        likes = set()

def genre_from_path(path):
    rel = path[len(music_root) + 1:] if path.startswith(music_root + os.sep) else ""
    if not rel or rel == path:
        return ""
    return rel.split(os.sep, 1)[0]

items = []
for path in paths:
    genre = genre_from_path(path)
    row = load_genre(genre).get(path) if genre else None
    if not row:
        meta = read_tags(path)
        row = {
            "path": path,
            "title": meta.get("title", ""),
            "artist": meta.get("artist", ""),
            "genre": meta.get("genre", ""),
            "album": meta.get("album", ""),
            "year": meta.get("year", ""),
            "label": meta.get("label", ""),
        }
    else:
        row = dict(row)
    row["path"] = path
    row["art"] = row.get("art") or art_path(path)
    row["liked"] = path in likes
    items.append(row)

print(json.dumps({"total": total, "offset": offset, "items": items}, ensure_ascii=False))
PY
}

load_evoshell_secrets() {
  local secrets="${EVOSHELL_SECRETS:-${HOME}/.local/share/evoshell/secrets.env}"
  [[ -f "$secrets" ]] || return 0
  set -a
  # shellcheck disable=SC1090
  source "$secrets"
  set +a
}

genre_from_path() {
  local path="$1"
  local rel="${path#${MUSIC_ROOT}/}"
  [[ "$rel" == "$path" ]] && return 0
  printf '%s' "${rel%%/*}"
}

track_cache_slug() {
  printf '%s' "$1" | sed 's/[^a-zA-Z0-9_-]/_/g'
}

track_cache_slug_legacy() {
  printf '%s' "$1" | sed 's/[^a-zA-Z0-9&_-]/_/g'
}

tracks_cache_path() {
  printf '%s/%s.tags.json' "$TRACKS_CACHE_DIR" "$(track_cache_slug "$1")"
}

tracks_cache_stale() {
  local genre="$1"
  local cache="$2"
  local dir="$MUSIC_ROOT/$genre"
  local p
  [[ ! -f "$cache" ]] && return 0
  [[ ! -s "$cache" ]] && return 0
  jq -e 'type == "array"' "$cache" >/dev/null 2>&1 || return 0
  [[ ! -d "$dir" ]] && return 0
  [[ -n "$(find "$dir" -type f -newer "$cache" -print -quit 2>/dev/null)" ]] && return 0
  while IFS= read -r p; do
    [[ -n "$p" && ! -f "$p" ]] && return 0
  done < <(jq -r '.[].path // empty' "$cache" 2>/dev/null)
  return 1
}

tracks_cache_prune_missing() {
  local cache="$1"
  [[ -f "$cache" ]] || return 0
  local tmp removed=0
  tmp="$(mktemp "${cache}.XXXXXX")"
  removed="$(python3 - "$cache" "$tmp" <<'PY'
import json, os, sys

in_path, out_path = sys.argv[1:3]
with open(in_path, encoding="utf-8") as fh:
    items = json.load(fh)
if not isinstance(items, list):
    sys.exit(1)
kept = [item for item in items if item.get("path") and os.path.isfile(item["path"])]
removed = len(items) - len(kept)
with open(out_path, "w", encoding="utf-8") as fh:
    json.dump(kept, fh, ensure_ascii=False)
print(removed)
PY
)" || {
    rm -f "$tmp"
    return 1
  }
  [[ "$removed" =~ ^[0-9]+$ ]] || removed=0
  (( removed > 0 )) || {
    rm -f "$tmp"
    return 0
  }
  mv "$tmp" "$cache"
  printf '%s\n' "$(jq 'length' "$cache" 2>/dev/null || echo 0)" >"${cache%.tags.json}.count"
  return 0
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
  tracks_cache_prune_missing "$cache" 2>/dev/null || true

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
  art="$(art_cache_find "$path" 2>/dev/null || art_path_folder "$path")"
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

art_ensure_now() {
  local path="$1"
  [[ -f "$path" ]] || return 0
  [[ -n "$(art_path_cached "$path")" ]] && return 0
  art_path_for "$path" >/dev/null 2>&1
}

art_ensure_async() {
  local path="$1"
  [[ -f "$path" ]] || return 0
  [[ -n "$(art_path_cached "$path")" ]] && return 0
  (art_path_for "$path" >/dev/null 2>&1 &)
  disown
}

art_ensure_priority_async() {
  local path="$1"
  [[ -f "$path" ]] || return 0
  [[ -n "$(art_path_cached "$path")" ]] && return 0
  (nice -n -5 art_path_for "$path" >/dev/null 2>&1 &)
  disown
}

art_prioritize_paths() {
  local first=1 path
  for path in "$@"; do
    [[ -f "$path" ]] || continue
    if [[ "$first" -eq 1 ]]; then
      art_ensure_now "$path"
      first=0
    else
      art_ensure_priority_async "$path"
    fi
  done
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

art_track_in_genre_root() {
  local path="$1"
  local rel
  rel="${path#${MUSIC_ROOT}/}"
  [[ "$rel" == "$path" ]] && return 1
  [[ "$rel" == */* ]] || return 1
  [[ "$rel" == */*/* ]] && return 1
  return 0
}

art_folder_key() {
  local path="$1"
  local rel dir
  rel="${path#${MUSIC_ROOT}/}"
  [[ "$rel" == "$path" ]] && rel="$(basename "$path")"
  if art_track_in_genre_root "$path"; then
    cache_key "$path"
    return 0
  fi
  dir="$(dirname "$rel")"
  [[ "$dir" == "." || -z "$dir" ]] && dir="$rel"
  track_cache_slug "$dir"
}

art_image_hash() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  sha256sum "$file" | awk '{print $1}'
}

art_path_folder() {
  local path="$1"
  printf '%s/%s.jpg' "$ART_DIR" "$(art_folder_key "$path")"
}

art_path_content() {
  local hash="$1"
  printf '%s/%s.jpg' "$ART_DIR" "$hash"
}

art_path_legacy() {
  local path="$1"
  printf '%s/%s.jpg' "$ART_DIR" "$(cache_key "$path")"
}

art_link_folder_alias() {
  local folder_path="$1" content_path="$2"
  [[ -f "$content_path" ]] || return 1
  if [[ -f "$folder_path" ]]; then
    local ino1 ino2
    ino1="$(stat -c '%i' "$folder_path" 2>/dev/null || echo "")"
    ino2="$(stat -c '%i' "$content_path" 2>/dev/null || echo "")"
    [[ -n "$ino1" && "$ino1" == "$ino2" ]] && return 0
    rm -f "$folder_path"
  fi
  ln "$content_path" "$folder_path" 2>/dev/null || cp -f "$content_path" "$folder_path"
}

art_folder_key_legacy() {
  local path="$1"
  local rel dir
  rel="${path#${MUSIC_ROOT}/}"
  [[ "$rel" == "$path" ]] && rel="$(basename "$path")"
  if art_track_in_genre_root "$path"; then
    cache_key_legacy "$path"
    return 0
  fi
  dir="$(dirname "$rel")"
  [[ "$dir" == "." || -z "$dir" ]] && dir="$rel"
  track_cache_slug_legacy "$dir"
}

cache_key_legacy() {
  local path="$1"
  local rel="${path#${MUSIC_ROOT}/}"
  [[ "$rel" == "$path" ]] && rel="$(basename "$path")"
  track_cache_slug_legacy "$rel"
}

art_cache_find() {
  local path="$1" candidate
  [[ -f "$path" ]] || return 1
  candidate="$(art_path_legacy "$path")"
  [[ -f "$candidate" ]] && {
    printf '%s' "$candidate"
    return 0
  }
  candidate="$(art_path_folder "$path")"
  [[ -f "$candidate" ]] && {
    printf '%s' "$candidate"
    return 0
  }
  candidate="${ART_DIR}/$(cache_key_legacy "$path").jpg"
  [[ -f "$candidate" ]] && {
    printf '%s' "$candidate"
    return 0
  }
  candidate="${ART_DIR}/$(art_folder_key_legacy "$path").jpg"
  [[ -f "$candidate" ]] && {
    printf '%s' "$candidate"
    return 0
  }
  return 1
}

art_path_canonical() {
  art_path_folder "$1"
}

art_path_for() {
  local path="$1"
  local folder content imghash tmp
  [[ -f "$path" ]] || return 0
  folder="$(art_path_folder "$path")"
  if [[ -f "$folder" ]]; then
    printf '%s' "$folder"
    return 0
  fi
  tmp="$(mktemp "${ART_DIR}/.art.XXXXXX.jpg")"
  ffmpeg -y -loglevel error -i "$path" -an -vcodec copy "$tmp" 2>/dev/null || true
  if [[ ! -f "$tmp" || ! -s "$tmp" ]]; then
    rm -f "$tmp"
    return 0
  fi
  imghash="$(art_image_hash "$tmp")"
  if [[ -z "$imghash" ]]; then
    rm -f "$tmp"
    return 0
  fi
  content="$(art_path_content "$imghash")"
  if [[ ! -f "$content" ]]; then
    mv "$tmp" "$content"
  else
    rm -f "$tmp"
  fi
  art_link_folder_alias "$folder" "$content"
  [[ -f "$folder" ]] && printf '%s' "$folder"
}

art_path_resolve() {
  art_path_cached "$1"
}

art_path_cached() {
  local path="$1" art
  [[ -f "$path" ]] || return 0
  art="$(art_cache_find "$path")"
  [[ -n "$art" ]] && printf '%s' "$art"
  return 0
}

art_prune_legacy() {
  ensure_dirs
  local path legacy folder pruned=0 ino_legacy ino_folder
  while IFS= read -r -d '' path; do
    is_audio "$path" || continue
    legacy="$(art_path_legacy "$path")"
    folder="$(art_path_folder "$path")"
    [[ -f "$legacy" ]] || continue
    [[ "$legacy" == "$folder" ]] && continue
    [[ -f "$folder" ]] || continue
    ino_legacy="$(stat -c '%i' "$legacy" 2>/dev/null || echo "")"
    ino_folder="$(stat -c '%i' "$folder" 2>/dev/null || echo "")"
    if [[ -n "$ino_legacy" && "$ino_legacy" == "$ino_folder" ]]; then
      rm -f "$legacy"
      pruned=$((pruned + 1))
      continue
    fi
    if cmp -s "$legacy" "$folder" 2>/dev/null; then
      rm -f "$legacy"
      pruned=$((pruned + 1))
    fi
  done < <(find "$MUSIC_ROOT" -type f -print0 2>/dev/null)
  echo "evo-player: pruned ${pruned} duplicate art files" >&2
  printf '%d' "$pruned"
}

is_image() {
  local path="$1"
  [[ -f "$path" ]] || return 1
  local ext="${path##*.}"
  ext="${ext,,}"
  case "$ext" in
    jpg|jpeg|png|webp|gif|bmp) return 0 ;;
  esac
  return 1
}

art_normalize_jpg() {
  local src="$1"
  local dest="$2"
  [[ -f "$src" ]] || return 1
  if ffmpeg -y -loglevel error -i "$src" \
    -vf "scale=1200:1200:force_original_aspect_ratio=decrease" \
    -q:v 2 "$dest" 2>/dev/null && [[ -s "$dest" ]]; then
    return 0
  fi
  if command -v magick >/dev/null 2>&1; then
    magick "$src" -thumbnail 1200x1200\> -quality 90 "$dest" 2>/dev/null && [[ -s "$dest" ]] && return 0
  fi
  cp -f "$src" "$dest"
  [[ -s "$dest" ]]
}

art_strip_track_overrides_in_dir() {
  local track_path="$1"
  local dir folder legacy f
  dir="$(dirname "$track_path")"
  folder="$(art_path_folder "$track_path")"
  [[ -d "$dir" ]] || return 0
  while IFS= read -r -d '' f; do
    is_audio "$f" || continue
    legacy="$(art_path_legacy "$f")"
    [[ "$legacy" == "$folder" ]] && continue
    [[ -f "$legacy" ]] && rm -f "$legacy"
  done < <(find "$dir" -maxdepth 1 -type f -print0 2>/dev/null)
}

art_install_image() {
  local track_path="$1"
  local image_path="$2"
  local scope="${3:-track}"
  local dest_art content imghash tmp
  [[ -f "$track_path" ]] && is_audio "$track_path" || return 1
  [[ -f "$image_path" ]] && is_image "$image_path" || return 1
  [[ "$scope" == "album" || "$scope" == "track" ]] || return 1
  ensure_dirs
  if [[ "$scope" == "album" ]]; then
    dest_art="$(art_path_folder "$track_path")"
  else
    dest_art="$(art_path_legacy "$track_path")"
  fi
  tmp="$(mktemp "${ART_DIR}/.install.XXXXXX.jpg")"
  art_normalize_jpg "$image_path" "$tmp" || {
    rm -f "$tmp"
    return 1
  }
  imghash="$(art_image_hash "$tmp")"
  if [[ -z "$imghash" ]]; then
    rm -f "$tmp"
    return 1
  fi
  content="$(art_path_content "$imghash")"
  if [[ ! -f "$content" ]]; then
    mv "$tmp" "$content"
  else
    rm -f "$tmp"
  fi
  art_link_folder_alias "$dest_art" "$content" || return 1
  if [[ "$scope" == "album" ]]; then
    art_strip_track_overrides_in_dir "$track_path"
  fi
  art_dirty_mark "$track_path" "$scope" || true
  printf '%s' "$dest_art"
}

art_dirty_ensure() {
  ensure_dirs
  if [[ ! -f "$ART_DIRTY" ]] || ! jq -e 'type == "object"' "$ART_DIRTY" >/dev/null 2>&1; then
    printf '{"dirs":{},"tracks":{}}\n' >"$ART_DIRTY"
  fi
}

art_dirty_snapshot() {
  ensure_dirs
  (
    flock -x 9
    art_dirty_ensure
    jq -c '{dirs:(.dirs // {}), tracks:(.tracks // {})}' "$ART_DIRTY"
  ) 9>"${ART_DIRTY}.lock"
}

art_dirty_mark() {
  local path="${1:-}"
  local scope="${2:-album}"
  local key kind at tmp
  [[ -n "$path" ]] || return 0
  path="$(readlink -f "$path" 2>/dev/null || printf '%s' "$path")"
  [[ -e "$path" ]] || return 0
  ensure_dirs
  at="$(date -Iseconds)"
  if [[ "$scope" == "track" ]] || art_track_in_genre_root "$path"; then
    kind="tracks"
    key="$path"
  else
    kind="dirs"
    key="$(dirname "$path")"
  fi
  (
    flock -x 9
    art_dirty_ensure
    tmp="$(mktemp "${ART_DIRTY}.XXXXXX")"
    jq --arg kind "$kind" --arg key "$key" --arg at "$at" \
      '.[$kind][$key] = {at:$at}' "$ART_DIRTY" >"$tmp" && mv "$tmp" "$ART_DIRTY"
  ) 9>"${ART_DIRTY}.lock" || true
}

art_dirty_clear_if() {
  local kind="${1:-}"
  local key="${2:-}"
  local at="${3:-}"
  local tmp
  [[ -n "$kind" && -n "$key" ]] || return 0
  (
    flock -x 9
    [[ -f "$ART_DIRTY" ]] || exit 0
    tmp="$(mktemp "${ART_DIRTY}.XXXXXX")"
    jq --arg kind "$kind" --arg key "$key" --arg at "$at" \
      'if ((.[$kind][$key].at // "") == $at) then del(.[$kind][$key]) else . end' \
      "$ART_DIRTY" >"$tmp" && mv "$tmp" "$ART_DIRTY"
  ) 9>"${ART_DIRTY}.lock" || true
}

art_notify_cache() {
  local path="$1" art dest hash tmp
  [[ -f "$path" ]] || return 1
  art="$(art_path_cached "$path")"
  if [[ -z "$art" ]]; then
    art_ensure_now "$path"
    art="$(art_path_cached "$path")"
  fi
  [[ -n "$art" && -f "$art" ]] || return 1
  hash="$(art_image_hash "$art")"
  [[ -n "$hash" ]] || return 1
  dest="${XDG_CACHE_HOME:-$HOME/.cache}/evoshell/display-art/${hash}.jpg"
  mkdir -p "$(dirname "$dest")"
  if [[ -f "$dest" ]] && cmp -s "$art" "$dest" 2>/dev/null; then
    printf '%s' "$dest"
    return 0
  fi
  tmp="$(mktemp "${dest}.XXXXXX")"
  cp "$art" "$tmp" && mv -f "$tmp" "$dest"
  printf '%s' "$dest"
}

scrobble_recording_mbid() {
  local artist="$1" title="$2" album="${3:-}"
  [[ -n "$artist" && -n "$title" ]] || return 0
  python3 - "$artist" "$title" "$album" <<'PY'
import json, sys, time, urllib.parse, urllib.request

artist, title, album = sys.argv[1:4]
terms = [f'artist:"{artist}"', f'recording:"{title}"']
if album:
    terms.append(f'release:"{album}"')
query = " AND ".join(terms)
url = "https://musicbrainz.org/ws/2/recording/?" + urllib.parse.urlencode({
    "query": query,
    "fmt": "json",
    "limit": 1,
})
req = urllib.request.Request(url, headers={"User-Agent": "evo-player/1.0 (local scrobbler)"})
time.sleep(1)
try:
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = json.load(resp)
except Exception:
    raise SystemExit
for rec in data.get("recordings") or []:
    mbid = rec.get("id") or ""
    if mbid:
        print(mbid)
        break
PY
}

scrobble_art_for_path() {
  local path="$1" art=""
  [[ -f "$path" ]] || return 0
  art="$(art_path_cached "$path")"
  if [[ -z "$art" ]]; then
    art_ensure_now "$path"
    art="$(art_path_cached "$path")"
  fi
  if [[ -n "$art" && -f "$art" ]]; then
    art="$(art_notify_cache "$path" 2>/dev/null || printf '%s' "$art")"
  fi
  printf '%s' "$art"
}

scrobble_record_entry() {
  local path="$1" event="${2:-submit}"
  [[ -f "$path" ]] || return 0
  ensure_dirs
  local tags artist title album art liked="false"
  tags="$(track_tags_read "$path")"
  artist="$(jq -r '.artist // ""' <<<"$tags")"
  title="$(jq -r '.title // ""' <<<"$tags")"
  album="$(jq -r '.album // ""' <<<"$tags")"
  [[ -n "$artist" && -n "$title" ]] || return 0
  art="$(scrobble_art_for_path "$path")"
  is_liked "$path" && liked="true"
  jq -nc \
    --arg at "$(date -Iseconds)" \
    --arg event "$event" \
    --arg path "$path" \
    --arg artist "$artist" \
    --arg title "$title" \
    --arg album "$album" \
    --arg art "$art" \
    --argjson liked "$([[ $liked == true ]] && echo true || echo false)" \
    '{at:$at,event:$event,path:$path,artist:$artist,title:$title,album:$album,art:$art,liked:$liked}' >>"$SCROBBLE_LOG"
}

scrobble_recent_json() {
  local limit="${1:-12}"
  ensure_dirs
  if [[ ! -f "$SCROBBLE_LOG" ]]; then
    printf '[]\n'
    return 0
  fi
  local rows
  rows="$(
    python3 - "$SCROBBLE_LOG" "$limit" <<'PY'
import json, sys

log_path, limit = sys.argv[1], int(sys.argv[2])
seen, out = set(), []
if not log_path:
    print("[]")
    raise SystemExit
with open(log_path, encoding="utf-8") as fh:
    lines = [ln.strip() for ln in fh if ln.strip()]
for line in reversed(lines):
    try:
        row = json.loads(line)
    except json.JSONDecodeError:
        continue
    key = row.get("path") or (row.get("artist", ""), row.get("title", ""))
    if key in seen:
        continue
    seen.add(key)
    out.append(row)
    if len(out) >= limit:
        break
print(json.dumps(out, ensure_ascii=False))
PY
  )"
  [[ -n "$rows" && "$rows" != "[]" ]] || {
    printf '[]\n'
    return 0
  }
  local items=() row path art liked cached
  while IFS= read -r row; do
    [[ -n "$row" ]] || continue
    path="$(jq -r '.path // ""' <<<"$row")"
    art="$(jq -r '.art // ""' <<<"$row")"
    liked="$(jq -r '.liked // false' <<<"$row")"
    if [[ -n "$path" && -f "$path" ]]; then
      cached="$(art_path_cached "$path")"
      [[ -n "$cached" ]] && art="$cached"
      is_liked "$path" && liked=true || liked=false
    fi
    items+=("$(
      jq -c \
        --arg art "$art" \
        --argjson liked "$([[ $liked == true ]] && echo true || echo false)" \
        '.art = $art | .liked = $liked' <<<"$row"
    )")
  done < <(jq -c '.[]' <<<"$rows")
  if ((${#items[@]} == 0)); then
    printf '[]\n'
    return 0
  fi
  local joined=""
  local i
  for i in "${!items[@]}"; do
    [[ -n "$joined" ]] && joined+=","
    joined+="${items[$i]}"
  done
  printf '[%s]\n' "$joined"
}

art_embed_stamp() {
  local audio="$1"
  local stamp="" pic="0"
  stamp="$(ffprobe -v quiet -show_entries format_tags=EVO_ART_HASH -of default=noprint_wrappers=1:nokey=1 "$audio" 2>/dev/null | head -1)"
  stamp="${stamp//$'\r'/}"
  if ffprobe -v quiet -select_streams v:0 -show_entries stream=codec_type -of csv=p=0 "$audio" 2>/dev/null | grep -qx video; then
    pic="1"
  fi
  printf '%s\t%s' "$stamp" "$pic"
}

art_embed_write_stamp() {
  local audio="$1"
  local hash="$2"
  local have
  [[ -f "$audio" && -n "$hash" ]] || return 0
  have="$(ffprobe -v quiet -show_entries format_tags=EVO_ART_HASH -of default=noprint_wrappers=1:nokey=1 "$audio" 2>/dev/null | head -1)"
  have="${have//$'\r'/}"
  [[ "$have" == "$hash" ]] && return 0
  local ext tmp
  ext="${audio##*.}"
  ext="${ext,,}"
  tmp="$(mktemp "${audio}.XXXXXX.${ext}")"
  ffmpeg -y -loglevel error -i "$audio" -c copy -map 0 -metadata EVO_ART_HASH="$hash" "$tmp" 2>/dev/null || {
    rm -f "$tmp"
    return 0
  }
  mv "$tmp" "$audio"
}

art_embed_audio() {
  local audio="$1"
  local art="$2"
  local ext tmp want have pic
  [[ -f "$audio" && -f "$art" ]] || return 1
  is_audio "$audio" || return 1
  want="$(art_image_hash "$art")"
  [[ -n "$want" ]] || return 1
  IFS=$'\t' read -r have pic < <(art_embed_stamp "$audio")
  if [[ "$have" == "$want" && "$pic" == "1" ]]; then
    return 2
  fi
  ext="${audio##*.}"
  ext="${ext,,}"
  tmp="$(mktemp "${audio}.XXXXXX.${ext}")"
  case "$ext" in
    mp3)
      ffmpeg -y -loglevel error -i "$audio" -i "$art" \
        -map 0:a -map 1:v -c:a copy -c:v mjpeg \
        -id3v2_version 3 \
        -metadata:s:v title="Album cover" \
        -metadata:s:v comment="Cover (front)" \
        -metadata EVO_ART_HASH="$want" \
        "$tmp" 2>/dev/null || {
        rm -f "$tmp"
        return 1
      }
      ;;
    flac|ogg|opus|m4a)
      ffmpeg -y -loglevel error -i "$audio" -i "$art" \
        -map 0 -map 1 -c copy -disposition:v:0 attached_pic \
        -metadata EVO_ART_HASH="$want" \
        "$tmp" 2>/dev/null || {
        rm -f "$tmp"
        return 1
      }
      ;;
    *)
      rm -f "$tmp"
      return 1
      ;;
  esac
  mv "$tmp" "$audio"
  art_embed_write_stamp "$audio" "$want" || true
  return 0
}

art_embed_folder() {
  local dir_path="$1"
  local track="" art="" entry embedded=0 failed=0 skipped=0 status
  [[ -d "$dir_path" ]] || return 1
  while IFS= read -r -d '' entry; do
    is_audio "$entry" || continue
    track="$entry"
    break
  done < <(find "$dir_path" -maxdepth 1 -type f -print0 2>/dev/null)
  [[ -n "$track" ]] || {
    printf '%d %d %d' 0 0 0
    return 0
  }
  art="$(art_path_folder "$track")"
  [[ -f "$art" ]] || {
    printf '%d %d %d' 0 0 0
    return 0
  }
  while IFS= read -r -d '' entry; do
    is_audio "$entry" || continue
    status=0
    art_embed_audio "$entry" "$art" || status=$?
    if [[ "$status" -eq 0 ]]; then
      embedded=$((embedded + 1))
    elif [[ "$status" -eq 2 ]]; then
      skipped=$((skipped + 1))
    else
      failed=$((failed + 1))
    fi
  done < <(find "$dir_path" -maxdepth 1 -type f -print0 2>/dev/null)
  printf '%d %d %d' "$embedded" "$failed" "$skipped"
}

