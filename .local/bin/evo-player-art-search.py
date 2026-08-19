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
                "-print_format", "json",
                "-show_format",
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


def pick_tag(tags: dict[str, str], *keys: str) -> str:
    lookup = {str(k).lower(): str(v).strip() for k, v in tags.items() if v}
    for key in keys:
        val = lookup.get(key.lower())
        if val:
            return val
    return ""


def looks_like_catno(value: str) -> bool:
    s = (value or "").strip()
    if len(s) < 3 or len(s) > 24 or " " in s:
        return False
    return bool(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._/-]*\d[A-Za-z0-9._/-]*", s))


def track_meta(path: str) -> dict[str, str]:
    tags = ffprobe_tags(path)
    year_raw = pick_tag(tags, "date", "year", "originaldate", "original_year", "tyer")
    year_match = re.search(r"(19\d{2}|20\d{2})", year_raw or "")
    album = pick_tag(tags, "album")
    catno = pick_tag(tags, "catalognumber", "catalog", "catalogue", "catno")
    if not catno and looks_like_catno(album):
        catno = album
    return {
        "artist": pick_tag(tags, "artist", "album_artist", "albumartist"),
        "album": album,
        "title": pick_tag(tags, "title") or os.path.splitext(os.path.basename(path))[0],
        "catno": catno,
        "year": year_match.group(1) if year_match else "",
    }


def fallback_queries(meta: dict[str, str]) -> list[str]:
    artist = meta.get("artist") or ""
    album = meta.get("album") or ""
    title = meta.get("title") or ""
    catno = meta.get("catno") or ""
    out = []
    for q in (
        catno.strip(),
        f"{artist} {album}".strip(),
        f"{artist} {title}".strip(),
        album.strip(),
        title.strip(),
    ):
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


def discogs_headers(token: str = "") -> dict[str, str]:
    headers = {"User-Agent": USER_AGENT}
    if token:
        headers["Authorization"] = f"Discogs token={token}"
    return headers


def norm_catno(value: str) -> str:
    return re.sub(r"[^a-z0-9]", "", (value or "").lower())


def discogs_release_art(resource_url: str, token: str = "") -> tuple[str, str]:
    if not resource_url:
        return "", ""
    try:
        data = fetch_json(resource_url, discogs_headers(token))
    except Exception:
        return "", ""
    images = data.get("images") or []
    primary = next((img for img in images if img.get("type") == "primary"), None)
    img = primary or (images[0] if images else None)
    if not img:
        return "", ""
    art = str(img.get("uri") or "")
    thumb = str(img.get("uri150") or art)
    return art, thumb


def search_discogs(
    query: str = "",
    token: str = "",
    limit: int = PER_SOURCE,
    catno: str = "",
    year: str = "",
) -> list[dict]:
    params = {"type": "release", "per_page": str(max(limit, 8))}
    if catno:
        params["catno"] = catno
    if year:
        params["year"] = year
    if query:
        params["q"] = query
    if "q" not in params and "catno" not in params:
        return []
    try:
        url = "https://api.discogs.com/database/search?" + urllib.parse.urlencode(params)
        data = fetch_json(url, discogs_headers(token))
    except Exception:
        return []
    raw = []
    want = norm_catno(catno)
    for item in data.get("results", []):
        raw.append({
            "title": item.get("title") or catno or query,
            "year": str(item.get("year") or ""),
            "catno": str(item.get("catno") or ""),
            "thumb": item.get("thumb") or item.get("cover_image") or "",
            "resource_url": item.get("resource_url") or "",
        })
    if want:
        exact = [row for row in raw if norm_catno(row.get("catno") or "") == want]
        raw = exact or raw
    out = []
    for item in raw:
        thumb = item.get("thumb") or ""
        art = re.sub(r"/fit-in/\d+x\d+/", "/fit-in/600x600/", thumb) if thumb else ""
        if not art:
            art, thumb = discogs_release_art(item.get("resource_url") or "", token)
        if not art:
            continue
        out.append({
            "url": art,
            "thumb": thumb or art,
            "label": item.get("title") or catno or query,
            "source": "discogs",
            "year": item.get("year") or "",
            "catno": item.get("catno") or "",
        })
        if len(out) >= limit:
            break
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


def search_discogs_catalog(catno: str, token: str, year: str = "") -> list[dict]:
    hits = search_discogs(token=token, catno=catno, limit=PER_SOURCE)
    if not year or len(hits) <= 1:
        return hits
    narrowed = search_discogs(token=token, catno=catno, year=year, limit=PER_SOURCE)
    if narrowed:
        return narrowed
    year_hits = [row for row in hits if str(row.get("year") or "") == year]
    return year_hits or hits


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

    meta = track_meta(path)
    queries = fallback_queries(meta)
    primary = meta.get("catno") or (queries[0] if queries else os.path.basename(path))
    merged: list[dict] = []
    if meta.get("catno"):
        merged.extend(search_discogs_catalog(meta["catno"], discogs_token, meta.get("year") or ""))
    results = dedupe(merged)
    if len(results) < 4:
        for q in queries:
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
