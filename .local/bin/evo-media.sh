#!/usr/bin/env bash
# Local film/TV library index + playback for evo-shell.
# Poster fetching stays in evo-media-fetch-posters.py (separate).

set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/evo-shell"
DB_PATH="${STATE_DIR}/media.db"
POSTER_DIR="${STATE_DIR}/media-posters"
FILMS_ROOT="${EVO_MEDIA_FILMS:-/mnt/external/films}"
TV_ROOT="${EVO_MEDIA_TV:-/mnt/external/tv}"
VIDEO_EXTS='mkv mp4 m4v avi'

usage() {
    cat >&2 <<'EOF'
usage:
  evo-media.sh scan
  evo-media.sh status
  evo-media.sh list films
  evo-media.sh list shows
  evo-media.sh list episodes <show>
  evo-media.sh play film <id>
  evo-media.sh play episode <id>
EOF
    exit 1
}

sql_escape() {
    local s="$1"
    s="${s//\'/\'\'}"
    printf '%s' "$s"
}

sql_null_int() {
    if [[ -z "${1:-}" ]]; then
        printf 'NULL'
    else
        printf '%s' "$1"
    fi
}

init_db() {
    mkdir -p "$STATE_DIR"
    sqlite3 "$DB_PATH" <<'SQL'
CREATE TABLE IF NOT EXISTS films (
    id INTEGER PRIMARY KEY,
    path TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    year INTEGER,
    sort_title TEXT NOT NULL,
    poster_path TEXT
);
CREATE TABLE IF NOT EXISTS shows (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    folder_path TEXT NOT NULL UNIQUE,
    poster_path TEXT
);
CREATE TABLE IF NOT EXISTS episodes (
    id INTEGER PRIMARY KEY,
    show_id INTEGER NOT NULL,
    path TEXT NOT NULL UNIQUE,
    season INTEGER,
    episode INTEGER,
    title TEXT NOT NULL,
    sort_key TEXT NOT NULL,
    poster_path TEXT,
    FOREIGN KEY (show_id) REFERENCES shows(id)
);
CREATE INDEX IF NOT EXISTS idx_episodes_show ON episodes(show_id);
SQL
    sqlite3 "$DB_PATH" "ALTER TABLE episodes ADD COLUMN poster_path TEXT" 2>/dev/null || true
}

is_video() {
    local path="$1"
    [[ -f "$path" ]] || return 1
    local ext="${path##*.}"
    ext="${ext,,}"
    local allowed
    for allowed in $VIDEO_EXTS; do
        if [[ "$ext" == "$allowed" ]]; then
            return 0
        fi
    done
    return 1
}

clean_name() {
    local text="$1"
    text="${text//./ }"
    text="${text//_/ }"
    text="$(printf '%s' "$text" | sed -E 's/[[:space:]]+/ /g; s/^[[:space:]]+//; s/[[:space:]]+$//')"
    printf '%s' "$text"
}

strip_video_ext() {
    local text="$1"
    local lower="${text,,}"
    local ext dotext
    for ext in $VIDEO_EXTS; do
        dotext=".${ext}"
        if [[ "$lower" == *"$dotext" ]]; then
            printf '%s' "${text:0:$((${#text} - ${#dotext}))}"
            return 0
        fi
    done
    printf '%s' "$text"
}

display_title() {
    local text="$1"
    local out
    out="$(strip_video_ext "$text")"
    out="$(clean_name "$out")"
    if [[ -z "$out" ]]; then
        out="$text"
    fi
    printf '%s' "$out"
}

parse_film() {
    local path="$1"
    local filename stem title year="" sort_title

    filename="$(basename "$path")"
    stem="$(strip_video_ext "$filename")"
    title="$stem"

    local year_paren year_space
    year_paren="$(printf '%s' "$stem" | sed -nE 's/.*\(([0-9]{4})\)[[:space:]]*$/\1/p')"
    if [[ -n "$year_paren" ]]; then
        year="$year_paren"
        title="$(printf '%s' "$stem" | sed -E 's/[[:space:]]*\([0-9]{4}\)[[:space:]]*$//')"
        title="$(printf '%s' "$title" | sed -E 's/[ -._]+$//')"
    else
        year_space="$(printf '%s' "$stem" | sed -nE 's/.*[[:space:]]([0-9]{4})[[:space:]]*$/\1/p')"
        if [[ -n "$year_space" ]]; then
            year="$year_space"
            title="$(printf '%s' "$stem" | sed -E 's/[[:space:]][0-9]{4}[[:space:]]*$//')"
            title="$(printf '%s' "$title" | sed -E 's/[ -._]+$//')"
        fi
    fi

    title="$(clean_name "$title")"
    [[ -z "$title" ]] && title="$stem"
    sort_title="$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]')"

    FILM_TITLE="$title"
    FILM_YEAR="$year"
    FILM_SORT_TITLE="$sort_title"
}

parse_episode() {
    local filename="$1"
    local season="" episode="" title sort_key season_ep

    season_ep="$(printf '%s' "$filename" | grep -oiE 'S[0-9]{1,2}E[0-9]{1,3}' | head -1 || true)"
    if [[ -n "$season_ep" ]]; then
        season="$(printf '%s' "$season_ep" | sed -E 's/^S([0-9]+)E.*/\1/i')"
        episode="$(printf '%s' "$season_ep" | sed -E 's/^S[0-9]+E([0-9]+)$/\1/i')"
        title="$(printf '%s' "$filename" | sed -E 's/.*S[0-9]{1,2}E[0-9]{1,3}//i' | sed -E 's/^[ -._]+//')"
    else
        title="$filename"
    fi

    title="$(display_title "$title")"
    [[ -z "$title" ]] && title="$(display_title "$filename")"
    [[ -z "$title" ]] && title="$filename"

    if [[ -n "$season" && -n "$episode" ]]; then
        sort_key="$(printf '%02d-%04d-%s' "$season" "$episode" "$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]')")"
    else
        sort_key="$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]')"
    fi

    EP_SEASON="$season"
    EP_EPISODE="$episode"
    EP_TITLE="$title"
    EP_SORT_KEY="$sort_key"
}

poster_url() {
    local path="${1:-}"
    if [[ -n "$path" && -f "$path" ]]; then
        local resolved uri
        resolved="$(realpath "$path")"
        uri="file://${resolved// /%20}"
        printf '%s' "$uri"
    else
        printf ''
    fi
}

format_episode_label() {
    local season="${1:-}"
    local episode="${2:-}"
    local title="$3"
    local display
    display="$(display_title "$title")"
    [[ -z "$display" ]] && display="$title"
    if [[ -n "$season" && -n "$episode" ]]; then
        printf 'S%02dE%02d · %s' "$season" "$episode" "$display"
    else
        printf '%s' "$display"
    fi
}

find_video_files() {
    local dir="$1"
    local -a find_args=("$dir" -type f '(')
    local ext first=true
    for ext in $VIDEO_EXTS; do
        if $first; then
            first=false
        else
            find_args+=(-o)
        fi
        find_args+=(-iname "*.${ext}")
    done
    find_args+=(')')
    find "${find_args[@]}" 2>/dev/null | LC_ALL=C sort
}

enrich_rows() {
    jq -c '.[]' | while IFS= read -r row; do
        local title pp poster display label season episode
        title="$(jq -r '.title // .name // empty' <<<"$row")"
        pp="$(jq -r '.poster_path // empty' <<<"$row")"
        poster="$(poster_url "$pp")"
        if [[ "${1:-}" == "episode" ]]; then
            season="$(jq -r '.season // empty' <<<"$row")"
            episode="$(jq -r '.episode // empty' <<<"$row")"
            display="$(display_title "$title")"
            label="$(format_episode_label "$season" "$episode" "$title")"
            jq -n --argjson row "$row" --arg poster "$poster" --arg display "$display" --arg label "$label" \
                '$row | . + {poster_path: (.poster_path // ""), poster: $poster, title: $display, label: $label}'
        elif [[ "${1:-}" == "show" ]]; then
            jq -n --argjson row "$row" --arg poster "$poster" \
                '$row | {id: .id, name: .name, poster_path: (.poster_path // ""), poster: $poster, episodes: .episodes}'
        else
            display="$(display_title "$title")"
            jq -n --argjson row "$row" --arg poster "$poster" --arg display "$display" \
                '$row | {id: .id, title: $display, year: .year, poster_path: (.poster_path // ""), poster: $poster, path: .path}'
        fi
    done | jq -s '.'
}

cmd_scan() {
    init_db
    sqlite3 "$DB_PATH" "DELETE FROM episodes; DELETE FROM shows; DELETE FROM films;"

    local film_count=0 show_count=0 episode_count=0 path show_dir show_name show_id resolved

    if [[ -d "$FILMS_ROOT" ]]; then
        while IFS= read -r path; do
            [[ -n "$path" ]] || continue
            parse_film "$path"
            resolved="$(realpath "$path")"
            sqlite3 "$DB_PATH" \
                "INSERT INTO films(path, title, year, sort_title, poster_path) VALUES ('$(sql_escape "$resolved")', '$(sql_escape "$FILM_TITLE")', $(sql_null_int "$FILM_YEAR"), '$(sql_escape "$FILM_SORT_TITLE")', NULL);"
            film_count=$((film_count + 1))
        done < <(
            for path in "$FILMS_ROOT"/*; do
                [[ -f "$path" ]] && is_video "$path" && printf '%s\n' "$path"
            done | LC_ALL=C sort
        )
    fi

    if [[ -d "$TV_ROOT" ]]; then
        while IFS= read -r show_dir; do
            [[ -n "$show_dir" ]] || continue
            show_name="$(clean_name "$(basename "$show_dir")")"
            [[ -z "$show_name" ]] && show_name="$(basename "$show_dir")"
            resolved="$(realpath "$show_dir")"
            show_id="$(sqlite3 "$DB_PATH" \
                "INSERT INTO shows(name, folder_path, poster_path) VALUES ('$(sql_escape "$show_name")', '$(sql_escape "$resolved")', NULL); SELECT last_insert_rowid();")"
            show_count=$((show_count + 1))

            while IFS= read -r path; do
                [[ -n "$path" ]] || continue
                parse_episode "$(basename "$path")" "$show_name"
                resolved="$(realpath "$path")"
                sqlite3 "$DB_PATH" \
                    "INSERT INTO episodes(show_id, path, season, episode, title, sort_key, poster_path) VALUES ($show_id, '$(sql_escape "$resolved")', $(sql_null_int "$EP_SEASON"), $(sql_null_int "$EP_EPISODE"), '$(sql_escape "$EP_TITLE")', '$(sql_escape "$EP_SORT_KEY")', NULL);"
                episode_count=$((episode_count + 1))
            done < <(find_video_files "$show_dir")
        done < <(
            for show_dir in "$TV_ROOT"/*; do
                [[ -d "$show_dir" ]] && printf '%s\n' "$show_dir"
            done | LC_ALL=C sort
        )
    fi

    jq -n \
        --argjson films "$film_count" \
        --argjson shows "$show_count" \
        --argjson episodes "$episode_count" \
        '{ok: true, films: $films, shows: $shows, episodes: $episodes}'
}

cmd_status() {
    if [[ ! -f "$DB_PATH" ]]; then
        jq -n '{ok: true, exists: false, films: 0, shows: 0, episodes: 0}'
        return 0
    fi
    init_db
    local films shows episodes
    films="$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM films")"
    shows="$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM shows")"
    episodes="$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM episodes")"
    jq -n \
        --argjson films "$films" \
        --argjson shows "$shows" \
        --argjson episodes "$episodes" \
        '{ok: true, exists: true, films: $films, shows: $shows, episodes: $episodes}'
}

cmd_list_films() {
    init_db
    local raw
    raw="$(sqlite3 -json "$DB_PATH" \
        "SELECT id, title, year, poster_path, path FROM films ORDER BY sort_title COLLATE NOCASE")"
    [[ -z "$raw" ]] && raw='[]'
    printf '%s\n' "$raw" | enrich_rows
}

cmd_list_shows() {
    init_db
    local raw
    raw="$(sqlite3 -json "$DB_PATH" \
        "SELECT s.id, s.name, s.poster_path, (SELECT COUNT(*) FROM episodes e WHERE e.show_id = s.id) AS episodes FROM shows s ORDER BY s.name COLLATE NOCASE")"
    [[ -z "$raw" ]] && raw='[]'
    printf '%s\n' "$raw" | enrich_rows show
}

cmd_list_episodes() {
    local show_query="$1"
    local escaped show_data show_id show_name raw enriched

    init_db
    escaped="$(sql_escape "$show_query")"
    show_data="$(sqlite3 "$DB_PATH" \
        "SELECT id, name FROM shows WHERE name = '$escaped' COLLATE NOCASE LIMIT 1")"

    if [[ -z "$show_data" ]]; then
        jq -n --arg show "$show_query" '{ok: false, error: "show not found", show: $show, seasons: []}'
        return 0
    fi

    show_id="${show_data%%|*}"
    show_name="${show_data#*|}"
    raw="$(sqlite3 -json "$DB_PATH" \
        "SELECT id, season, episode, title, path, poster_path FROM episodes WHERE show_id = $show_id ORDER BY sort_key COLLATE NOCASE")"
    [[ -z "$raw" ]] && raw='[]'
    enriched="$(printf '%s\n' "$raw" | enrich_rows episode)"

    jq -n \
        --arg show "$show_name" \
        --argjson showId "$show_id" \
        --argjson episodes "$enriched" \
        --argjson seasons "$(
            jq '
                group_by(.season // 0)
                | map({
                    season: (if (.[0].season // 0) == 0 then null else .[0].season end),
                    label: (
                        if (.[0].season // 0) == 0 then "Episodes"
                        else "Season " + (
                            if (.[0].season < 10) then "0" + (.[0].season | tostring)
                            else (.[0].season | tostring) end
                        ) end
                    ),
                    episodes: .
                })
                | sort_by(.season // 0)
            ' <<<"$enriched"
        )" \
        '{ok: true, show: $show, showId: $showId, episodes: $episodes, seasons: $seasons}'
}

cmd_play() {
    local kind="$1"
    local entry_id="$2"
    local path

    if ! [[ "$entry_id" =~ ^[0-9]+$ ]]; then
        jq -n '{ok: false, error: "invalid id"}'
        return 0
    fi

    init_db

    if [[ "$kind" == "film" ]]; then
        path="$(sqlite3 "$DB_PATH" "SELECT path FROM films WHERE id = $entry_id")"
    elif [[ "$kind" == "episode" ]]; then
        path="$(sqlite3 "$DB_PATH" "SELECT path FROM episodes WHERE id = $entry_id")"
    else
        jq -n '{ok: false, error: "invalid kind"}'
        return 0
    fi

    if [[ -z "$path" ]]; then
        jq -n '{ok: false, error: "not found"}'
        return 0
    fi

    if [[ ! -f "$path" ]]; then
        jq -n --arg path "$path" '{ok: false, error: "file missing", path: $path}'
        return 0
    fi

    nohup mpv --fs --really-quiet "$path" >/dev/null 2>&1 &
    disown
    jq -n --arg path "$path" '{ok: true, path: $path}'
}

cmd="${1:-}"
case "$cmd" in
scan)
    cmd_scan
    ;;
status)
    cmd_status
    ;;
list)
    sub="${2:-}"
    case "$sub" in
    films)
        cmd_list_films
        ;;
    shows)
        cmd_list_shows
        ;;
    episodes)
        show="${3:-}"
        [[ -n "$show" ]] || usage
        cmd_list_episodes "$show"
        ;;
    *)
        usage
        ;;
    esac
    ;;
play)
    kind="${2:-}"
    entry_id="${3:-}"
    [[ "$kind" == "film" || "$kind" == "episode" ]] || usage
    [[ "$entry_id" =~ ^[0-9]+$ ]] || usage
    cmd_play "$kind" "$entry_id"
    ;;
*)
    usage
    ;;
esac
