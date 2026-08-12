#!/bin/bash
# Evo panel: fastfetch-style system snapshot + live mem/disk stats.
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

read_live_stats() {
    local mem_total mem_used mem_avail disk_used disk_total disk_pct
    local storage_used storage_total storage_pct
    local external_used external_total external_pct
    local monitors_json

    monitors_json="$(read_monitors_json)"

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
        --argjson memUsed "$mem_used" \
        --argjson memTotal "$mem_total" \
        --arg memPercent "$mem_pct" \
        --arg memUsedLabel "$(fmt_bytes "$mem_used")" \
        --arg memTotalLabel "$(fmt_bytes "$mem_total")" \
        --argjson diskUsed "$disk_used" \
        --argjson diskTotal "$disk_total" \
        --arg diskPercent "$disk_pct" \
        --arg diskUsedLabel "$(fmt_bytes "$disk_used")" \
        --arg diskTotalLabel "$(fmt_bytes "$disk_total")" \
        --argjson storageUsed "$storage_used" \
        --argjson storageTotal "$storage_total" \
        --arg storagePercent "$storage_pct" \
        --arg storageTotalLabel "$(fmt_bytes "$storage_total")" \
        --argjson externalUsed "$external_used" \
        --argjson externalTotal "$external_total" \
        --arg externalPercent "$external_pct" \
        --arg externalTotalLabel "$(fmt_bytes "$external_total")" \
        --argjson monitors "$monitors_json" \
        '{
            ok: true,
            memUsed: $memUsed,
            memTotal: $memTotal,
            memPercent: ($memPercent | tonumber),
            memUsedLabel: $memUsedLabel,
            memTotalLabel: $memTotalLabel,
            diskUsed: $diskUsed,
            diskTotal: $diskTotal,
            diskPercent: ($diskPercent | tonumber),
            diskUsedLabel: $diskUsedLabel,
            diskTotalLabel: $diskTotalLabel,
            storageUsed: $storageUsed,
            storageTotal: $storageTotal,
            storagePercent: ($storagePercent | tonumber),
            storageTotalLabel: $storageTotalLabel,
            externalUsed: $externalUsed,
            externalTotal: $externalTotal,
            externalPercent: ($externalPercent | tonumber),
            externalTotalLabel: $externalTotalLabel,
            monitors: $monitors
        }'
}

fmt_uptime() {
    local ms="${1:-0}"
    awk -v ms="$ms" 'BEGIN {
        s = int(ms / 1000)
        d = int(s / 86400); s %= 86400
        h = int(s / 3600); s %= 3600
        m = int(s / 60)
        if (d > 0) printf "%dd %dh %dm", d, h, m
        else if (h > 0) printf "%dh %dm", h, m
        else printf "%dm", m
    }'
}

read_monitors_json() {
    hyprctl monitors -j 2>/dev/null | jq -c '
        if type == "array" then
            [.[] | {
                name: .name,
                width: .width,
                height: .height,
                resolution: "\(.width)×\(.height)",
                x: .x,
                y: .y,
                scale: (if (.scale // 1) == 0 then 1 else .scale end)
            }] | sort_by(.y, .x)
        else
            []
        end
    ' 2>/dev/null || echo '[]'
}

read_snapshot() {
    local ff os install_age kernel packages wm host cpu gpu uptime_text
    local live_json mem_used mem_total mem_pct disk_used disk_total disk_pct
    local monitors_json

    live_json="$(read_live_stats)"
    mem_used="$(echo "$live_json" | jq -r '.memUsed')"
    mem_total="$(echo "$live_json" | jq -r '.memTotal')"
    mem_pct="$(echo "$live_json" | jq -r '.memPercent')"
    disk_used="$(echo "$live_json" | jq -r '.diskUsed')"
    disk_total="$(echo "$live_json" | jq -r '.diskTotal')"
    disk_pct="$(echo "$live_json" | jq -r '.diskPercent')"
    storage_used="$(echo "$live_json" | jq -r '.storageUsed')"
    storage_total="$(echo "$live_json" | jq -r '.storageTotal')"
    storage_pct="$(echo "$live_json" | jq -r '.storagePercent')"
    external_used="$(echo "$live_json" | jq -r '.externalUsed')"
    external_total="$(echo "$live_json" | jq -r '.externalTotal')"
    external_pct="$(echo "$live_json" | jq -r '.externalPercent')"
    monitors_json="$(echo "$live_json" | jq -c '.monitors // []')"

    if ! ff="$(fastfetch --json 2>/dev/null)"; then
        jq -cn --arg error "System info unavailable" \
            '{ok:false, error:$error}'
        exit 0
    fi

    os="$(echo "$ff" | jq -r '.[] | select(.type=="OS") | .result.prettyName // .result.name // ""' | head -1)"
    install_age="$(echo "$ff" | jq -r '.[] | select(.type=="Command") | .result // ""' | head -1)"
    kernel="$(echo "$ff" | jq -r '.[] | select(.type=="Kernel") | .result.release // ""' | head -1)"
    packages="$(echo "$ff" | jq -r '.[] | select(.type=="Packages") | .result.all // .result.pacman // 0' | head -1)"
    wm="$(echo "$ff" | jq -r '.[] | select(.type=="WM") | "\(.result.prettyName // .result.processName // "") \(.result.version // "")"' | head -1 | sed 's/ $//')"
    host="$(echo "$ff" | jq -r '.[] | select(.type=="Host") | "\(.result.vendor // "") \(.result.name // "")"' | head -1 | sed 's/^ //;s/ $//')"
    cpu="$(echo "$ff" | jq -r '.[] | select(.type=="CPU") | .result.cpu // ""' | head -1)"
    gpu="$(echo "$ff" | jq -r '.[] | select(.type=="GPU") | .result[0].name // ""' | head -1)"
  local uptime_ms
    uptime_ms="$(echo "$ff" | jq -r '.[] | select(.type=="Uptime") | .result.uptime // 0' | head -1)"
    uptime_text="$(fmt_uptime "$uptime_ms")"

    jq -cn \
        --arg os "$os" \
        --arg installAge "$install_age" \
        --arg kernel "$kernel" \
        --argjson packages "${packages:-0}" \
        --arg wm "$wm" \
        --arg host "$host" \
        --arg cpu "$cpu" \
        --arg gpu "$gpu" \
        --arg uptime "$uptime_text" \
        --argjson memUsed "$mem_used" \
        --argjson memTotal "$mem_total" \
        --argjson memPercent "$mem_pct" \
        --arg memUsedLabel "$(fmt_bytes "$mem_used")" \
        --arg memTotalLabel "$(fmt_bytes "$mem_total")" \
        --argjson diskUsed "$disk_used" \
        --argjson diskTotal "$disk_total" \
        --argjson diskPercent "$disk_pct" \
        --arg diskUsedLabel "$(fmt_bytes "$disk_used")" \
        --arg diskTotalLabel "$(fmt_bytes "$disk_total")" \
        --argjson storageUsed "$storage_used" \
        --argjson storageTotal "$storage_total" \
        --arg storagePercent "$storage_pct" \
        --arg storageTotalLabel "$(fmt_bytes "$storage_total")" \
        --argjson externalUsed "$external_used" \
        --argjson externalTotal "$external_total" \
        --arg externalPercent "$external_pct" \
        --arg externalTotalLabel "$(fmt_bytes "$external_total")" \
        --argjson monitors "$monitors_json" \
        '{
            ok: true,
            os: $os,
            installAge: $installAge,
            kernel: $kernel,
            packages: $packages,
            wm: $wm,
            host: $host,
            cpu: $cpu,
            gpu: $gpu,
            uptime: $uptime,
            memUsed: $memUsed,
            memTotal: $memTotal,
            memPercent: $memPercent,
            memUsedLabel: $memUsedLabel,
            memTotalLabel: $memTotalLabel,
            diskUsed: $diskUsed,
            diskTotal: $diskTotal,
            diskPercent: $diskPercent,
            diskUsedLabel: $diskUsedLabel,
            diskTotalLabel: $diskTotalLabel,
            storageUsed: $storageUsed,
            storageTotal: $storageTotal,
            storagePercent: ($storagePercent | tonumber),
            storageTotalLabel: $storageTotalLabel,
            externalUsed: $externalUsed,
            externalTotal: $externalTotal,
            externalPercent: ($externalPercent | tonumber),
            externalTotalLabel: $externalTotalLabel,
            monitors: $monitors
        }'
}

if [[ "${1:-}" == "--live" ]]; then
    read_live_stats
else
    read_snapshot
fi
