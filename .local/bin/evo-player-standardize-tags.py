#!/usr/bin/env python3
"""Lookup, fix, and standardize audio tags for evo-player import."""

import importlib.util
import json
import os
import re
import sys
from pathlib import Path

EVOSHELL_BIN = Path(os.environ.get("EVOSHELL_BIN", Path.home() / ".local" / "bin"))
MUSIC_ROOT = Path(os.environ.get("MUSIC_ROOT", "/mnt/external/music"))
MIN_YEAR = 1985
MAX_YEAR = 2026

GENRE_FOLDER_TO_TAG = {
    "drum&bass": "Drum & Bass",
    "dubstep": "Dubstep",
    "grime": "Grime",
    "hiphop": "Hip-Hop",
    "house": "House",
}

KNOWN_YEARS = {
    "bailey_gq-metalheadz_history_sessions_phonox-05-04-24": 2024,
    "future_beats_radio_show_04-06-15": 2015,
    "future_beats_radio_show_04-04-13": 2013,
}

STEM_GENRE = [
    ("excision-darkside_dubstep", "dubstep"),
    ("future_beats_radio_show", "drum&bass"),
    ("ant_tc1_mc_visionobi", "drum&bass"),
    ("calibre-essential_mix", "drum&bass"),
    ("chase_status_boiler_room", "drum&bass"),
    ("hospital_records_with_lens", "drum&bass"),
    ("huscher-subtle_radio", "drum&bass"),
    ("jdizz_vol", "drum&bass"),
    ("cream_live_mixed_by_paul_oakenfold", "house"),
    ("bufera_beats_w_limmz", "grime"),
    ("boofy", "dubstep"),
    ("cluekid", "dubstep"),
    ("chokez", "dubstep"),
    ("damna", "dubstep"),
    ("benga", "dubstep"),
    ("skream", "dubstep"),
    ("hatcha", "dubstep"),
    ("kampah", "dubstep"),
    ("black teeth", "dubstep"),
    ("jook", "drum&bass"),
    ("nas", "hiphop"),
    ("kendrick", "hiphop"),
    ("hip hop", "hiphop"),
]


def load_path_year_module():
    script = EVOSHELL_BIN / "evo-player-path-year.py"
    spec = importlib.util.spec_from_file_location("evo_player_path_year", script)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_path_year = load_path_year_module()


def read_tags(path: Path) -> dict:
    import subprocess

    title = artist = genre = album = year = ""
    try:
        proc = subprocess.run(
            [
                "ffprobe", "-v", "quiet", "-print_format", "json",
                "-show_format", str(path),
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        if proc.returncode == 0 and proc.stdout.strip():
            tags = json.loads(proc.stdout).get("format", {}).get("tags", {}) or {}

            def pick(*keys: str) -> str:
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
            raw_year = pick("date", "year", "originaldate", "original_year", "tyer")
            m = re.search(r"(\d{4})", raw_year or "")
            year = m.group(1) if m else ""
    except (json.JSONDecodeError, OSError):
        pass
    if not title:
        title = path.stem
    return {
        "title": title,
        "artist": artist,
        "genre": genre,
        "album": album,
        "year": year,
    }


def valid_year(y: int) -> bool:
    return MIN_YEAR <= y <= MAX_YEAR


def year_from_parentheses(stem: str) -> int | None:
    m = re.search(r"\((19\d{2}|20\d{2})\)", stem)
    if m:
        y = int(m.group(1))
        if valid_year(y):
            return y
    return None


def resolve_year(path: Path, tags: dict) -> int | None:
    name = path.name
    stem = path.stem
    if name in KNOWN_YEARS:
        return KNOWN_YEARS[name]
    if stem in KNOWN_YEARS:
        return KNOWN_YEARS[stem]

    y = _path_year.resolve_path_year(str(path), str(MUSIC_ROOT))
    if y and valid_year(y):
        return y

    y = year_from_parentheses(stem)
    if y:
        return y

    tag_y = tags.get("year", "")
    if tag_y.isdigit() and valid_year(int(tag_y)):
        return int(tag_y)
    return None


def genre_tag_to_folder(tag: str) -> str | None:
    lower = tag.lower().strip()
    if not lower:
        return None
    if any(x in lower for x in ("drum", "dnb", "jungle")):
        return "drum&bass"
    if "dub" in lower:
        return "dubstep"
    if "house" in lower:
        return "house"
    if "grime" in lower:
        return "grime"
    if "hiphop" in lower or ("hip" in lower and "hop" in lower):
        return "hiphop"
    if lower == "liquid":
        return "drum&bass"
    if lower in ("electronic", "electronica"):
        return None
    return None


def resolve_genre_folder(path: Path, tags: dict) -> str | None:
    stem_lower = path.stem.lower()
    for pattern, folder in STEM_GENRE:
        if pattern in stem_lower:
            return folder

    for field in (tags.get("genre", ""), tags.get("artist", ""), tags.get("title", "")):
        folder = genre_tag_to_folder(field)
        if folder:
            return folder

    combined = f"{tags.get('artist', '')} {tags.get('title', '')}"
    return genre_tag_to_folder(combined)


def parse_filename_artist_title(stem: str) -> tuple[str, str]:
    if " - " in stem:
        artist, title = stem.split(" - ", 1)
        return artist.strip(), title.strip()
    return "", stem.strip()


def target_tags(path: Path, tags: dict) -> dict:
    stem = path.stem
    year = resolve_year(path, tags)
    folder = resolve_genre_folder(path, tags)
    genre_tag = GENRE_FOLDER_TO_TAG.get(folder, "") if folder else ""

    artist = tags.get("artist", "").strip()
    title = tags.get("title", "").strip()
    fn_artist, fn_title = parse_filename_artist_title(stem)

    if fn_artist:
        if not artist or artist.lower() == fn_title.lower():
            artist = fn_artist
        if not title or title == stem:
            title = fn_title
    if not artist and fn_artist:
        artist = fn_artist
    if not title:
        title = fn_title or stem

    out = {"title": title, "artist": artist}
    if genre_tag:
        out["genre"] = genre_tag
    if year:
        out["year"] = str(year)
    return out


def write_tags(path: Path, targets: dict) -> bool:
    ext = path.suffix.lower()
    try:
        if ext in {".mp3", ".mp2"}:
            from mutagen.id3 import ID3, ID3NoHeaderError, TDRC, TCON, TIT2, TPE1
            try:
                id3 = ID3(path)
            except ID3NoHeaderError:
                id3 = ID3()
            if "title" in targets:
                id3["TIT2"] = TIT2(encoding=3, text=targets["title"])
            if "artist" in targets:
                id3["TPE1"] = TPE1(encoding=3, text=targets["artist"])
            if "genre" in targets:
                id3["TCON"] = TCON(encoding=3, text=targets["genre"])
            if "year" in targets:
                id3["TDRC"] = TDRC(encoding=3, text=targets["year"])
            id3.save(path, v2_version=4)
            return True
        if ext == ".m4a":
            from mutagen.mp4 import MP4
            mp4 = MP4(path)
            if mp4.tags is None:
                mp4.add_tags()
            if "title" in targets:
                mp4["\xa9nam"] = [targets["title"]]
            if "artist" in targets:
                mp4["\xa9ART"] = [targets["artist"]]
            if "genre" in targets:
                mp4["\xa9gen"] = [targets["genre"]]
            if "year" in targets:
                mp4["\xa9day"] = [targets["year"]]
            mp4.save()
            return True
    except Exception as exc:
        print(f"evo-player: tag write failed {path}: {exc}", file=sys.stderr)
        return False
    return False


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: evo-player-standardize-tags.py <audio-file>", file=sys.stderr)
        return 1
    path = Path(sys.argv[1])
    if not path.is_file():
        return 1

    before = read_tags(path)
    targets = target_tags(path, before)
    changes = {}
    for key in ("title", "artist", "genre", "year"):
        new = targets.get(key, "")
        old = before.get(key, "")
        if new and new != old:
            changes[key] = {"from": old, "to": new}

    if not changes:
        print(json.dumps({"path": str(path), "changed": False}))
        return 0

    merged = dict(before)
    for key, val in targets.items():
        if val:
            merged[key] = val

    if not write_tags(path, merged):
        return 1

    print(
        json.dumps(
            {"path": str(path), "changed": True, "changes": changes},
            ensure_ascii=False,
        )
    )
    for key, diff in changes.items():
        print(
            f"tag {key}: {diff['from'] or '∅'} -> {diff['to']}",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
