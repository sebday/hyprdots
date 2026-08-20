// Static menu entries migrated from elephant menus (only what is actually used).

function ipc(home, args) {
    return home + "/.local/bin/evo-ipc shell " + args
}

function panelToggle(home, module, focus) {
    var payload = { module: module }
    if (focus)
        payload.focus = focus
    return ipc(home, "toggle evo.side '" + JSON.stringify(payload) + "'")
}

function systemSectionLayout(home) {
    var entries = systemEntries(home)
    var byName = {}
    for (var i = 0; i < entries.length; i++)
        byName[entries[i].name] = entries[i]

    function pick(names) {
        var out = []
        for (var j = 0; j < names.length; j++) {
            if (byName[names[j]])
                out.push(byName[names[j]])
        }
        return out
    }

    return {
        panels: {
            title: "Panels",
            icon: "󰐒",
            entries: pick([
                "Settings", "Themes", "Wallpaper", "Music", "Library",
                "Calculator", "Tasks", "Clipboard", "Shopify"
            ])
        },
        right: [
            { title: "Reference", icon: "󰋗", entries: pick(["Bindings", "Shell commands"]) },
            { title: "Session", icon: "󰍃", entries: pick([
                "Lock", "Restart shell", "Clear cache", "Backup", "Reboot", "Shutdown"
            ]) }
        ]
    }
}

function systemSections(home) {
    var layout = systemSectionLayout(home)
    var out = []
    if (layout.panels)
        out.push(layout.panels)
    return out.concat(layout.right)
}

function systemEntries(home) {
    var bin = home + "/.local/bin"
    return [
        { name: "Settings", icon: "󰒓", keywords: ["settings", "panel", "hypr", "bar"], command: ipc(home, "toggle evo.sys.settings") },
        { name: "Themes", icon: "󰸌", keywords: ["theme", "colours", "gtk"], command: ipc(home, "toggle evo.sys.themes") },
        { name: "Wallpaper", icon: "󰏘", keywords: ["wallpaper", "background"], command: ipc(home, "toggle evo.sys.wallpaper") },
        { name: "Music", icon: "󰎈", keywords: ["music", "player", "mpv"], command: ipc(home, "toggle evo.panel.player") },
        { name: "Library", icon: "󰿯", keywords: ["library", "film", "tv", "movies"], command: ipc(home, "toggle evo.bar.media.library") },
        { name: "Calculator", icon: "󰪚", keywords: ["calc", "calculator", "math"], command: panelToggle(home, "calc") },
        { name: "Tasks", icon: "󰄴", keywords: ["tasks", "todo", "list"], command: panelToggle(home, "calc", "tasks") },
        { name: "Clipboard", icon: "󰅍", keywords: ["clipboard", "copy", "paste"], command: ipc(home, "toggle evo.side.clipboard") },
        { name: "Shopify", icon: "󰒚", keywords: ["shopify", "sales", "dashboard", "store", "shop"], command: ipc(home, "toggle evo.panel.shopify") },
        { name: "Bindings", icon: "󰌌", keywords: ["bindings", "shortcuts", "keys", "hotkeys", "hyprland", "keybindings"], submenu: "bindings" },
        { name: "Shell commands", icon: "󰆍", keywords: ["shell", "ipc", "commands", "evo-ipc", "quickshell"], submenu: "shell" },
        { name: "Lock", icon: "󰌾", keywords: ["lock", "screen"], command: bin + "/evo-system lock" },
        { name: "Restart shell", icon: "󰑐", keywords: ["evo", "shell", "bar", "quickshell", "refresh"], command: bin + "/evo-system restart" },
        { name: "Clear cache", icon: "󰃢", keywords: ["cache", "cleanup", "clear"], command: bin + "/evo-system-cleanup" },
        { name: "Backup", icon: "󰁯", keywords: ["backup", "env"], command: bin + "/evo-system-backup" },
        { name: "Reboot", icon: "󰜉", keywords: ["reboot", "restart"], command: bin + "/evo-system reboot" },
        { name: "Shutdown", icon: "󰐥", keywords: ["shutdown", "power off"], command: bin + "/evo-system shutdown" }
    ]
}

function startsWithQuery(text, query) {
    if (!query) return true
    if (!text) return false
    return String(text).toLowerCase().startsWith(String(query).toLowerCase())
}

function matchesQuery(entry, query) {
    if (!query) return true
    var q = String(query).toLowerCase()
    if (startsWithQuery(entry.name, q)) return true
    if (startsWithQuery(entry.keys, q)) return true
    if (startsWithQuery(entry.command, q)) return true
    if (entry.keywords) {
        for (var i = 0; i < entry.keywords.length; i++) {
            if (startsWithQuery(entry.keywords[i], q)) return true
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
