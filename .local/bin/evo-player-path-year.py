#!/usr/bin/env python3
"""Extract release year from file path/filename for evo-player."""

import os
import re
import sys

MIN_YEAR = 1985
MAX_YEAR = 2026


def valid_year(y: int) -> bool:
    return MIN_YEAR <= y <= MAX_YEAR


def valid_month(m: int) -> bool:
    return 1 <= m <= 12


def valid_day(d: int) -> bool:
    return 1 <= d <= 31


def valid_day_or_zero(d: int) -> bool:
    return 0 <= d <= 31


def yy_to_year(yy: int) -> int:
    return 2000 + yy if yy < 70 else 1900 + yy


def year_from_filename(stem: str) -> tuple[int, str]:
    m = re.search(r"(?:^|[-_])(\d{4})(\d{2})(\d{2})$", stem)
    if m:
        y, mo, d = int(m.group(1)), int(m.group(2)), int(m.group(3))
        if valid_year(y) and valid_month(mo) and valid_day(d):
            return y, "filename-yyyymmdd"

    m = re.search(r"(\d{2})[.-](\d{2})[.-](20\d{2})", stem)
    if m:
        y = int(m.group(3))
        mo, d = int(m.group(2)), int(m.group(1))
        if valid_year(y) and valid_month(mo) and valid_day(d):
            return y, "filename-ddmmyyyy"

    m = re.search(r"(\d{2})\.(\d{2})\.(\d{2})$", stem)
    if m:
        d, mo, yy = int(m.group(1)), int(m.group(2)), int(m.group(3))
        if valid_month(mo) and valid_day_or_zero(d):
            y = yy_to_year(yy)
            if valid_year(y):
                return y, "filename-ddmmyy"

    m = re.search(r"(?:^|[-_])(\d{2})[.-](\d{2})[.-](\d{2})(?:\D|$)", stem)
    if m:
        yy, mo, d = int(m.group(1)), int(m.group(2)), int(m.group(3))
        if valid_month(mo) and valid_day_or_zero(d):
            y = yy_to_year(yy)
            if valid_year(y):
                return y, "filename-yymmdd"

    m = re.search(r"(\d{2})(\d{2})(\d{4})$", stem)
    if m:
        d, mo, y = int(m.group(1)), int(m.group(2)), int(m.group(3))
        if valid_year(y) and valid_month(mo) and valid_day(d):
            return y, "filename-ddmmyyyy"

    return 0, ""


def path_year_authority(path: str) -> tuple[int, str]:
    stem = os.path.splitext(os.path.basename(path))[0]
    y, src = year_from_filename(stem)
    if y:
        return y, src

    parts = path.replace("\\", "/").split("/")

    for i, part in enumerate(parts):
        if part == "mixes" and i + 1 < len(parts):
            m = re.fullmatch(r"(19\d{2}|20\d{2})", parts[i + 1])
            if m:
                y = int(m.group(1))
                if valid_year(y):
                    return y, "mixes-folder"

    for part in parts:
        m = re.match(r"^(19\d{2}|20\d{2})_", part)
        if m:
            y = int(m.group(1))
            if valid_year(y):
                return y, "album-folder"
        m = re.search(r"(?:^|[-_])(19\d{2}|20\d{2})(?:\D|$)", part)
        if m:
            y = int(m.group(1))
            if valid_year(y):
                return y, "folder-year"

    return 0, ""


def resolve_path_year(path: str, music_root: str) -> int:
    root = music_root.rstrip(os.sep)
    if path.startswith(root):
        rel = path[len(root):].lstrip(os.sep).replace(os.sep, "/")
    else:
        rel = os.path.basename(path)
    y, _ = path_year_authority(rel)
    return y


def main() -> int:
    if len(sys.argv) >= 3 and sys.argv[1] == "--resolve":
        music_root = (
            sys.argv[3]
            if len(sys.argv) > 3
            else os.environ.get("MUSIC_ROOT", "/mnt/external/music")
        )
        y = resolve_path_year(sys.argv[2], music_root)
        if y:
            print(y)
        return 0
    print("usage: evo-player-path-year.py --resolve <path> [music_root]", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
