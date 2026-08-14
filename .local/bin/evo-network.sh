#!/usr/bin/env bash
# Network status and per-process traffic for evo-shell.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/evo-network-lib.sh"

print_status() {
    local device
    device=$(active_iface)
    if [[ -z "$device" ]]; then
        printf 'disconnected\t\t\n'
        return
    fi
    local speed=""
    if [[ -r "/sys/class/net/$device/speed" ]]; then
        speed=$(cat "/sys/class/net/$device/speed" 2>/dev/null || true)
    fi
    printf 'ethernet\t%s\t%s\n' "$device" "$speed"
}

print_ping_samples() {
    local gateway="$1"
    local tmpdir router_file internet_file
    local router_pid="" internet_pid=""

    command -v ping >/dev/null 2>&1 || return 0
    tmpdir=$(mktemp -d) || return 0
    router_file="$tmpdir/router"
    internet_file="$tmpdir/internet"

    if [[ -n "$gateway" ]]; then
        ping_latency_ms "$gateway" >"$router_file" &
        router_pid=$!
    fi

    ping_latency_ms "$INTERNET_PROBE" >"$internet_file" &
    internet_pid=$!

    if [[ -n "$router_pid" ]]; then
        wait "$router_pid" || true
        printf 'router_ping_ms\t%s\n' "$(cat "$router_file" 2>/dev/null || true)"
    fi

    wait "$internet_pid" || true
    printf 'internet_ping_ms\t%s\n' "$(cat "$internet_file" 2>/dev/null || true)"
    rm -rf "$tmpdir"
}

print_verbose() {
    local route_json iface gw src prefix speed duplex
    route_json=$(ip -j route get "$INTERNET_PROBE" 2>/dev/null || true)
    [[ -n "$route_json" ]] || return 0

    iface=$(jq -r '.[0].dev // ""' <<<"$route_json" 2>/dev/null)
    gw=$(jq -r '.[0].gateway // ""' <<<"$route_json" 2>/dev/null)
    src=$(jq -r '.[0].prefsrc // ""' <<<"$route_json" 2>/dev/null)
    [[ -n "$iface" ]] || return 0

    prefix=$(ip -j addr show "$iface" 2>/dev/null | jq -r '.[0].addr_info[]? | select(.family == "inet") | .prefixlen // ""' 2>/dev/null | head -n1)

    printf 'iface\t%s\n' "$iface"
    printf 'type\tethernet\n'
    printf 'ip\t%s\n' "$src"
    printf 'prefix\t%s\n' "$prefix"
    printf 'gateway\t%s\n' "$gw"

    if [[ -r "/sys/class/net/$iface/statistics/rx_bytes" ]]; then
        printf 'rx_bytes\t%s\n' "$(cat "/sys/class/net/$iface/statistics/rx_bytes")"
    fi
    if [[ -r "/sys/class/net/$iface/statistics/tx_bytes" ]]; then
        printf 'tx_bytes\t%s\n' "$(cat "/sys/class/net/$iface/statistics/tx_bytes")"
    fi
    if [[ -r "/sys/class/net/$iface/speed" ]]; then
        speed=$(cat "/sys/class/net/$iface/speed" 2>/dev/null || true)
        [[ -n "$speed" && "$speed" != "-1" ]] && printf 'speed\t%s\n' "$speed"
    fi
    if [[ -r "/sys/class/net/$iface/duplex" ]]; then
        duplex=$(cat "/sys/class/net/$iface/duplex" 2>/dev/null || true)
        [[ -n "$duplex" ]] && printf 'duplex\t%s\n' "$duplex"
    fi

    print_ping_samples "$gw"
}

print_top_processes() {
    local interval=1
    local sample_a sample_b

    command -v ss >/dev/null 2>&1 || return 0
    command -v awk >/dev/null 2>&1 || return 0

    sample_a=$(mktemp) || return 0
    sample_b=$(mktemp) || { rm -f "$sample_a"; return 0; }

    sample_socket_traffic >"$sample_a"
    sleep "$interval"
    sample_socket_traffic >"$sample_b"

    awk -F'\t' -v dt="$interval" '
        FNR==NR {
            ad[$1] = $3 + 0
            au[$1] = $4 + 0
            an[$1] = $2
            next
        }
        {
            if (!($1 in ad)) next
            dd = ($3 - ad[$1]) / dt
            du = ($4 - au[$1]) / dt
            if (dd < 0) dd = 0
            if (du < 0) du = 0
            name = $2
            if (dd > 0) print "down\t" name "\t" dd
            if (du > 0) print "up\t" name "\t" du
        }
    ' "$sample_a" "$sample_b" | sort -t "$(printf '\t')" -k1,1 -k3,3gr | awk -F'\t' '
        $1 == "down" && down_count < 5 {
            printf "proc_down\t%s\t%s\n", $2, $3
            down_count++
        }
        $1 == "up" && up_count < 5 {
            printf "proc_up\t%s\t%s\n", $2, $3
            up_count++
        }
    '

    rm -f "$sample_a" "$sample_b"
}

case "${1:-}" in
status) print_status ;;
verbose) print_verbose ;;
processes) print_top_processes ;;
*)
    echo "usage: evo-network.sh status|verbose|processes" >&2
    exit 2
    ;;
esac
