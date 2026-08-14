#!/usr/bin/env bash
# Shared network helpers for evoshell bar + popup.

INTERNET_PROBE="${INTERNET_PROBE:-1.1.1.1}"

active_iface() {
    ip route get "$INTERNET_PROBE" 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }'
}

ping_latency_ms() {
    local host="$1"
    LC_ALL=C ping -n -c 1 -W 1 "$host" 2>/dev/null | awk -F'time[=<]' '/time[=<]/ { split($2, parts, " "); print parts[1]; exit }'
}

format_rate() {
    local bytes_per_sec="$1"
    awk -v n="$bytes_per_sec" 'BEGIN {
        if (n < 0 || n != n) n = 0
        if (n < 1024) printf "%.0f B/s", n
        else if (n < 1048576) printf "%.1f KB/s", n / 1024
        else if (n < 1073741824) printf "%.1f MB/s", n / 1048576
        else printf "%.2f GB/s", n / 1073741824
    }'
}

format_ping() {
    local ms="$1"
    local has="${2:-1}"
    if [[ "$has" == "0" ]]; then
        printf '%s' "--"
        return
    fi
    if [[ -z "$ms" ]]; then
        printf '%s' "Timeout"
        return
    fi
    awk -v v="$ms" 'BEGIN {
        if (v < 0 || v != v) { print "Timeout"; exit }
        if (v > 0 && v < 10) printf "%.1f ms", v
        else printf "%.0f ms", v
    }'
}

format_link_speed() {
    local mbps="$1"
    [[ -n "$mbps" && "$mbps" =~ ^[0-9]+$ && "$mbps" -gt 0 ]] || return 1
    if ((mbps >= 1000)); then
        awk -v v="$mbps" 'BEGIN { printf "%.1fgbit", v / 1000 }'
    else
        printf '%dmbit' "$mbps"
    fi
}

connection_icon() {
    local kind="${1:-disconnected}"
    case "$kind" in
    ethernet) printf '%s' "󰈀" ;;
    *) printf '%s' "󰤮" ;;
    esac
}

read_iface_bytes() {
    local iface="$1"
    local rx_path="/sys/class/net/$iface/statistics/rx_bytes"
    local tx_path="/sys/class/net/$iface/statistics/tx_bytes"
    [[ -n "$iface" && -r "$rx_path" && -r "$tx_path" ]] || return 1
    printf '%s\t%s\n' "$(cat "$rx_path" 2>/dev/null || echo 0)" "$(cat "$tx_path" 2>/dev/null || echo 0)"
}

# Sample interface throughput in bytes/sec (interval defaults to 1s).
sample_iface_rates() {
    local iface="$1"
    local interval="${2:-1}"
    local rx1 tx1 rx2 tx2 download_bps upload_bps

    [[ "$interval" =~ ^[0-9]+$ && "$interval" -gt 0 ]] || interval=1

    if ! read_iface_bytes "$iface" >/dev/null 2>&1; then
        printf '0\t0\n'
        return 0
    fi

    IFS=$'\t' read -r rx1 tx1 <<<"$(read_iface_bytes "$iface")"
    sleep "$interval"
    IFS=$'\t' read -r rx2 tx2 <<<"$(read_iface_bytes "$iface")"

    download_bps=$(( (rx2 - rx1) / interval ))
    upload_bps=$(( (tx2 - tx1) / interval ))
    if (( download_bps < 0 )); then download_bps=0; fi
    if (( upload_bps < 0 )); then upload_bps=0; fi
    printf '%s\t%s\n' "$download_bps" "$upload_bps"
}

sample_socket_traffic() {
    command -v ss >/dev/null 2>&1 || return 0
    ss -Htipn state established 2>/dev/null | awk '
        function is_loopback(addr,   a) {
            a = addr
            sub(/%.*$/, "", a)
            if (a ~ /^127\./ || a == "::1" || a ~ /^::ffff:127\./) return 1
            return 0
        }
        /^[0-9]/ {
            line = $0
            local = $3
            remote = $4
            pid = ""
            name = "unknown"
            if (match(line, /pid=([0-9]+)/, m)) pid = m[1]
            if (match(line, /users:\(\("([^"]+)"/, m)) name = m[1]
            if (pid == "" || is_loopback(local) || is_loopback(remote)) {
                pid = ""
                next
            }
            next
        }
        /^[ \t]/ {
            if (pid == "") next
            rx = 0
            tx = 0
            if (match($0, /bytes_received:([0-9]+)/, m)) rx = m[1] + 0
            if (match($0, /bytes_sent:([0-9]+)/, m)) tx = m[1] + 0
            down[pid] += rx
            up[pid] += tx
            names[pid] = name
            next
        }
        END {
            for (p in down)
                print p "\t" names[p] "\t" down[p] "\t" up[p]
        }
    '
}
