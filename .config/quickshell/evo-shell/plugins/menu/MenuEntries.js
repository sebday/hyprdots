// Static menu entries migrated from elephant menus (only what is actually used).

function systemActionEntries(home) {
    var bin = home + "/.local/bin"
    return [
        { name: "Theme", icon: "󰸌", keywords: ["theme", "appearance", "looks"], command: bin + "/evo-theme.sh" },
        { name: "Wallpaper", icon: "󰏘", keywords: ["wallpaper", "background"], command: bin + "/evo-theme.sh wallpaper" },
        { name: "Clear cache", icon: "󰃢", keywords: ["cache", "cleanup", "clear"], command: bin + "/evo-cleanup.sh" },
        { name: "Backup", icon: "󰁯", keywords: ["backup", "env"], command: bin + "/evo-backup.sh" }
    ]
}

function powerEntries(home) {
    return [
        { name: "Lock", icon: "󰌾", keywords: ["lock", "screen"], command: "evo-system-lock" },
        { name: "Evo", icon: "󰑐", keywords: ["evo", "shell", "bar", "quickshell", "refresh", "restart shell"], command: home + "/.local/bin/evo-restart-shell.sh" },
        { name: "Hypr", icon: "󰑐", keywords: ["hypr", "hyprland", "relaunch", "logout", "session"], command: home + "/.local/bin/evo-logout.sh relaunch" },
        { name: "Restart", icon: "󰜉", keywords: ["reboot", "restart"], command: home + "/.local/bin/evo-logout.sh reboot" },
        { name: "Shutdown", icon: "󰐥", keywords: ["shutdown", "power off"], command: home + "/.local/bin/evo-logout.sh shutdown" }
    ]
}

function systemEntries(home) {
    return systemActionEntries(home).concat(powerEntries(home))
}

function matchesQuery(entry, query) {
    if (!query) return true
    var q = query.toLowerCase()
    if (entry.name && entry.name.toLowerCase().indexOf(q) !== -1) return true
    if (entry.keywords) {
        for (var i = 0; i < entry.keywords.length; i++) {
            if (String(entry.keywords[i]).toLowerCase().indexOf(q) !== -1) return true
        }
    }
    return false
}

function filterEntries(list, query, limit) {
    var out = []
    for (var i = 0; i < list.length; i++) {
        if (matchesQuery(list[i], query)) out.push(list[i])
    }
    if (limit && out.length > limit) return out.slice(0, limit)
    return out
}

function mapEntry(e) {
    return {
        kind: e.submenu ? "submenu" : "command",
        name: e.name,
        command: e.command,
        submenu: e.submenu,
        icon: e.icon || "󰍉"
    }
}
