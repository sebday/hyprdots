#!/usr/bin/env -S python3 -u
"""Fetch film/show/episode artwork from the web; ffmpeg frame grab is episode fallback."""

from __future__ import annotations

import json
import os
import re
import sqlite3
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import fcntl
from contextlib import contextmanager
from pathlib import Path

STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "evo-shell"
DB_PATH = STATE_DIR / "media.db"
LOCK_PATH = STATE_DIR / "media-fetch-posters.lock"
POSTER_DIR = STATE_DIR / "media-posters"
POSTER_WIDTH = 342
SEARCH_DELAY_SEC = 1.25
USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
DB_BUSY_RETRIES = 20
DB_BUSY_DELAY_SEC = 0.75


@contextmanager
def run_lock():
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    handle = open(LOCK_PATH, "w")
    try:
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        handle.close()
        other_pid = LOCK_PATH.read_text(encoding="utf-8").strip() if LOCK_PATH.is_file() else ""
        msg = "evo-media-fetch-posters is already running"
        if other_pid:
            msg += f" (pid {other_pid})"
        msg += ". Wait for it to finish or stop it first."
        raise SystemExit(msg)
    handle.write(str(os.getpid()))
    handle.flush()
    try:
        yield
    finally:
        fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
        handle.close()
        LOCK_PATH.unlink(missing_ok=True)


@contextmanager
def db_conn():
    conn = sqlite3.connect(DB_PATH, timeout=120)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=120000")
    try:
        yield conn
    finally:
        conn.close()


def db_write(sql: str, params: tuple = ()) -> None:
    for attempt in range(DB_BUSY_RETRIES):
        try:
            with db_conn() as conn:
                conn.execute(sql, params)
                conn.commit()
            return
        except sqlite3.OperationalError as err:
            if "locked" not in str(err).lower() or attempt == DB_BUSY_RETRIES - 1:
                raise
            time.sleep(DB_BUSY_DELAY_SEC * (attempt + 1))


def slug(text: str) -> str:
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    return text.strip("-") or "item"


def poster_exists(path: str | None) -> bool:
    return bool(path and Path(path).is_file() and Path(path).stat().st_size > 0)


def http_json(url: str, referer: str = "") -> dict | list | None:
    headers = {"User-Agent": USER_AGENT}
    if referer:
        headers["Referer"] = referer
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=25) as resp:
            return json.loads(resp.read())
    except (urllib.error.URLError, urllib.error.HTTPError, json.JSONDecodeError, TimeoutError):
        return None


def search_images(query: str, limit: int = 12) -> list[dict]:
    time.sleep(SEARCH_DELAY_SEC)
    landing = (
        "https://duckduckgo.com/?"
        + urllib.parse.urlencode({"q": query, "iax": "images", "ia": "images"})
    )
    req = urllib.request.Request(landing, headers={"User-Agent": USER_AGENT})
    try:
        html = urllib.request.urlopen(req, timeout=25).read().decode("utf-8", "replace")
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError):
        return []

    match = re.search(r"vqd=([\d-]+)", html)
    if not match:
        return []

    params = urllib.parse.urlencode({"q": query, "vqd": match.group(1), "o": "json"})
    api_url = "https://duckduckgo.com/i.js?" + params
    for attempt in range(3):
        time.sleep(0.4 * (attempt + 1))
        data = http_json(api_url, referer="https://duckduckgo.com/")
        if isinstance(data, dict):
            results = data.get("results") or []
            return results[:limit]
        time.sleep(1.5 * (attempt + 1))
    return []


def unwrap_image_url(url: str) -> str:
    if "url=" not in url:
        return url
    parsed = urllib.parse.urlparse(url)
    query = urllib.parse.parse_qs(parsed.query)
    inner = query.get("url", [""])[0]
    return urllib.parse.unquote(inner) if inner else url


def score_image_result(result: dict, *, kind: str) -> float:
    url = str(result.get("image") or "")
    title = str(result.get("title") or "").lower()
    width = int(result.get("width") or 0)
    height = int(result.get("height") or 0)
    if not url:
        return -1.0

    score = 0.0
    if "image.tmdb.org" in url:
        score += 80
    if "mzstatic.com" in url:
        score += 60
    if "media-amazon.com" in url:
        score += 55
    if "simkl." in url or "pogd.es" in url or "pogdesign.co.uk" in url:
        score += 50
    if "wikipedia.org" in url or "wikimedia.org" in url:
        score += 45
    if kind == "episode":
        if "episode" in title or "still" in title or "screencap" in title:
            score += 35
        if re.search(r"s\d{1,2}e\d{1,2}", title):
            score += 30
        if "pilot" in title:
            score += 10
        if "poster" in title and "episode" not in title:
            score -= 30
        if "season poster" in title or "series poster" in title:
            score -= 40
    else:
        if "poster" in title:
            score += 35
        if "movie poster" in title or "tv poster" in title or "series poster" in title:
            score += 25
        if kind == "show" and ("tv series" in title or "season" in title):
            score += 10
        if kind == "film" and "movie" in title:
            score += 10
    if "logo" in title or "icon" in title or "avatar" in title:
        score -= 50
    if "wallpaper" in title or "banner" in title:
        score -= 25
    if kind != "episode" and ("behind the scenes" in title or "still" in title):
        score -= 15

    if width > 0 and height > 0:
        ratio = width / height
        if kind == "episode":
            if 1.25 <= ratio <= 2.1:
                score += 30
            elif 0.58 <= ratio <= 0.78:
                score -= 10
        else:
            if 0.58 <= ratio <= 0.78:
                score += 30
            elif ratio > 1.2:
                score -= 20
        score += min(width, height) / 80.0

    if url.lower().endswith((".svg", ".gif")):
        score -= 40
    return score


def pick_image_url(results: list[dict], *, kind: str) -> str:
    ranked = sorted(
        ((score_image_result(item, kind=kind), unwrap_image_url(str(item.get("image") or ""))) for item in results),
        reverse=True,
    )
    for score, url in ranked:
        if score > 0 and url:
            return url
    return ""


def itunes_artwork(term: str, media: str) -> str:
    params = urllib.parse.urlencode({"term": term, "media": media, "limit": 8})
    data = http_json(f"https://itunes.apple.com/search?{params}")
    if not isinstance(data, dict):
        return ""
    for item in data.get("results") or []:
        url = item.get("artworkUrl100") or item.get("artworkUrl60") or ""
        if not url:
            continue
        return re.sub(r"/\d+x\d+bb\.jpg$", "/600x600bb.jpg", url)
    return ""


def build_search_queries(title: str, year: int | None, *, kind: str) -> list[str]:
    clean = re.sub(r"\s+", " ", title).strip()
    if kind == "show":
        return [
            f'"{clean}" TV series poster',
            f"{clean} TV show poster",
            f"{clean} series poster",
        ]
    if year:
        return [
            f'"{clean}" {year} movie poster',
            f"{clean} {year} film poster",
            f"{clean} {year} poster",
        ]
    return [
        f'"{clean}" movie poster',
        f"{clean} film poster",
        f"{clean} poster",
    ]


def build_episode_search_queries(
    show_name: str, season: int | None, episode: int | None, title: str
) -> list[str]:
    show = re.sub(r"\s+", " ", show_name).strip()
    ep_title = re.sub(r"\s+", " ", title).strip()
    queries: list[str] = []
    if season is not None and episode is not None:
        queries.append(f"{show} S{season:02d}E{episode:02d}")
        queries.append(f'"{show}" season {season} episode {episode} still')
    if ep_title:
        queries.append(f'"{show}" {ep_title} still')
        queries.append(f"{show} {ep_title} episode still")
    return queries


def find_poster_url(title: str, year: int | None, *, kind: str) -> str:
    for query in build_search_queries(title, year, kind=kind):
        results = search_images(query)
        url = pick_image_url(results, kind=kind)
        if url:
            return url

    fallback_term = f"{title} {year}" if year and kind == "film" else title
    media = "tvShow" if kind == "show" else "movie"
    return itunes_artwork(fallback_term, media) if kind != "episode" else ""


def find_episode_poster_url(
    show_name: str, season: int | None, episode: int | None, title: str
) -> str:
    for query in build_episode_search_queries(show_name, season, episode, title):
        results = search_images(query)
        url = pick_image_url(results, kind="episode")
        if url:
            return url
    return ""


def image_magic(data: bytes) -> bool:
    if data.startswith(b"\xff\xd8\xff"):
        return True
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return True
    if data.startswith(b"RIFF") and b"WEBP" in data[:16]:
        return True
    return False


def download_bytes(url: str) -> bytes | None:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": USER_AGENT,
            "Referer": "https://duckduckgo.com/",
            "Accept": "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=40) as resp:
            data = resp.read()
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError):
        return None
    if len(data) < 4000 or not image_magic(data):
        return None
    return data


def normalize_poster(src: Path, dest: Path) -> bool:
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(".tmp.jpg")
    cmd = [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-i",
        str(src),
        "-vf",
        f"scale={POSTER_WIDTH}:-2",
        "-q:v",
        "4",
        str(tmp),
    ]
    try:
        subprocess.run(cmd, check=True, stderr=subprocess.DEVNULL)
    except (subprocess.CalledProcessError, OSError):
        tmp.unlink(missing_ok=True)
        return False
    if not tmp.is_file() or tmp.stat().st_size == 0:
        tmp.unlink(missing_ok=True)
        return False
    tmp.replace(dest)
    return True


def save_poster_from_url(url: str, dest: Path) -> bool:
    data = download_bytes(url)
    if not data:
        return False
    dest.parent.mkdir(parents=True, exist_ok=True)
    raw = dest.with_suffix(".raw")
    raw.write_bytes(data)
    ok = normalize_poster(raw, dest)
    raw.unlink(missing_ok=True)
    return ok


def video_duration(path: str) -> float | None:
    try:
        out = subprocess.check_output(
            [
                "ffprobe",
                "-v",
                "error",
                "-show_entries",
                "format=duration",
                "-of",
                "default=noprint_wrappers=1:nokey=1",
                path,
            ],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
        value = float(out)
        return value if value > 0 else None
    except (subprocess.CalledProcessError, ValueError, OSError):
        return None


def pick_seek_seconds(path: str) -> str:
    duration = video_duration(path)
    if duration is None:
        return "300"
    target = min(max(duration * 0.10, 120.0), max(duration - 30.0, 120.0))
    return f"{target:.3f}"


def extract_episode_poster(video_path: str, dest: Path) -> bool:
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(".tmp.jpg")
    seek = pick_seek_seconds(video_path)
    cmd = [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-ss",
        seek,
        "-i",
        video_path,
        "-frames:v",
        "1",
        "-vf",
        f"scale={POSTER_WIDTH}:-2",
        "-q:v",
        "4",
        str(tmp),
    ]
    try:
        subprocess.run(cmd, check=True, stderr=subprocess.DEVNULL)
    except (subprocess.CalledProcessError, OSError):
        tmp.unlink(missing_ok=True)
        return False
    if not tmp.is_file() or tmp.stat().st_size == 0:
        tmp.unlink(missing_ok=True)
        return False
    tmp.replace(dest)
    return True


def build_film_posters(force: bool) -> tuple[int, int]:
    with db_conn() as conn:
        rows = conn.execute(
            "SELECT id, title, year, poster_path FROM films ORDER BY sort_title"
        ).fetchall()
    ok = 0
    skipped = 0
    for film_id, title, year, poster_path in rows:
        dest = POSTER_DIR / "films" / f"{film_id}-{slug(title)}.jpg"
        if not force and poster_exists(poster_path):
            skipped += 1
            continue
        url = find_poster_url(title, year, kind="film")
        if not url:
            print(f"no poster found: {title}", file=sys.stderr)
            continue
        if not save_poster_from_url(url, dest):
            print(f"download failed: {title}", file=sys.stderr)
            continue
        db_write("UPDATE films SET poster_path = ? WHERE id = ?", (str(dest), film_id))
        ok += 1
        print(f"film: {title}", flush=True)
    return ok, skipped


def build_show_posters(force: bool) -> tuple[int, int]:
    with db_conn() as conn:
        rows = conn.execute("SELECT id, name, poster_path FROM shows ORDER BY name").fetchall()
    ok = 0
    skipped = 0
    for show_id, name, poster_path in rows:
        dest = POSTER_DIR / "shows" / f"{show_id}-{slug(name)}.jpg"
        if not force and poster_exists(poster_path):
            skipped += 1
            continue
        url = find_poster_url(name, None, kind="show")
        if not url:
            print(f"no poster found: {name}", file=sys.stderr)
            continue
        if not save_poster_from_url(url, dest):
            print(f"download failed: {name}", file=sys.stderr)
            continue
        db_write("UPDATE shows SET poster_path = ? WHERE id = ?", (str(dest), show_id))
        ok += 1
        print(f"show: {name}", flush=True)
    return ok, skipped


def build_episode_posters(force: bool) -> tuple[int, int, int]:
    with db_conn() as conn:
        rows = conn.execute(
            """
            SELECT e.id, e.season, e.episode, e.title, e.path, e.poster_path, s.name
            FROM episodes e
            JOIN shows s ON s.id = e.show_id
            ORDER BY s.name COLLATE NOCASE, e.sort_key COLLATE NOCASE
            """
        ).fetchall()
    ok = 0
    skipped = 0
    fallback = 0
    for ep_id, season, episode, title, path, poster_path, show_name in rows:
        dest = POSTER_DIR / "episodes" / f"{ep_id}-{slug(show_name)}-{slug(title)}.jpg"
        if not force and poster_exists(poster_path):
            skipped += 1
            continue

        url = find_episode_poster_url(show_name, season, episode, title)
        if url and save_poster_from_url(url, dest):
            db_write("UPDATE episodes SET poster_path = ? WHERE id = ?", (str(dest), ep_id))
            ok += 1
            if ok % 25 == 0:
                print(f"episodes: {ok} online...", flush=True)
            continue

        if not path or not Path(path).is_file():
            print(f"missing file: {show_name} / {title}", file=sys.stderr)
            continue
        if not extract_episode_poster(path, dest):
            print(f"no artwork: {show_name} / {title}", file=sys.stderr)
            continue
        db_write("UPDATE episodes SET poster_path = ? WHERE id = ?", (str(dest), ep_id))
        ok += 1
        fallback += 1
        if ok % 25 == 0:
            print(f"episodes: {ok} ({fallback} fallback)...", flush=True)
    if fallback:
        print(f"episodes: {fallback} used local frame grab fallback", file=sys.stderr)
    return ok, skipped, fallback


def main() -> int:
    args = set(sys.argv[1:])
    force = "--force" in args
    films_only = "--films-only" in args
    shows_only = "--shows-only" in args
    episodes_only = "--episodes-only" in args
    fetch_episodes = "--episodes" in args or episodes_only
    skip_episodes = "--no-episodes" in args

    if episodes_only:
        fetch_films = fetch_shows = False
        fetch_episodes = True
    elif films_only:
        fetch_films, fetch_shows, fetch_episodes = True, False, False
    elif shows_only:
        fetch_films, fetch_shows, fetch_episodes = False, True, False
    else:
        fetch_films = True
        fetch_shows = True
        fetch_episodes = not skip_episodes

    if not DB_PATH.is_file():
        print(f"missing database: {DB_PATH} (run evo-media.sh scan first)", file=sys.stderr)
        return 1

    with run_lock():
        films_ok = films_skip = shows_ok = shows_skip = episodes_ok = episodes_skip = episodes_fallback = 0

        if fetch_films:
            films_ok, films_skip = build_film_posters(force)
        if fetch_shows:
            shows_ok, shows_skip = build_show_posters(force)
        if fetch_episodes:
            episodes_ok, episodes_skip, episodes_fallback = build_episode_posters(force)
    print(
        json.dumps(
            {
                "ok": True,
                "filmsBuilt": films_ok,
                "filmsSkipped": films_skip,
                "showsBuilt": shows_ok,
                "showsSkipped": shows_skip,
                "episodesBuilt": episodes_ok,
                "episodesSkipped": episodes_skip,
                "episodesFallback": episodes_fallback,
            }
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
