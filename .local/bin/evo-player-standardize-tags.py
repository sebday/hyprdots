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


AUDIO_EXTS = {".mp3", ".mp2", ".m4a"}
VINYL_SKIP_LABELS = {"_misc"}
TAG_FIELDS = ("title", "artist", "genre", "year", "album", "publisher", "catalognumber")


def _first_text(frame) -> str:
    if frame is None:
        return ""
    text = getattr(frame, "text", None)
    if text:
        return str(text[0]).strip()
    return str(frame).strip()


def read_tags(path: Path) -> dict:
    title = artist = genre = album = year = publisher = catalognumber = ""
    ext = path.suffix.lower()
    try:
        if ext in {".mp3", ".mp2"}:
            from mutagen.id3 import ID3, ID3NoHeaderError
            try:
                id3 = ID3(path)
            except ID3NoHeaderError:
                id3 = None
            if id3 is not None:
                title = _first_text(id3.get("TIT2"))
                artist = _first_text(id3.get("TPE1")) or _first_text(id3.get("TPE2"))
                genre = _first_text(id3.get("TCON"))
                album = _first_text(id3.get("TALB"))
                publisher = _first_text(id3.get("TPUB"))
                year = _first_text(id3.get("TDRC")) or _first_text(id3.get("TYER"))
                for frame in id3.getall("TXXX"):
                    desc = str(getattr(frame, "desc", "")).lower()
                    if desc in {"catalognumber", "catalog", "catalogue"}:
                        catalognumber = _first_text(frame)
                        break
        elif ext == ".m4a":
            from mutagen.mp4 import MP4
            mp4 = MP4(path)
            tags = mp4.tags or {}

            def mp4_pick(key: str) -> str:
                val = tags.get(key)
                if not val:
                    return ""
                item = val[0]
                if isinstance(item, bytes):
                    return item.decode("utf-8", "replace").strip()
                return str(item).strip()

            title = mp4_pick("\xa9nam")
            artist = mp4_pick("\xa9ART")
            genre = mp4_pick("\xa9gen")
            album = mp4_pick("\xa9alb")
            year = mp4_pick("\xa9day")
            publisher = mp4_pick("----:com.apple.iTunes:LABEL")
            catalognumber = mp4_pick("----:com.apple.iTunes:CATALOGNUMBER")
    except OSError:
        pass
    m = re.search(r"(\d{4})", year or "")
    year = m.group(1) if m else ""
    if not title:
        title = path.stem
    return {
        "title": title,
        "artist": artist,
        "genre": genre,
        "album": album,
        "year": year,
        "publisher": publisher,
        "catalognumber": catalognumber,
    }


def vinyl_label_name(folder: str) -> str:
    return folder.replace("_", " ").replace("-", " ").strip().title()


def vinyl_catalog_from_folder(release_folder: str) -> str | None:
    def is_year_token(tok: str) -> bool:
        return bool(re.fullmatch(r"(19|20)\d{2}", tok))

    def is_cat_token(tok: str) -> bool:
        tok = tok.upper()
        if not re.fullmatch(r"[A-Z0-9]{3,16}", tok):
            return False
        if is_year_token(tok):
            return False
        if not re.search(r"[A-Z]", tok) or not re.search(r"\d", tok):
            return False
        return True

    def score(tok: str) -> int:
        return len(re.findall(r"\d", tok)) * 10 + len(tok)

    first = release_folder.split("-", 1)[0]
    if is_cat_token(first):
        return first.upper()

    candidates: list[str] = []
    if "_" in first:
        tail = first.rsplit("_", 1)[-1]
        if is_cat_token(tail) and len(re.findall(r"\d", tail)) >= 2:
            candidates.append(tail.upper())
    for tok in re.split(r"[-_]", release_folder):
        if is_cat_token(tok):
            candidates.append(tok.upper())
    if not candidates:
        return None
    return max(candidates, key=score)


def vinyl_from_path(path: Path) -> dict | None:
    try:
        rel = path.resolve().relative_to(MUSIC_ROOT.resolve())
    except ValueError:
        return None
    parts = rel.parts
    if len(parts) < 4:
        return None
    if parts[1] != "vinyl":
        return None
    if parts[0] not in GENRE_FOLDER_TO_TAG:
        return None
    label_folder = parts[2]
    if label_folder in VINYL_SKIP_LABELS:
        return None
    label = vinyl_label_name(label_folder)
    if not label:
        return None
    out = {"publisher": label}
    cat = vinyl_catalog_from_folder(parts[3])
    if cat:
        out["album"] = cat
        out["catalognumber"] = cat
    return out


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
    vinyl = vinyl_from_path(path)
    if vinyl:
        out.update(vinyl)
    return out


def write_tags(path: Path, targets: dict) -> bool:
    ext = path.suffix.lower()
    try:
        if ext in {".mp3", ".mp2"}:
            from mutagen.id3 import ID3, ID3NoHeaderError, TALB, TCON, TDRC, TIT2, TPE1, TPUB, TXXX
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
            if "album" in targets:
                id3["TALB"] = TALB(encoding=3, text=targets["album"])
            if "publisher" in targets:
                id3["TPUB"] = TPUB(encoding=3, text=targets["publisher"])
            if "catalognumber" in targets:
                keep_txxx = [
                    frame for frame in id3.getall("TXXX")
                    if str(getattr(frame, "desc", "")).lower() != "catalognumber"
                ]
                id3.delall("TXXX")
                for frame in keep_txxx:
                    id3.add(frame)
                id3.add(TXXX(encoding=3, desc="CATALOGNUMBER", text=targets["catalognumber"]))
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
            if "album" in targets:
                mp4["\xa9alb"] = [targets["album"]]
            if "publisher" in targets:
                mp4["----:com.apple.iTunes:LABEL"] = [targets["publisher"].encode("utf-8")]
            if "catalognumber" in targets:
                mp4["----:com.apple.iTunes:CATALOGNUMBER"] = [targets["catalognumber"].encode("utf-8")]
            mp4.save()
            return True
    except Exception as exc:
        print(f"evo-player: tag write failed {path}: {exc}", file=sys.stderr)
        return False
    return False


def iter_audio_files(path: Path):
    if path.is_file():
        if path.suffix.lower() in AUDIO_EXTS:
            yield path
        return
    if path.is_dir():
        for child in sorted(path.rglob("*")):
            if child.is_file() and child.suffix.lower() in AUDIO_EXTS:
                yield child


def standardize_file(path: Path) -> dict:
    before = read_tags(path)
    targets = target_tags(path, before)
    changes = {}
    for key in TAG_FIELDS:
        new = targets.get(key, "")
        old = before.get(key, "")
        if new and new != old:
            changes[key] = {"from": old, "to": new}

    if not changes:
        return {"path": str(path), "changed": False}

    if not write_tags(path, {key: diff["to"] for key, diff in changes.items()}):
        return {"path": str(path), "changed": False, "error": True}

    return {"path": str(path), "changed": True, "changes": changes}


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: evo-player-standardize-tags.py <audio-file-or-dir>", file=sys.stderr)
        return 1
    path = Path(sys.argv[1])
    if not path.exists():
        return 1

    if path.is_dir():
        changed_n = 0
        failed = 0
        for audio in iter_audio_files(path):
            result = standardize_file(audio)
            if result.get("error"):
                failed += 1
                continue
            if result.get("changed"):
                changed_n += 1
        print(json.dumps({"root": str(path), "changed_files": changed_n, "failed": failed}))
        return 1 if failed else 0

    audio = next(iter_audio_files(path), None)
    if audio is None:
        return 1
    result = standardize_file(audio)
    if result.get("error"):
        return 1
    print(json.dumps(result, ensure_ascii=False))
    if result.get("changed"):
        for key, diff in result["changes"].items():
            print(
                f"tag {key}: {diff['from'] or '∅'} -> {diff['to']}",
                file=sys.stderr,
            )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
