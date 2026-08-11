#!/bin/bash
# Evo bar JSON output for daily Shopify sales + 14-day sparkline.
# Reads merged KPI rows from ecommerce-data SQLite (fact_kpi_daily).
# Currency label for today uses raw_shopify_orders_daily when present.
#
# Environment:
#   ECOMMERCE_SQLITE_DIR    — local *.sqlite directory (default ~/projects/ecommerce-data/data)
#   ECOMMERCE_SQLITE_REMOTE — rsync source host:path; empty disables remote sync
#   EVO_SHOPIFY_TZ       — timezone for "today" (default Europe/London)

set -euo pipefail

source "${HOME}/.local/bin/evo-bar-common.sh"

DEFAULT_SQLITE_DIR="$HOME/projects/ecommerce-data/data"
DEFAULT_REMOTE="seb@192.168.2.200:/home/seb/projects/ecommerce-data/data"
DEFAULT_TZ="Europe/London"

# prefix|display_name|site_key
STORES=(
    "ZK|Z |zk"
    "DIY|D |diy"
    "TGS|T |tgs"
)

BARS=(" " "▂" "▃" "▄" "▅" "▆" "▇" "█")

json_text() {
    jq -cn --arg text "$1" '{text: $text}'
}

json_shopify() {
    jq -cn \
        --arg text "$1" \
        --arg label "$2" \
        --argjson bars "$3" \
        --arg store "$4" \
        --arg symbol "$5" \
        '{text: $text, label: $label, bars: $bars, store: $store, symbol: $symbol}'
}

remote_spec() {
    if [[ -n "${ECOMMERCE_SQLITE_REMOTE+x}" ]]; then
        local v="${ECOMMERCE_SQLITE_REMOTE// /}"
        if [[ -n "$v" ]]; then printf '%s' "$v"; fi
        return
    fi
    printf '%s' "$DEFAULT_REMOTE"
}

sqlite_data_dir() {
    local raw="${ECOMMERCE_SQLITE_DIR:-}"
    raw="${raw#"${raw%%[![:space:]]*}"}"
    raw="${raw%"${raw##*[![:space:]]}"}"
    if [[ -n "$raw" ]]; then
        readlink -f "${raw/#\~/$HOME}"
    else
        readlink -f "$DEFAULT_SQLITE_DIR"
    fi
}

sync_remote_sqlite() {
    local remote_spec=$1 dest=$2
    mkdir -p "$dest"
    local src="${remote_spec%/}/"
    local ssh_opts="ssh -o BatchMode=yes -o ConnectTimeout=8"

    if timeout 40 rsync -az \
        --include='*.sqlite' --exclude='*' --timeout=25 \
        -e "$ssh_opts" "$src" "${dest}/" 2>/dev/null; then
        return 0
    fi

    if [[ "$remote_spec" =~ ^([^@]+)@([^:]+):(.+)$ ]]; then
        local user="${BASH_REMATCH[1]}" host="${BASH_REMATCH[2]}" dirpath="${BASH_REMATCH[3]%/}"
        local base="${user}@${host}:${dirpath}"
        local entry prefix _display site_key
        for entry in "${STORES[@]}"; do
            IFS='|' read -r prefix _display site_key <<< "$entry"
            timeout 35 scp -q \
                -o BatchMode=yes -o ConnectTimeout=8 \
                "${base}/${site_key}.sqlite" "${dest}/${site_key}.sqlite" 2>/dev/null || break
        done
    fi
}

sqlite_base() {
    local dest remote
    dest=$(sqlite_data_dir)
    remote=$(remote_spec)
    if [[ -n "$remote" ]]; then
        sync_remote_sqlite "$remote" "$dest" >/dev/null
    fi
    printf '%s' "$dest"
}

site_sqlite_path() {
    local site_key=$1 base=$2
    local safe
    safe=$(printf '%s' "$site_key" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/_/g')
    printf '%s/%s.sqlite' "$base" "$safe"
}

has_google_spend_column() {
    local db=$1
    sqlite3 -readonly "$db" "PRAGMA table_info(fact_kpi_daily)" | cut -d'|' -f2 | grep -qx 'google_spend' || return 1
}

get_day_stats() {
    local db=$1 dt=$2 spend_col=$3
    local row rev n spend cos
    row=$(sqlite3 -readonly -separator '|' "$db" \
        "SELECT revenue, orders, ${spend_col} FROM fact_kpi_daily WHERE dt = '${dt}';" 2>/dev/null || true)

    if [[ -z "$row" ]]; then
        printf '0|0|'
        return
    fi

    IFS='|' read -r rev n spend <<< "$row"
    rev=${rev:-0}
    n=${n:-0}

    cos=""
    if [[ -n "$spend" && "$spend" != "NULL" ]]; then
        cos=$(awk -v s="$spend" -v r="$rev" 'BEGIN {
            if (r > 0) printf "%.10f", s / r
        }')
    fi

    printf '%s|%s|%s' "$rev" "$n" "$cos"
}

currency_symbol() {
    local code="${1:-}"
    code=$(printf '%s' "$code" | tr '[:lower:]' '[:upper:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    case "$code" in
        "" | GBP) printf '£' ;;
        USD)      printf '$' ;;
        EUR)      printf '€' ;;
        *)        printf '%s ' "$code" ;;
    esac
}

format_int_commas() {
    awk -v n="$1" 'BEGIN {
        s = sprintf("%d", n + 0)
        len = length(s)
        out = ""
        for (i = 1; i <= len; i++) {
            c = substr(s, len - i + 1, 1)
            if (i > 1 && (i - 1) % 3 == 0) out = "," out
            out = c out
        }
        print out
    }'
}

generate_sales_chart() {
    local -a sales=("$@")
    local chart="" i sale max_sale bar_level color_level bar_char color pct

    max_sale=$(printf '%s\n' "${sales[@]}" | awk '
        { v = ($1 == "" ? 0 : $1); if (v < 0) v = 0; if (v > max) max = v }
        END { print max + 0 }
    ')

    if awk -v m="$max_sale" 'BEGIN { exit (m == 0) ? 0 : 1 }'; then
        printf "<span foreground='%s'>%s</span>" "${GITHUB_COLORS[0]}" "$(printf '%.0s ' {1..14})"
        return
    fi

    for sale in "${sales[@]}"; do
        read -r bar_level color_level bar_char <<< "$(awk -v sale="$sale" -v max="$max_sale" 'BEGIN {
            s = (sale == "" ? 0 : sale + 0)
            if (s < 0) s = 0

            bar_level = 0
            if (s > 0) {
                bar_level = int((s / max) * 7)
                if (bar_level == 0) bar_level = 1
            }
            if (bar_level > 7) bar_level = 7

            color_level = 0
            if (s > 0) {
                pct = s / max
                if (pct > 0.75) color_level = 4
                else if (pct > 0.5) color_level = 3
                else if (pct > 0.25) color_level = 2
                else color_level = 1
            }
            bars[0] = " "
            bars[1] = "▂"
            bars[2] = "▃"
            bars[3] = "▄"
            bars[4] = "▅"
            bars[5] = "▆"
            bars[6] = "▇"
            bars[7] = "█"

            print bar_level, color_level, bars[bar_level]
        }')"
        color="${GITHUB_COLORS[$color_level]}"
        chart+="<span foreground='${color}'>${bar_char}</span>"
    done

    printf '%s' "$chart"
}

build_sparkline_json() {
    local -a rows=("$@")
    local max_sale row day_iso sale bar_level color_level color

    max_sale=$(printf '%s\n' "${rows[@]}" | awk -F'|' '
        { v = ($2 == "" ? 0 : $2 + 0); if (v < 0) v = 0; if (v > max) max = v }
        END { print max + 0 }
    ')

    if awk -v m="$max_sale" 'BEGIN { exit (m == 0) ? 0 : 1 }'; then
        printf '[]'
        return
    fi

    local lines=""
    for row in "${rows[@]}"; do
        IFS='|' read -r day_iso sale <<< "$row"
        read -r bar_level color_level <<< "$(awk -v sale="$sale" -v max="$max_sale" 'BEGIN {
            s = (sale == "" ? 0 : sale + 0)
            if (s < 0) s = 0

            bar_level = 0
            if (s > 0) {
                bar_level = int((s / max) * 7)
                if (bar_level == 0) bar_level = 1
            }
            if (bar_level > 7) bar_level = 7

            color_level = 0
            if (s > 0) {
                pct = s / max
                if (pct > 0.75) color_level = 4
                else if (pct > 0.5) color_level = 3
                else if (pct > 0.25) color_level = 2
                else color_level = 1
            }

            print bar_level, color_level
        }')"
        color="${GITHUB_COLORS[$color_level]}"
        lines+="$(jq -cn --arg date "$day_iso" --argjson value "${sale:-0}" \
            --argjson level "$bar_level" --argjson colorLevel "$color_level" --arg color "$color" \
            '{date: $date, value: $value, level: $level, colorLevel: $colorLevel, color: $color}')"
        lines+=$'\n'
    done

    printf '%s' "$lines" | jq -s '.'
}

find_store() {
    local want_prefix=$1
    local entry prefix display site_key
    for entry in "${STORES[@]}"; do
        IFS='|' read -r prefix display site_key <<< "$entry"
        if [[ "$prefix" == "$want_prefix" ]]; then
            STORE_PREFIX=$prefix
            STORE_DISPLAY=$display
            STORE_SITE_KEY=$site_key
            return 0
        fi
    done
    return 1
}

main() {
    local store_prefix=${1:-}
    local tz_name="${EVO_SHOPIFY_TZ:-$DEFAULT_TZ}"
    tz_name="${tz_name// /}"
    [[ -z "$tz_name" ]] && tz_name="$DEFAULT_TZ"

    evo_bar_load_heatmap_colors

    local today_s i day_iso base db_path spend_col
    local rev orders cos sym sales_chart today_sales_val cos_str output_text
    local -a chart_sales=()
    local -a chart_days=()

    today_s=$(TZ="$tz_name" date +%Y-%m-%d)
    base=$(sqlite_base)

    if [[ -n "$store_prefix" ]]; then
        if ! find_store "$store_prefix"; then
            json_text "Error: Store ${store_prefix} not found"
            return 1
        fi
    else
        IFS='|' read -r STORE_PREFIX STORE_DISPLAY STORE_SITE_KEY <<< "${STORES[0]}"
    fi

    db_path=$(site_sqlite_path "$STORE_SITE_KEY" "$base")
    if [[ ! -f "$db_path" ]]; then
        json_text "${STORE_DISPLAY}: no db (${db_path})"
        return 1
    fi

    if ! sqlite3 -readonly "$db_path" "SELECT 1;" >/dev/null 2>&1; then
        echo "evo-bar-shopify: ${db_path}: db error" >&2
        json_text "${STORE_DISPLAY}: db error"
        return 1
    fi

    if has_google_spend_column "$db_path"; then
        spend_col="google_spend"
    else
        spend_col="NULL"
    fi

    IFS='|' read -r rev orders cos <<< "$(get_day_stats "$db_path" "$today_s" "$spend_col")"

    sym=$(currency_symbol "$(sqlite3 -readonly "$db_path" \
        "SELECT currency_code FROM raw_shopify_orders_daily WHERE dt = '${today_s}';" 2>/dev/null || true)")

    for i in $(seq 13 -1 0); do
        day_iso=$(TZ="$tz_name" date -d "${today_s} - ${i} days" +%Y-%m-%d)
        rev=$(get_day_stats "$db_path" "$day_iso" "$spend_col" | cut -d'|' -f1)
        chart_sales+=("$rev")
        chart_days+=("${day_iso}|${rev}")
    done

    sales_chart=$(generate_sales_chart "${chart_sales[@]}")
    sparkline_json=$(build_sparkline_json "${chart_days[@]}")
    today_sales_val=$(format_int_commas "$(awk -v r="$rev" 'BEGIN { print int(r + 0) }')")

    if [[ -n "$cos" ]]; then
        cos_str=$(awk -v c="$cos" 'BEGIN { printf "%.1f%%", c * 100 }')
    else
        cos_str="—"
    fi

    label_text="${STORE_DISPLAY}${sym}${today_sales_val} | ${orders} | ${cos_str}"
    output_text="${label_text} ${sales_chart}"

    json_shopify "$output_text" "$label_text" "$sparkline_json" "${STORE_DISPLAY}" "$sym"
}

main "$@"
