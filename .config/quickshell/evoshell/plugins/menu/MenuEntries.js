// Static menu entries migrated from elephant menus (only what is actually used).

function ipc(home, args) {
    return home + "/.local/bin/evo-ipc shell " + args
}

function panelToggle(home, module, focus) {
    var payload = { module: module }
    if (focus)
        payload.focus = focus
    return ipc(home, "toggle evo.panel '" + JSON.stringify(payload) + "'")
}

function systemEntries(home) {
    var bin = home + "/.local/bin"
    return [
        { name: "Apps", icon: "󰀻", keywords: ["apps", "applications", "launcher", "programs"], mode: "apps" },
        { name: "Settings", icon: "󰒓", keywords: ["settings", "panel", "hypr", "bar"], command: panelToggle(home, "settings") },
        { name: "Themes", icon: "󰸌", keywords: ["theme", "colours", "gtk"], submenu: "themes" },
        { name: "Wallpaper", icon: "󰏘", keywords: ["wallpaper", "background"], submenu: "wallpaper" },
        { name: "Music", icon: "󰎈", keywords: ["music", "player", "mpv"], command: ipc(home, "toggle evo.player") },
        { name: "Library", icon: "󰿯", keywords: ["library", "film", "tv", "movies"], command: ipc(home, "toggle evo.library") },
        { name: "Calculator", icon: "󰪚", keywords: ["calc", "calculator", "math"], command: panelToggle(home, "calc") },
        { name: "Tasks", icon: "󰄴", keywords: ["tasks", "todo", "list"], command: panelToggle(home, "calc", "tasks") },
        { name: "Clipboard", icon: "󰅍", keywords: ["clipboard", "copy", "paste"], command: ipc(home, "toggle evo.clipboard") },
        { name: "Shopify", icon: "󰒚", keywords: ["shopify", "sales", "dashboard", "store", "shop"], command: ipc(home, "toggle evo.shopify") },
        { name: "Bindings", icon: "󰌌", keywords: ["bindings", "shortcuts", "keys", "hotkeys", "hyprland", "keybindings"], submenu: "bindings" },
        { name: "Reload bar", icon: "󰑐", keywords: ["reload", "config", "bar", "shell"], command: ipc(home, "reloadConfig") },
        { name: "Lock", icon: "󰌾", keywords: ["lock", "screen"], command: bin + "/evo-system lock" },
        { name: "Restart shell", icon: "󰑐", keywords: ["evo", "shell", "bar", "quickshell", "refresh"], command: bin + "/evo-system restart" },
        { name: "Clear cache", icon: "󰃢", keywords: ["cache", "cleanup", "clear"], command: bin + "/evo-system-cleanup" },
        { name: "Backup", icon: "󰁯", keywords: ["backup", "env"], command: bin + "/evo-system-backup" },
        { name: "Reboot", icon: "󰜉", keywords: ["reboot", "restart"], command: bin + "/evo-system reboot" },
        { name: "Shutdown", icon: "󰐥", keywords: ["shutdown", "power off"], command: bin + "/evo-system shutdown" }
    ]
}

function matchesQuery(entry, query) {
    if (!query) return true
    var q = query.toLowerCase()
    if (entry.name && entry.name.toLowerCase().indexOf(q) !== -1) return true
    if (entry.keys && String(entry.keys).toLowerCase().indexOf(q) !== -1) return true
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
        kind: e.submenu ? "submenu" : (e.mode ? "mode" : "command"),
        name: e.name,
        command: e.command,
        submenu: e.submenu,
        mode: e.mode,
        icon: e.icon || "󰍉"
    }
}
