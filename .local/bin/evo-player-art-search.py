#!/usr/bin/env python3
"""Album art search for evo-player: iTunes, MusicBrainz/CAA, Discogs, Spotify."""

import json
import os
import re
import subprocess
import sys
import urllib.parse
import urllib.request


def ffprobe_meta(path: str, field: str) -> str:
    try:
        proc = subprocess.run(
            [
                "ffprobe", "-v", "quiet",
                "-show_entries", f"format_tags={field}",
                "-of", "default=nw=1:nk=1",
                path,
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        return (proc.stdout or "").strip()
    except Exception:
        return ""


def track_queries(path: str) -> list[str]:
    artist = ffprobe_meta(path, "artist") or ffprobe_meta(path, "album_artist")
    album = ffprobe_meta(path, "album")
    title = ffprobe_meta(path, "title") or os.path.splitext(os.path.basename(path))[0]
    out = []
    for q in (f"{artist} {album}".strip(), f"{artist} {title}".strip(), album.strip(), title.strip()):
        if q and q not in out:
            out.append(q)
    return out


def fetch_json(url: str, headers: dict | None = None) -> dict:
    req = urllib.request.Request(url, headers=headers or {"User-Agent": "evo-player/1.0"})
    with urllib.request.urlopen(req, timeout=20) as resp:
        return json.load(resp)


def search_itunes(query: str, limit: int = 6) -> list[dict]:
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


def search_caa(query: str, limit: int = 6) -> list[dict]:
  try:
      term = urllib.parse.quote(query)
      url = f"https://musicbrainz.org/ws/2/release/?query={term}&fmt=json&limit={limit}"
      data = fetch_json(url, {"User-Agent": "evo-player/1.0 (local music player)"})
  except Exception:
      return []
  out = []
  for rel in data.get("releases", []):
      mbid = rel.get("id")
      if not mbid:
          continue
      title = rel.get("title") or ""
      artist = ""
      ac = rel.get("artist-credit") or []
      if ac:
          artist = (ac[0].get("name") or "").strip()
      label = f"{artist} — {title}".strip(" —") if artist else title
      try:
          caa = fetch_json(
              f"https://coverartarchive.org/release/{mbid}",
              {"User-Agent": "evo-player/1.0"},
          )
      except Exception:
          continue
      images = caa.get("images") or []
      front = next((img for img in images if img.get("front")), images[0] if images else None)
      if not front:
          continue
      art = front.get("image") or front.get("thumbnails", {}).get("large") or ""
      if not art:
          continue
      out.append({"url": art, "thumb": art, "label": label, "source": "caa"})
  return out


def search_discogs(query: str, token: str, limit: int = 6) -> list[dict]:
    if not token:
        return []
    try:
        term = urllib.parse.quote(query)
        url = f"https://api.discogs.com/database/search?q={term}&type=release&per_page={limit}"
        data = fetch_json(url, {
            "User-Agent": "evo-player/1.0",
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
    with urllib.request.urlopen(req, timeout=20) as resp:
        return json.load(resp).get("access_token") or ""


def search_spotify(query: str, client_id: str, client_secret: str, limit: int = 6) -> list[dict]:
    if not client_id or not client_secret:
        return []
    try:
        token = spotify_token(client_id, client_secret)
        if not token:
            return []
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


def dedupe(results: list[dict], max_items: int = 16) -> list[dict]:
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


def main() -> int:
    if len(sys.argv) < 2:
        return 1
    path = sys.argv[1]
    json_mode = "--json" in sys.argv[2:]
    if not os.path.isfile(path):
        print("evo-player: not a file", file=sys.stderr)
        return 1

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

    queries = track_queries(path)
    primary = queries[0] if queries else os.path.basename(path)
    merged: list[dict] = []
    for q in queries[:3]:
        merged.extend(search_itunes(q))
        merged.extend(search_caa(q))
        merged.extend(search_discogs(q, discogs_token))
        merged.extend(search_spotify(q, spotify_id, spotify_secret))
    results = dedupe(merged)
    payload = {"query": primary, "results": results}
    if json_mode:
        print(json.dumps(payload, ensure_ascii=False))
    else:
        for row in results:
            print(f"{row.get('label', '')}\t{row.get('url', '')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
