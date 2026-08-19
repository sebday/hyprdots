#!/usr/bin/env python3
"""Album art search for evo-player: iTunes, MusicBrainz/CAA, Discogs, Spotify."""

from concurrent.futures import ThreadPoolExecutor, as_completed
import json
import os
import re
import subprocess
import sys
import urllib.parse
import urllib.request


HTTP_TIMEOUT = 8
MAX_RESULTS = 8
PER_SOURCE = 4
USER_AGENT = "evo-player/1.0 (local music player)"


def ffprobe_tags(path: str) -> dict[str, str]:
    try:
        proc = subprocess.run(
            [
                "ffprobe", "-v", "quiet",
                "-show_entries", "format_tags=artist,album_artist,album,title",
                "-of", "json",
                path,
            ],
            capture_output=True,
            text=True,
            check=False,
            timeout=8,
        )
        data = json.loads(proc.stdout or "{}")
        tags = ((data.get("format") or {}).get("tags") or {})
        out = {}
        for key, value in tags.items():
            out[str(key).lower()] = str(value or "").strip()
        return out
    except Exception:
        return {}


def track_queries(path: str) -> list[str]:
    tags = ffprobe_tags(path)
    artist = tags.get("artist") or tags.get("album_artist") or ""
    album = tags.get("album") or ""
    title = tags.get("title") or os.path.splitext(os.path.basename(path))[0]
    out = []
    for q in (f"{artist} {album}".strip(), f"{artist} {title}".strip(), album.strip(), title.strip()):
        if q and q not in out:
            out.append(q)
    return out


def fetch_json(url: str, headers: dict | None = None) -> dict:
    hdrs = {"User-Agent": USER_AGENT}
    if headers:
        hdrs.update(headers)
    req = urllib.request.Request(url, headers=hdrs)
    with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as resp:
        return json.load(resp)


def search_itunes(query: str, limit: int = PER_SOURCE) -> list[dict]:
    term = urllib.parse.quote(query)
    url = f"https://itunes.apple.com/search?term={term}&entity=album&limit={limit}"
    try:
        data = fetch_json(url)
    except Exception:
        return []
    out = []
    for item in data.get("results", []):
        thumb = item.get("artworkUrl100") or ""
        art = thumb.replace("100x100bb", "600x600bb") if thumb else ""
        if not art:
            continue
        label = f"{item.get('artistName', '').strip()} — {item.get('collectionName', '').strip()}".strip(" —")
        out.append({"url": art, "thumb": art, "label": label, "source": "itunes"})
    return out


def search_caa(query: str, limit: int = PER_SOURCE) -> list[dict]:
    try:
        term = urllib.parse.quote(query)
        url = (
            f"https://musicbrainz.org/ws/2/release/?query={term}"
            f"&fmt=json&limit={limit}"
        )
        data = fetch_json(url)
    except Exception:
        return []
    out = []
    for rel in data.get("releases", []):
        mbid = rel.get("id")
        if not mbid:
            continue
        caa = rel.get("cover-art-archive") or {}
        if caa and not caa.get("front") and not caa.get("artwork"):
            continue
        title = rel.get("title") or ""
        artist = ""
        ac = rel.get("artist-credit") or []
        if ac:
            artist = (ac[0].get("name") or "").strip()
        label = f"{artist} — {title}".strip(" —") if artist else title
        thumb = f"https://coverartarchive.org/release/{mbid}/front-250"
        art = f"https://coverartarchive.org/release/{mbid}/front-500"
        out.append({"url": art, "thumb": thumb, "label": label, "source": "caa"})
        if len(out) >= limit:
            break
    return out


def search_discogs(query: str, token: str, limit: int = PER_SOURCE) -> list[dict]:
    if not token:
        return []
    try:
        term = urllib.parse.quote(query)
        url = f"https://api.discogs.com/database/search?q={term}&type=release&per_page={limit}"
        data = fetch_json(url, {
            "User-Agent": USER_AGENT,
            "Authorization": f"Discogs token={token}",
        })
    except Exception:
        return []
    out = []
    for item in data.get("results", []):
        thumb = item.get("thumb") or item.get("cover_image") or ""
        if not thumb:
            continue
        art = re.sub(r"/fit-in/\d+x\d+/", "/fit-in/600x600/", thumb)
        label = item.get("title") or query
        out.append({"url": art, "thumb": art, "label": label, "source": "discogs"})
    return out


def spotify_token(client_id: str, client_secret: str) -> str:
    import base64

    auth = base64.b64encode(f"{client_id}:{client_secret}".encode()).decode()
    req = urllib.request.Request(
        "https://accounts.spotify.com/api/token",
        data=b"grant_type=client_credentials",
        headers={
            "Authorization": f"Basic {auth}",
            "Content-Type": "application/x-www-form-urlencoded",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as resp:
        return json.load(resp).get("access_token") or ""


def search_spotify(query: str, token: str, limit: int = PER_SOURCE) -> list[dict]:
    if not token:
        return []
    try:
        term = urllib.parse.quote(query)
        url = f"https://api.spotify.com/v1/search?q={term}&type=album&limit={limit}"
        data = fetch_json(url, {"Authorization": f"Bearer {token}"})
    except Exception:
        return []
    out = []
    for item in (data.get("albums", {}).get("items") or []):
        images = item.get("images") or []
        if not images:
            continue
        art = images[0].get("url") or ""
        if not art:
            continue
        artists = ", ".join(a.get("name", "") for a in item.get("artists", []))
        title = item.get("name") or ""
        label = f"{artists} — {title}".strip(" —") if artists else title
        out.append({"url": art, "thumb": art, "label": label, "source": "spotify"})
    return out


def dedupe(results: list[dict], max_items: int = MAX_RESULTS) -> list[dict]:
    seen = set()
    out = []
    for row in results:
        key = row.get("url") or ""
        if not key or key in seen:
            continue
        seen.add(key)
        out.append(row)
        if len(out) >= max_items:
            break
    return out


def search_query(query: str, discogs_token: str, sp_token: str) -> list[dict]:
    merged: list[dict] = []
    with ThreadPoolExecutor(max_workers=4) as pool:
        futs = [
            pool.submit(search_itunes, query),
            pool.submit(search_caa, query),
            pool.submit(search_discogs, query, discogs_token),
            pool.submit(search_spotify, query, sp_token),
        ]
        for fut in as_completed(futs):
            try:
                merged.extend(fut.result())
            except Exception:
                continue
    return merged


def load_secrets() -> tuple[str, str, str]:
    secrets_path = os.environ.get(
        "EVOSHELL_SECRETS",
        os.path.expanduser("~/.local/share/evoshell/secrets.env"),
    )
    discogs_token = os.environ.get("DISCOGS_TOKEN", "")
    spotify_id = os.environ.get("SPOTIFY_CLIENT_ID", "")
    spotify_secret = os.environ.get("SPOTIFY_CLIENT_SECRET", "")
    if os.path.isfile(secrets_path):
        for line in open(secrets_path, encoding="utf-8"):
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, _, v = line.partition("=")
            k = k.strip()
            v = v.strip().strip('"').strip("'")
            if k == "DISCOGS_TOKEN" and not discogs_token:
                discogs_token = v
            elif k == "SPOTIFY_CLIENT_ID" and not spotify_id:
                spotify_id = v
            elif k == "SPOTIFY_CLIENT_SECRET" and not spotify_secret:
                spotify_secret = v
    return discogs_token, spotify_id, spotify_secret


def main() -> int:
    if len(sys.argv) < 2:
        return 1
    path = sys.argv[1]
    json_mode = "--json" in sys.argv[2:]
    if not os.path.isfile(path):
        print("evo-player: not a file", file=sys.stderr)
        return 1

    discogs_token, spotify_id, spotify_secret = load_secrets()
    sp_token = ""
    if spotify_id and spotify_secret:
        try:
            sp_token = spotify_token(spotify_id, spotify_secret)
        except Exception:
            sp_token = ""

    queries = track_queries(path)
    primary = queries[0] if queries else os.path.basename(path)
    merged = search_query(primary, discogs_token, sp_token)
    results = dedupe(merged)
    if len(results) < 4:
        for q in queries[1:3]:
            merged.extend(search_query(q, discogs_token, sp_token))
            results = dedupe(merged)
            if len(results) >= 4:
                break

    payload = {"query": primary, "results": results}
    if json_mode:
        print(json.dumps(payload, ensure_ascii=False))
    else:
        for row in results:
            print(f"{row.get('label', '')}\t{row.get('url', '')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
