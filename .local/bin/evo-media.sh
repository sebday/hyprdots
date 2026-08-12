#!/usr/bin/env bash
# Local film/TV library index + playback for evo-shell.

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

media_py() {
    python3 - "$@" <<'PY'
import json
import os
import re
import sqlite3
import subprocess
import sys
from pathlib import Path

cmd = sys.argv[1]
db_path = sys.argv[2]
poster_dir = sys.argv[3]
films_root = Path(sys.argv[4])
tv_root = Path(sys.argv[5])
video_exts = {f".{x.strip()}" for x in sys.argv[6].split() if x.strip()}

SEASON_EP_RE = re.compile(r"(?i)\bS(\d{1,2})E(\d{1,3})\b")
YEAR_RE = re.compile(r"(?:\((\d{4})\)|\b(\d{4})\b)\s*$")


def connect():
    os.makedirs(os.path.dirname(db_path) or ".", exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    return conn


def init_db(conn):
    conn.executescript(
        """
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
        """
    )
    try:
        conn.execute("ALTER TABLE episodes ADD COLUMN poster_path TEXT")
    except sqlite3.OperationalError:
        pass
    conn.commit()


def is_video(path: Path) -> bool:
    return path.is_file() and path.suffix.lower() in video_exts


def clean_name(text: str) -> str:
    text = re.sub(r"[._]+", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def strip_video_ext(text: str) -> str:
    lower = text.lower()
    for ext in video_exts:
        if lower.endswith(ext):
            return text[: -len(ext)]
    return text


def display_title(text: str) -> str:
    return clean_name(strip_video_ext(text)) or text


def parse_film(path: Path):
    stem = path.stem
    year = None
    m = YEAR_RE.search(stem)
    title = stem
    if m:
        year = int(m.group(1) or m.group(2))
        title = stem[: m.start()].strip(" -._")
    title = clean_name(title) or stem
    sort_title = title.lower()
    return title, year, sort_title


def parse_episode(filename: str, show_name: str):
    m = SEASON_EP_RE.search(filename)
    season = int(m.group(1)) if m else None
    episode = int(m.group(2)) if m else None
    title = filename
    if m:
        title = filename[m.end() :].strip(" -._")
    title = display_title(title) or display_title(filename) or filename
    if season is not None and episode is not None:
        sort_key = f"{season:02d}-{episode:04d}-{title.lower()}"
    else:
        sort_key = title.lower()
    return season, episode, title, sort_key


def scan():
    conn = connect()
    init_db(conn)
    conn.execute("DELETE FROM episodes")
    conn.execute("DELETE FROM shows")
    conn.execute("DELETE FROM films")

    film_count = 0
    if films_root.is_dir():
        for path in sorted(films_root.iterdir()):
            if not is_video(path):
                continue
            title, year, sort_title = parse_film(path)
            conn.execute(
                """
                INSERT INTO films(path, title, year, sort_title, poster_path)
                VALUES (?, ?, ?, ?, NULL)
                """,
                (str(path.resolve()), title, year, sort_title),
            )
            film_count += 1

    show_count = 0
    episode_count = 0
    if tv_root.is_dir():
        for show_dir in sorted(p for p in tv_root.iterdir() if p.is_dir()):
            show_name = clean_name(show_dir.name) or show_dir.name
            cur = conn.execute(
                """
                INSERT INTO shows(name, folder_path, poster_path)
                VALUES (?, ?, NULL)
                """,
                (show_name, str(show_dir.resolve())),
            )
            show_id = cur.lastrowid
            show_count += 1
            for path in sorted(show_dir.rglob("*")):
                if not is_video(path):
                    continue
                season, episode, title, sort_key = parse_episode(path.name, show_name)
                conn.execute(
                    """
                    INSERT INTO episodes(show_id, path, season, episode, title, sort_key, poster_path)
                    VALUES (?, ?, ?, ?, ?, ?, NULL)
                    """,
                    (show_id, str(path.resolve()), season, episode, title, sort_key),
                )
                episode_count += 1

    conn.commit()
    conn.close()
    print(
        json.dumps(
            {
                "ok": True,
                "films": film_count,
                "shows": show_count,
                "episodes": episode_count,
            }
        )
    )


def status():
    if not os.path.isfile(db_path):
        print(json.dumps({"ok": True, "exists": False, "films": 0, "shows": 0, "episodes": 0}))
        return
    conn = connect()
    init_db(conn)
    films = conn.execute("SELECT COUNT(*) FROM films").fetchone()[0]
    shows = conn.execute("SELECT COUNT(*) FROM shows").fetchone()[0]
    episodes = conn.execute("SELECT COUNT(*) FROM episodes").fetchone()[0]
    conn.close()
    print(json.dumps({"ok": True, "exists": True, "films": films, "shows": shows, "episodes": episodes}))


def poster_url(path):
    if not path:
        return ""
    p = Path(path)
    if p.is_file():
        return p.resolve().as_uri()
    return ""


def list_films():
    conn = connect()
    init_db(conn)
    rows = conn.execute(
        """
        SELECT id, title, year, poster_path, path
        FROM films
        ORDER BY sort_title COLLATE NOCASE
        """
    ).fetchall()
    conn.close()
    out = []
    for row in rows:
        out.append(
            {
                "id": row["id"],
                "title": display_title(row["title"]),
                "year": row["year"],
                "poster_path": row["poster_path"] or "",
                "poster": poster_url(row["poster_path"]),
                "path": row["path"],
            }
        )
    print(json.dumps(out))


def list_shows():
    conn = connect()
    init_db(conn)
    rows = conn.execute(
        """
        SELECT s.id, s.name, s.poster_path,
               (SELECT COUNT(*) FROM episodes e WHERE e.show_id = s.id) AS episodes
        FROM shows s
        ORDER BY s.name COLLATE NOCASE
        """
    ).fetchall()
    conn.close()
    out = []
    for row in rows:
        out.append(
            {
                "id": row["id"],
                "name": row["name"],
                "poster_path": row["poster_path"] or "",
                "poster": poster_url(row["poster_path"]),
                "episodes": row["episodes"],
            }
        )
    print(json.dumps(out))


def list_episodes(show_name: str):
    conn = connect()
    init_db(conn)
    row = conn.execute(
        "SELECT id, name FROM shows WHERE name = ? COLLATE NOCASE",
        (show_name,),
    ).fetchone()
    if not row:
        print(json.dumps({"ok": False, "error": "show not found", "show": show_name, "seasons": []}))
        conn.close()
        return
    show_id = row["id"]
    episodes = conn.execute(
        """
        SELECT id, season, episode, title, path, poster_path
        FROM episodes
        WHERE show_id = ?
        ORDER BY sort_key COLLATE NOCASE
        """,
        (show_id,),
    ).fetchall()
    conn.close()

    flat = []
    seasons = {}
    for ep in episodes:
        item = {
            "id": ep["id"],
            "season": ep["season"],
            "episode": ep["episode"],
            "title": display_title(ep["title"]),
            "path": ep["path"],
            "poster_path": ep["poster_path"] or "",
            "poster": poster_url(ep["poster_path"]),
            "label": format_episode_label(ep["season"], ep["episode"], ep["title"]),
        }
        flat.append(item)
        season = ep["season"] if ep["season"] is not None else 0
        seasons.setdefault(season, []).append(item)

    season_list = []
    for season in sorted(seasons.keys()):
        season_list.append(
            {
                "season": season if season != 0 else None,
                "label": f"Season {season:02d}" if season else "Episodes",
                "episodes": seasons[season],
            }
        )

    print(
        json.dumps(
            {
                "ok": True,
                "show": row["name"],
                "showId": show_id,
                "episodes": flat,
                "seasons": season_list,
            }
        )
    )


def format_episode_label(season, episode, title):
    title = display_title(title) or title
    if season is not None and episode is not None:
        return f"S{season:02d}E{episode:02d} · {title}"
    return title


def play(kind: str, entry_id: str):
    if not entry_id.isdigit():
        print(json.dumps({"ok": False, "error": "invalid id"}))
        return
    conn = connect()
    init_db(conn)
    if kind == "film":
        row = conn.execute("SELECT path FROM films WHERE id = ?", (entry_id,)).fetchone()
    elif kind == "episode":
        row = conn.execute("SELECT path FROM episodes WHERE id = ?", (entry_id,)).fetchone()
    else:
        print(json.dumps({"ok": False, "error": "invalid kind"}))
        conn.close()
        return
    conn.close()
    if not row:
        print(json.dumps({"ok": False, "error": "not found"}))
        return
    path = row["path"]
    if not os.path.isfile(path):
        print(json.dumps({"ok": False, "error": "file missing", "path": path}))
        return
    subprocess.Popen(
        ["mpv", "--fs", "--really-quiet", path],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    print(json.dumps({"ok": True, "path": path}))


if cmd == "scan":
    scan()
elif cmd == "status":
    status()
elif cmd == "list-films":
    list_films()
elif cmd == "list-shows":
    list_shows()
elif cmd == "list-episodes":
    list_episodes(sys.argv[7])
elif cmd == "play":
    play(sys.argv[7], sys.argv[8])
else:
    print(json.dumps({"ok": False, "error": "unknown command"}), file=sys.stderr)
    raise SystemExit(1)
PY
}

cmd="${1:-}"
case "$cmd" in
scan)
    media_py scan "$DB_PATH" "$POSTER_DIR" "$FILMS_ROOT" "$TV_ROOT" "$VIDEO_EXTS"
    ;;
status)
    media_py status "$DB_PATH" "$POSTER_DIR" "$FILMS_ROOT" "$TV_ROOT" "$VIDEO_EXTS"
    ;;
list)
    sub="${2:-}"
    case "$sub" in
    films)
        media_py list-films "$DB_PATH" "$POSTER_DIR" "$FILMS_ROOT" "$TV_ROOT" "$VIDEO_EXTS"
        ;;
    shows)
        media_py list-shows "$DB_PATH" "$POSTER_DIR" "$FILMS_ROOT" "$TV_ROOT" "$VIDEO_EXTS"
        ;;
    episodes)
        show="${3:-}"
        [[ -n "$show" ]] || usage
        media_py list-episodes "$DB_PATH" "$POSTER_DIR" "$FILMS_ROOT" "$TV_ROOT" "$VIDEO_EXTS" "$show"
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
    media_py play "$DB_PATH" "$POSTER_DIR" "$FILMS_ROOT" "$TV_ROOT" "$VIDEO_EXTS" "$kind" "$entry_id"
    ;;
*)
    usage
    ;;
esac
