#!/usr/bin/env python3
"""
Waybar JSON output for daily Shopify sales + 14-day sparkline.
Reads merged KPI rows from ecommerce-data SQLite (fact_kpi_daily).
Currency label for today uses raw_shopify_orders_daily when present (fact has no currency).

Paths (first match wins):
  ECOMMERCE_SQLITE_DIR     — use this directory only (no fetch).
  Otherwise                — rsync/scp from ECOMMERCE_SQLITE_REMOTE if set, else
                             built-in DEFAULT_REMOTE, into ~/.cache/ecommerce-waybar-sqlite,
                             then read from that cache.

Pure local / no network: set ECOMMERCE_SQLITE_DIR to ~/projects/ecommerce-data/data.
Disable remote only: export ECOMMERCE_SQLITE_REMOTE= (empty string) — then falls
back to ~/projects/ecommerce-data/data without fetching.
"""
import argparse
import json
import os
import re
import sqlite3
import subprocess
import sys
from datetime import datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

DEFAULT_SQLITE_DIR = Path.home() / "projects" / "ecommerce-data" / "data"
DEFAULT_CACHE_DIR = Path.home() / ".cache" / "ecommerce-waybar-sqlite"
DEFAULT_REMOTE = "seb@192.168.2.200:/home/seb/projects/ecommerce-data/data"
DEFAULT_TZ = "Europe/London"


def load_github_colors():
    """Load GitHub-style heatmap colors from the current theme's waybar.css."""
    waybar_css_path = os.path.expanduser("~/.themes/current/waybar.css")
    default_colors = ["#ebedf0", "#9be9a8", "#40c463", "#30a14e", "#216e39"]

    if not os.path.exists(waybar_css_path):
        return default_colors

    colors = {}
    try:
        with open(waybar_css_path, "r", encoding="utf-8") as f:
            for line in f:
                if "@define-color github-" in line:
                    match = re.search(r"@define-color\s+github-(\d)\s+([^;]+);", line)
                    if match:
                        index, color = match.groups()
                        colors[int(index)] = color.strip()

        if len(colors) == 5:
            return [colors[i] for i in sorted(colors.keys())]
        return default_colors
    except OSError:
        return default_colors


# prefix = Waybar argv (DIY, TGS, …); site_key = ecommerce-data sqlite basename (diy.sqlite)
STORES_CONFIG = [
    {"prefix": "ZK", "display_name": "Z ", "site_key": "zk"},
    {"prefix": "DIY", "display_name": "D ", "site_key": "diy"},
    {"prefix": "TGS", "display_name": "T ", "site_key": "tgs"},
]


def _remote_spec() -> str | None:
    if "ECOMMERCE_SQLITE_REMOTE" in os.environ:
        v = os.environ["ECOMMERCE_SQLITE_REMOTE"].strip()
        return v or None
    return DEFAULT_REMOTE.strip() or None


def sync_remote_sqlite(remote_spec: str) -> Path:
    """Pull *.sqlite into local cache; on failure leave existing cache for stale reads."""
    cache = Path(
        os.environ.get("ECOMMERCE_SQLITE_CACHE_DIR", str(DEFAULT_CACHE_DIR))
    ).expanduser()
    cache.mkdir(parents=True, exist_ok=True)
    src = remote_spec.rstrip("/") + "/"
    ssh = "ssh -o BatchMode=yes -o ConnectTimeout=8"
    try:
        r = subprocess.run(
            [
                "rsync",
                "-az",
                "--include=*.sqlite",
                "--exclude=*",
                "--timeout=25",
                "-e",
                ssh,
                src,
                str(cache) + "/",
            ],
            capture_output=True,
            timeout=40,
        )
        if r.returncode == 0:
            return cache
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

    m = re.match(r"^([^@]+)@([^:]+):(.+)$", remote_spec)
    if m:
        user, host, dirpath = m.group(1), m.group(2), m.group(3).rstrip("/")
        base = f"{user}@{host}:{dirpath}"
        for site in STORES_CONFIG:
            key = site["site_key"]
            try:
                subprocess.run(
                    [
                        "scp",
                        "-q",
                        "-o",
                        "BatchMode=yes",
                        "-o",
                        "ConnectTimeout=8",
                        f"{base}/{key}.sqlite",
                        str(cache / f"{key}.sqlite"),
                    ],
                    capture_output=True,
                    timeout=35,
                    check=False,
                )
            except (FileNotFoundError, subprocess.TimeoutExpired):
                break
    return cache


def sqlite_base() -> Path:
    explicit = os.environ.get("ECOMMERCE_SQLITE_DIR", "").strip()
    if explicit:
        return Path(explicit).expanduser().resolve()
    remote = _remote_spec()
    if remote:
        return sync_remote_sqlite(remote).resolve()
    return DEFAULT_SQLITE_DIR.resolve()


def site_sqlite_path(site_key: str, base: Path) -> Path:
    safe = re.sub(r"[^a-z0-9_-]", "_", site_key.strip().lower())
    return base / f"{safe}.sqlite"


def get_day_stats(conn: sqlite3.Connection, dt_iso: str) -> tuple[float, int]:
    row = conn.execute(
        """
        SELECT revenue, orders
        FROM fact_kpi_daily
        WHERE dt = ?
        """,
        (dt_iso,),
    ).fetchone()
    if not row:
        return 0.0, 0
    rev, n = row[0], row[1]
    return float(rev or 0), int(n or 0)


def generate_sales_chart(daily_sales, colors):
    bars = [" ", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

    max_sale = max(s if s is not None else 0 for s in daily_sales) if daily_sales else 0
    chart_str = ""

    if max_sale == 0:
        bar_char = " "
        color = colors[0]
        return f"<span foreground='{color}'>{bar_char * 14}</span>"

    for sale_val in daily_sales:
        sale = float(sale_val if sale_val is not None else 0.0)
        if sale < 0:
            sale = 0

        bar_level = 0
        if sale > 0:
            bar_level = int((sale / max_sale) * (len(bars) - 1))
            if bar_level == 0 and sale > 0:
                bar_level = 1
        bar_level = min(bar_level, len(bars) - 1)
        bar_char = bars[bar_level]

        color_level = 0
        if sale > 0:
            percentage = sale / max_sale
            if percentage > 0.75:
                color_level = 4
            elif percentage > 0.5:
                color_level = 3
            elif percentage > 0.25:
                color_level = 2
            else:
                color_level = 1

        color = colors[color_level]
        chart_str += f"<span foreground='{color}'>{bar_char}</span>"

    return chart_str


def currency_symbol(code: str | None) -> str:
    if not code:
        return "£"
    c = code.strip().upper()
    if c == "GBP":
        return "£"
    if c == "USD":
        return "$"
    if c == "EUR":
        return "€"
    return f"{c} "


def main():
    parser = argparse.ArgumentParser(
        description="Read daily sales from ecommerce-data fact_kpi_daily for Waybar."
    )
    parser.add_argument(
        "store_prefix",
        nargs="?",
        help="Store prefix (e.g. DIY, TGS) — must match STORES_CONFIG",
    )
    args = parser.parse_args()

    tz_name = os.environ.get("WAYBAR_SHOPIFY_TZ", DEFAULT_TZ).strip() or DEFAULT_TZ
    try:
        tz = ZoneInfo(tz_name)
    except Exception:
        tz = ZoneInfo(DEFAULT_TZ)

    colors = load_github_colors()
    today = datetime.now(tz).date()
    base = sqlite_base()

    stores_to_process = STORES_CONFIG
    if args.store_prefix:
        stores_to_process = [s for s in STORES_CONFIG if s["prefix"] == args.store_prefix]
        if not stores_to_process:
            print(json.dumps({"text": f"Error: Store {args.store_prefix} not found"}))
            return

    if not stores_to_process:
        print(json.dumps({"text": "No store configured"}))
        return

    for store_config in stores_to_process:
        display_name = store_config["display_name"]
        site_key = store_config["site_key"]
        db_path = site_sqlite_path(site_key, base)

        if not db_path.is_file():
            print(
                json.dumps(
                    {
                        "text": f"{display_name}: no db ({db_path})",
                    }
                )
            )
            break

        try:
            conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
        except sqlite3.Error as e:
            print(json.dumps({"text": f"{display_name}: db error"}))
            print(f"waybar-shopify: {db_path}: {e}", file=sys.stderr)
            break

        try:
            today_s = today.isoformat()
            today_sales_figure, today_order_count = get_day_stats(conn, today_s)

            cur_row = conn.execute(
                "SELECT currency_code FROM raw_shopify_orders_daily WHERE dt = ?",
                (today_s,),
            ).fetchone()
            sym = currency_symbol(cur_row[0] if cur_row else None)

            chart_daily_sales = []
            for i in range(13, -1, -1):
                d = (today - timedelta(days=i)).isoformat()
                rev, _n = get_day_stats(conn, d)
                chart_daily_sales.append(rev)

            sales_chart = generate_sales_chart(chart_daily_sales, colors)
            today_sales_val = int(today_sales_figure if today_sales_figure is not None else 0)

            output_text = f"{display_name}{sym}{today_sales_val:,} | {today_order_count} {sales_chart}"
            if today_order_count == 0:
                output_text = f"<span foreground='{colors[1]}'>{output_text}</span>"

            print(json.dumps({"text": output_text}))
        finally:
            conn.close()
        break


if __name__ == "__main__":
    main()
