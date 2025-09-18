#!/usr/bin/env python3
import shopify
import os
import sys
from datetime import datetime, timedelta
from dotenv import load_dotenv
import json
import argparse
from zoneinfo import ZoneInfo
import re

# The script is executed from the project root via `cd ... && ...`
project_root = os.getcwd()
if project_root not in sys.path:
    sys.path.append(project_root)
import db

def load_github_colors():
    """
    Loads GitHub contribution colors from the current theme's waybar.css file.
    """
    waybar_css_path = os.path.expanduser("~/.themes/current/waybar.css")
    default_colors = ["#ebedf0", "#9be9a8", "#40c463", "#30a14e", "#216e39"]
    
    if not os.path.exists(waybar_css_path):
        return default_colors

    colors = {}
    try:
        with open(waybar_css_path, 'r') as f:
            for line in f:
                if "@define-color github-" in line:
                    match = re.search(r'@define-color\s+github-(\d)\s+([^;]+);', line)
                    if match:
                        index, color = match.groups()
                        colors[int(index)] = color.strip()
        
        if len(colors) == 5:
            return [colors[i] for i in sorted(colors.keys())]
        else:
            return default_colors
    except Exception:
        return default_colors

STORES_CONFIG = [
    {'prefix': 'ZK', 'display_name': ' ', 'db_name': 'ZK' },
    {'prefix': 'DIY', 'display_name': ' ', 'db_name': 'DIY' },
    {'prefix': 'TGS', 'display_name': ' ', 'db_name': 'TGS' }
]

def initialize_environment(store_prefix):
    """
    Loads environment variables and sets up Shopify session for a specific store.
    """
    dotenv_path = os.path.join(project_root, '.env')
    load_dotenv(dotenv_path=dotenv_path)
    
    shop_url = os.getenv(f"{store_prefix}_SHOP_URL")
    admin_api_key = os.getenv(f"{store_prefix}_ADMIN_API_KEY") 
    api_version = os.getenv("API_VERSION")

    if not all([shop_url, admin_api_key, api_version]):
        return None, None

    try:
        session = shopify.Session(shop_url, api_version, admin_api_key)
        shopify.ShopifyResource.activate_session(session)
        shop = shopify.Shop.current()
        return session, shop.iana_timezone
    except Exception as e:
        return None, None

def is_cancelled(order):
    return hasattr(order, 'cancelled_at') and order.cancelled_at is not None

def is_fully_refunded(order):
    if hasattr(order, 'financial_status'):
        return order.financial_status == 'refunded'
    return False

def should_count_in_revenue(order):
    if is_cancelled(order) or is_fully_refunded(order):
        return False
    valid_statuses = ['paid', 'partially_paid', 'partially_refunded']
    if hasattr(order, 'financial_status'):
        return order.financial_status in valid_statuses
    return False

def get_order_total(order):
    price_attr = order.current_total_price if hasattr(order, 'current_total_price') and order.current_total_price is not None else order.total_price
    return float(price_attr if price_attr is not None else 0.0)

def fetch_orders_for_day_api(day_date, session, store_name_param, store_tz):
    start_date = datetime.combine(day_date, datetime.min.time(), tzinfo=store_tz)
    end_date = datetime.combine(day_date, datetime.max.time(), tzinfo=store_tz)
    api_orders = []
    if not session: return api_orders 
    try:
        page_orders = shopify.Order.find(
            limit=250,
            created_at_min=start_date.isoformat(),
            created_at_max=end_date.isoformat(),
            status='any',
            fields='id,total_price,created_at,line_items,cancelled_at,financial_status,current_total_price,refunds,name'
        )
        for o in page_orders: api_orders.append(o)
    except Exception as e:
        import sys
        print(f"Waybar Critical Error: API fetch failed for {store_name_param} on {day_date}. Details: {e}", file=sys.stderr)
    return api_orders

def get_daily_sales_total_for_waybar(day_date, session, store_name_db, store_tz):
    orders_for_day = []
    refresh_hours = 0.25 if day_date == datetime.now(store_tz).date() else 4

    if session and db.should_refresh_data(store_name_db, day_date, refresh_interval_hours=refresh_hours):
        api_orders = fetch_orders_for_day_api(day_date, session, store_name_db, store_tz)
        for order in api_orders:
            db.store_order(store_name_db, order)
        orders_for_day = api_orders
    elif session:
        db_orders_raw = db.get_orders_for_day(store_name_db, day_date)
        for db_order_data in db_orders_raw:
            try:
                order_dict = json.loads(db_order_data['order_data'])
                order = shopify.Order(order_dict, prefix_options=session.site)
                orders_for_day.append(order)
            except Exception as e:
                continue
    else:
        stats = db.get_daily_stats(store_name_db, day_date)
        if stats and stats['revenue'] is not None and stats['order_count'] is not None:
            return float(stats['revenue']), int(stats['order_count'])
        return 0.0, 0

    valid_orders = [o for o in orders_for_day if should_count_in_revenue(o)]
    daily_total_revenue = sum(get_order_total(order) for order in valid_orders)
    order_count = len(valid_orders)
    db.update_daily_stats(store_name_db, day_date, daily_total_revenue, order_count)
    return daily_total_revenue, order_count

def generate_sales_chart(daily_sales, colors):
    bars = [' ', '▂', '▃', '▄', '▅', '▆', '▇', '█'] 

    max_sale = max(s if s is not None else 0 for s in daily_sales) if daily_sales else 0 
    chart_str = ""
    
    if max_sale == 0:
        bar_char = ' '
        color = colors[0]
        return f"<span foreground='{color}'>{bar_char * 14}</span>"

    for sale_val in daily_sales:
        sale = float(sale_val if sale_val is not None else 0.0) 
        if sale < 0: sale = 0

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

def main():
    parser = argparse.ArgumentParser(description='Fetch Shopify sales data for a specific store.')
    parser.add_argument('store_prefix', type=str, nargs='?', help='The prefix of the store to fetch data for (e.g., ZK, DIY).')
    parser.add_argument('--print-todays-orders', action='store_true', help="Print today's orders from the database.")
    args = parser.parse_args()

    db.initialize_database()

    colors = load_github_colors()

    today = datetime.now().date()

    output_text = ""

    stores_to_process = STORES_CONFIG
    if args.store_prefix:
        stores_to_process = [s for s in STORES_CONFIG if s['prefix'] == args.store_prefix]
        if not stores_to_process:
            output_text = f"Error: Store {args.store_prefix} not found"
            print(json.dumps({"text": output_text}))
            return

    if not stores_to_process:
        print(json.dumps({"text": "No store configured"}))
        return

    for store_config in stores_to_process:
        store_prefix = store_config['prefix']
        display_name = store_config['display_name']
        db_name = store_config['db_name']
        
        active_session, store_timezone_str = initialize_environment(store_prefix)
        if not active_session:
            output_text = f"{display_name}: Auth Error"
            break

        store_tz = ZoneInfo(store_timezone_str)
        today = datetime.now(store_tz).date()
        today_sales_figure, today_order_count = get_daily_sales_total_for_waybar(today, active_session, db_name, store_tz)

        chart_daily_sales = []
        for i in range(13, -1, -1):
            day_to_fetch = today - timedelta(days=i)
            sales_for_chart_day, _ = get_daily_sales_total_for_waybar(day_to_fetch, active_session, db_name, store_tz)
            chart_daily_sales.append(sales_for_chart_day)

        sales_chart = generate_sales_chart(chart_daily_sales, colors)
        today_sales_val = int(today_sales_figure if today_sales_figure is not None else 0)

        output_text = f"{display_name} £{today_sales_val:,} | {today_order_count} {sales_chart}"
        
        if today_order_count == 0:
            output_text = f"<span foreground='{colors[0]}'>{output_text}</span>"

        break
    
    print(json.dumps({"text": output_text}))

if __name__ == "__main__":
    main() 