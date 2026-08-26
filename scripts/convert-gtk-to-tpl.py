#!/usr/bin/env python3
"""One-time: evoshell gtk.css → Omarchy gtk-4.0-gtk.css.tpl with {{ tokens }}."""

import re
import sys
from pathlib import Path

# Catppuccin / evoshell hex → Omarchy colors.toml token (case-insensitive)
HEX_MAP = {
    "1e1e2e": "{{ background }}",
    "181825": "{{ dark_background }}",
    "313244": "{{ lighter_background }}",
    "292c3c": "{{ lighter_background }}",
    "4a4b5a": "{{ lighter_background }}",
    "232634": "{{ lighter_background }}",
    "2b2b3a": "{{ lighter_background }}",
    "484856": "{{ muted }}",
    "393484": "{{ muted }}",
    "5e5c64": "{{ muted }}",
    "eff1f5": "{{ bright_foreground }}",
    "cdd6f4": "{{ foreground }}",
    "e6e9ef": "{{ bright_foreground }}",
    "89b4fa": "{{ blue }}",
    "1e66f5": "{{ blue }}",
    "1c71d8": "{{ blue }}",
    "74c7ec": "{{ accent }}",
    "94e2d5": "{{ cyan }}",
    "0db9d7": "{{ bright_cyan }}",
    "cba6f7": "{{ magenta }}",
    "bb9af7": "{{ bright_magenta }}",
    "ce8cd7": "{{ magenta }}",
    "eb5ec3": "{{ magenta }}",
    "ef4e9b": "{{ magenta }}",
    "6d53e0": "{{ magenta }}",
    "a6e3a1": "{{ green }}",
    "40a02b": "{{ green }}",
    "2ec27e": "{{ green }}",
    "b9f27c": "{{ bright_green }}",
    "fab387": "{{ orange }}",
    "df8e1d": "{{ yellow }}",
    "f9e2af": "{{ yellow }}",
    "f9e2a7": "{{ yellow }}",
    "e0af68": "{{ yellow }}",
    "ff9e64": "{{ bright_yellow }}",
    "f77466": "{{ orange }}",
    "f38ba8": "{{ red }}",
    "f7768e": "{{ red }}",
    "d20f39": "{{ bright_red }}",
    "ff7a93": "{{ bright_red }}",
}


def color_mix(token: str, alpha: float) -> str:
    pct = round(alpha * 100)
    if pct <= 0:
        return "transparent"
    if pct >= 100:
        return token
    return f"color-mix(in srgb, {token} {pct}%, transparent)"


def replace_rgba(text: str) -> str:
    # Foreground family (eff1f5 / 239,241,245)
    text = re.sub(
        r"rgba?\(\s*239\s*,\s*241\s*,\s*245\s*,\s*([0-9.]+)\s*\)",
        lambda m: color_mix("{{ bright_foreground }}", float(m.group(1))),
        text,
        flags=re.I,
    )
    # Background family (1e1e2e / 30,30,46)
    text = re.sub(
        r"rgba?\(\s*30\s*,\s*30\s*,\s*46\s*,\s*([0-9.]+)\s*\)",
        lambda m: color_mix("{{ background }}", float(m.group(1))),
        text,
        flags=re.I,
    )
    # Blue accent (89b4fa / 137,180,250)
    text = re.sub(
        r"rgba?\(\s*137\s*,\s*180\s*,\s*250\s*,\s*([0-9.]+)\s*\)",
        lambda m: color_mix("{{ blue }}", float(m.group(1))),
        text,
        flags=re.I,
    )
    return text


def replace_hex(text: str) -> str:
    def sub_hex(match: re.Match) -> str:
        hex_digits = match.group(1).lower()
        if hex_digits in HEX_MAP:
            return HEX_MAP[hex_digits]
        return match.group(0)

    return re.sub(r"#([0-9a-fA-F]{6})\b", sub_hex, text)


def convert(content: str) -> str:
    content = replace_rgba(content)
    content = replace_hex(content)
    return content


def main() -> None:
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} <input.css> <output.tpl>", file=sys.stderr)
        sys.exit(1)

    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    out = convert(src.read_text())
    dst.write_text(out)
    remaining = sorted(set(re.findall(r"#([0-9a-fA-F]{6})", out, re.I)))
    if remaining:
        print(f"warning: {len(remaining)} hex literals remain in {dst}", file=sys.stderr)
        for h in remaining[:15]:
            print(f"  #{h}", file=sys.stderr)


if __name__ == "__main__":
    main()
