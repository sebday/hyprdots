#!/bin/bash
# Evo panel: system snapshot + live mem/disk stats.
#
# Usage:
#   evo-panel-info-system.sh         — full snapshot JSON
#   evo-panel-info-system.sh --live  — mem/disk fields only

set -euo pipefail

fmt_bytes() {
    local b="${1:-0}"
    awk -v b="$b" 'BEGIN {
        if (b >= 1073741824) printf "%.1f GiB", b / 1073741824
        else if (b >= 1048576) printf "%.1f MiB", b / 1048576
        else if (b >= 1024) printf "%.0f KiB", b / 1024
        else printf "%d B", b
    }'
}

read_mount_stats() {
    local mp="$1"
    if [[ ! -d "$mp" ]]; then
        printf '0 0 0'
        return
    fi
    df -B1 --output=used,size,pcent "$mp" 2>/dev/null | awk 'NR == 2 { gsub(/%/, "", $3); print $1, $2, $3; found=1 } END { if (!found) print "0 0 0" }'
}

read_cpu_percent() {
    local state_dir state idle total prev_idle prev_total di dt
    state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/evo-shell"
    state="$state_dir/cpu-stat.prev"
    mkdir -p "$state_dir"
    read -r idle total < <(awk '/^cpu / {idle=$5+$6; t=0; for (i=2; i<=NF; i++) t+=$i; print idle, t}' /proc/stat)
  prev_idle=0
  prev_total=0
  if [[ -f "$state" ]]; then
    read -r prev_idle prev_total < "$state" || true
  fi
  printf '%s %s\n' "$idle" "$total" > "$state"
  if (( prev_total > 0 && total > prev_total )); then
    di=$((idle - prev_idle))
    dt=$((total - prev_total))
    awk -v di="$di" -v dt="$dt" 'BEGIN { if (dt > 0) printf "%.1f", 100 * (1 - di / dt); else print 0 }'
  else
    printf '0'
  fi
}

read_uptime_short() {
    fmt_uptime "$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo 0)"
}

read_live_stats() {
    local mem_total mem_used mem_avail disk_used disk_total disk_pct
    local storage_used storage_total storage_pct
    local external_used external_total external_pct
    local cpu_pct uptime_short

    cpu_pct="$(read_cpu_percent)"
    uptime_short="$(read_uptime_short)"

    read -r mem_total mem_avail < <(awk '
        /MemTotal:/ { t = $2 }
        /MemAvailable:/ { a = $2 }
        END {
            if (t == "") t = 0
            if (a == "") a = 0
            printf "%d %d\n", t * 1024, a * 1024
        }
    ' /proc/meminfo)

    mem_used=$((mem_total - mem_avail))
    if (( mem_total > 0 )); then
        mem_pct=$(awk -v u="$mem_used" -v t="$mem_total" 'BEGIN { printf "%.1f", (u / t) * 100 }')
    else
        mem_pct="0"
    fi

    read -r disk_used disk_total disk_pct < <(df -B1 --output=used,size,pcent / 2>/dev/null | awk 'NR == 2 { gsub(/%/, "", $3); print $1, $2, $3 }')
    disk_used="${disk_used:-0}"
    disk_total="${disk_total:-0}"
    disk_pct="${disk_pct:-0}"

    read -r storage_used storage_total storage_pct < <(read_mount_stats /mnt/storage)
    storage_used="${storage_used:-0}"
    storage_total="${storage_total:-0}"
    storage_pct="${storage_pct:-0}"

    read -r external_used external_total external_pct < <(read_mount_stats /mnt/external)
    external_used="${external_used:-0}"
    external_total="${external_total:-0}"
    external_pct="${external_pct:-0}"

    jq -cn \
        --argjson memTotal "$mem_total" \
        --arg memPercent "$mem_pct" \
        --arg memTotalLabel "$(fmt_bytes "$mem_total")" \
        --argjson diskTotal "$disk_total" \
        --arg diskPercent "$disk_pct" \
        --arg diskTotalLabel "$(fmt_bytes "$disk_total")" \
        --argjson storageUsed "$storage_used" \
        --argjson storageTotal "$storage_total" \
        --arg storagePercent "$storage_pct" \
        --arg storageTotalLabel "$(fmt_bytes "$storage_total")" \
        --argjson externalUsed "$external_used" \
        --argjson externalTotal "$external_total" \
        --arg externalPercent "$external_pct" \
        --arg externalTotalLabel "$(fmt_bytes "$external_total")" \
        --arg cpuPercent "$cpu_pct" \
        --arg uptime "$uptime_short" \
        '{
            ok: true,
            uptime: $uptime,
            cpuPercent: ($cpuPercent | tonumber),
            memTotal: $memTotal,
            memPercent: ($memPercent | tonumber),
            memTotalLabel: $memTotalLabel,
            diskTotal: $diskTotal,
            diskPercent: ($diskPercent | tonumber),
            diskTotalLabel: $diskTotalLabel,
            storageUsed: $storageUsed,
            storageTotal: $storageTotal,
            storagePercent: ($storagePercent | tonumber),
            storageTotalLabel: $storageTotalLabel,
            externalUsed: $externalUsed,
            externalTotal: $externalTotal,
            externalPercent: ($externalPercent | tonumber),
            externalTotalLabel: $externalTotalLabel
        }'
}

fmt_uptime() {
    awk -v s="${1:-0}" 'BEGIN {
        s = int(s)
        if (s < 0) s = 0
        d = int(s / 86400); s %= 86400
        h = int(s / 3600); s %= 3600
        m = int(s / 60)
        if (d > 0) printf "%dd %dh %dm", d, h, m
        else if (h > 0) printf "%dh %dm", h, m
        else printf "%dm", m
    }'
}

read_os() {
    local pretty=""
    # shellcheck disable=SC1091
    if [[ -r /etc/os-release ]]; then
        pretty="$(. /etc/os-release && printf '%s' "${PRETTY_NAME:-}")"
    fi
    printf '%s' "$pretty"
}

read_install_age() {
    local birth current days
    birth="$(stat -c %W / 2>/dev/null || echo 0)"
    if ! [[ "$birth" =~ ^[0-9]+$ ]] || (( birth <= 0 )); then
        return 0
    fi
    current="$(date +%s)"
    days=$(( (current - birth) / 86400 ))
    (( days < 0 )) && days=0
    printf '%s days old' "$days"
}

read_kernel() {
    uname -r
}

read_packages() {
    local n
    n="$(pacman -Qq 2>/dev/null | wc -l)"
    n="${n// /}"
    printf '%s' "${n:-0}"
}

read_wm() {
    local line
    line="$(hyprctl version 2>/dev/null | awk 'NR==1 {print $1, $2; exit}')"
    line="${line%"${line##*[![:space:]]}"}"
    if [[ -n "$line" ]]; then
        printf '%s' "$line"
        return
    fi
    printf '%s' "${XDG_CURRENT_DESKTOP:-Hyprland}"
}

read_host() {
    local vendor product
    vendor="$(tr -d '\0' < /sys/devices/virtual/dmi/id/sys_vendor 2>/dev/null || true)"
    product="$(tr -d '\0' < /sys/devices/virtual/dmi/id/product_name 2>/dev/null || true)"
    vendor="${vendor//$'\n'/}"
    product="${product//$'\n'/}"
    vendor="${vendor#"${vendor%%[![:space:]]*}"}"
    vendor="${vendor%"${vendor##*[![:space:]]}"}"
    product="${product#"${product%%[![:space:]]*}"}"
    product="${product%"${product##*[![:space:]]}"}"
    if [[ -z "$vendor" || "$vendor" == "To be filled by O.E.M." ]]; then
        printf '%s' "$product"
        return
    fi
    if [[ -z "$product" || "$product" == "To be filled by O.E.M." ]]; then
        printf '%s' "$vendor"
        return
    fi
    printf '%s %s' "$vendor" "$product"
}

read_cpu() {
    local name
    name="$(awk -F': ' '/^model name/ {print $2; exit}' /proc/cpuinfo)"
    name="${name// CPU / }"
    name="${name%% @ *}"
    name="${name#"${name%%[![:space:]]*}"}"
    name="${name%"${name##*[![:space:]]}"}"
    printf '%s' "$name"
}

read_gpu() {
    local line name brand=""
    line="$(lspci 2>/dev/null | grep -E 'VGA compatible controller|3D controller|Display controller' | head -1)"
    [[ -z "$line" ]] && return 0
    if [[ "$line" == *NVIDIA* ]]; then
        brand="NVIDIA"
    elif [[ "$line" == *AMD* || "$line" == *ATI* ]]; then
        brand="AMD"
    elif [[ "$line" == *Intel* ]]; then
        brand="Intel"
    fi
    name="$(grep -oE '\[[^]]+\]' <<<"$line" | sed 's/^\[//;s/\]$//' | grep -Ev '^[0-9a-fA-F]+:[0-9a-fA-F]+$|^AMD/ATI$' | tail -1)"
    name="${name%%/*}"
    name="${name%"${name##*[![:space:]]}"}"
    if [[ -n "$brand" && -n "$name" ]]; then
        printf '%s %s' "$brand" "$name"
    elif [[ -n "$name" ]]; then
        printf '%s' "$name"
    else
        printf '%s' "${line#*: }"
    fi
}

read_snapshot() {
    local os install_age kernel packages wm host cpu gpu uptime_text
    local live_json

    live_json="$(read_live_stats)"
    os="$(read_os)"
    install_age="$(read_install_age)"
    kernel="$(read_kernel)"
    packages="$(read_packages)"
    wm="$(read_wm)"
    host="$(read_host)"
    cpu="$(read_cpu)"
    gpu="$(read_gpu)"
    uptime_text="$(read_uptime_short)"

    jq -cn \
        --argjson live "$live_json" \
        --arg os "$os" \
        --arg installAge "$install_age" \
        --arg kernel "$kernel" \
        --argjson packages "${packages:-0}" \
        --arg wm "$wm" \
        --arg host "$host" \
        --arg cpu "$cpu" \
        --arg gpu "$gpu" \
        --arg uptime "$uptime_text" \
        '$live + {
            os: $os,
            installAge: $installAge,
            kernel: $kernel,
            packages: $packages,
            wm: $wm,
            host: $host,
            cpu: $cpu,
            gpu: $gpu,
            uptime: $uptime
        }'
}

if [[ "${1:-}" == "--live" ]]; then
    read_live_stats
else
    read_snapshot
fi
