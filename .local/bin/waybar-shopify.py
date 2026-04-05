#!/usr/bin/env python3
"""
Waybar JSON output for daily Shopify sales + 14-day sparkline.
Reads merged KPI rows from ecommerce-data SQLite (fact_kpi_daily).
Currency label for today uses raw_shopify_orders_daily when present (fact has no currency).
"""
import argparse
import json
import os
import re
import sqlite3
import sys
from datetime import datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

DEFAULT_SQLITE_DIR = Path.home() / "projects" / "ecommerce-data" / "data"
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
_ICON = "\ue26b "  # nerd-fonts private use (same as previous waybar-shopify config)
STORES_CONFIG = [
    {"prefix": "ZK", "display_name": _ICON, "site_key": "zk"},
    {"prefix": "DIY", "display_name": _ICON, "site_key": "diy"},
    {"prefix": "TGS", "display_name": _ICON, "site_key": "tgs"},
]


def sqlite_dir() -> Path:
    raw = os.environ.get("ECOMMERCE_SQLITE_DIR", "").strip()
    if raw:
        return Path(raw).expanduser().resolve()
    return DEFAULT_SQLITE_DIR.resolve()


def site_sqlite_path(site_key: str) -> Path:
    safe = re.sub(r"[^a-z0-9_-]", "_", site_key.strip().lower())
    return sqlite_dir() / f"{safe}.sqlite"


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
        db_path = site_sqlite_path(site_key)

        if not db_path.is_file():
            print(
                json.dumps(
                    {
                        "text": f"{display_name}: no db ({db_path.name})",
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
