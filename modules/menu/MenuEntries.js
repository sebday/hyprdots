// Static system menu entries.

function evoBin(home) {
    return String(home || "") + "/.local/bin/evo"
}

function evoshellLib(home, binOverride) {
    if (binOverride && String(binOverride).trim() !== "")
        return String(binOverride).trim()
    return String(home || "") + "/.local/lib/evoshell/bin"
}

function ipc(home, args) {
    return evoBin(home) + " ipc shell " + args
}

function systemSectionLayout(home, binOverride, extensionPanels) {
    var entries = systemEntries(home, binOverride)
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

    var panelEntries = pick([
        "Themes", "Wallpaper", "Music",
        "Calculator", "Clipboard"
    ])
    if (extensionPanels && extensionPanels.length) {
        for (var k = 0; k < extensionPanels.length; k++)
            panelEntries.push(extensionPanels[k])
    }

    return {
        panels: {
            title: "Panels",
            icon: "󰐒",
            entries: panelEntries
        },
        right: [
            { title: "Reference", icon: "󰋗", entries: pick([
                "Shell commands"
            ]) },
            { title: "Session", icon: "󰍃", entries: pick([
                "Lock", "Restart shell", "Reboot", "Shutdown"
            ]) }
        ]
    }
}

function systemSections(home, binOverride) {
    var layout = systemSectionLayout(home, binOverride)
    var out = []
    if (layout.panels)
        out.push(layout.panels)
    return out.concat(layout.right)
}

function systemEntries(home, binOverride) {
    var lib = evoshellLib(home, binOverride)
    var evo = evoBin(home)
    return [
        { name: "Themes", icon: "󰸌", keywords: ["theme", "colours", "gtk"], command: ipc(home, "toggle evo.sys.themes") },
        { name: "Wallpaper", icon: "󰏘", keywords: ["wallpaper", "background"], command: ipc(home, "toggle evo.sys.wallpaper") },
        { name: "Music", icon: "󰎈", keywords: ["music", "player", "mpv"], command: ipc(home, "toggle evo.panels.player") },
        { name: "Calculator", icon: "󰪚", keywords: ["calc", "calculator", "math"], command: ipc(home, "toggle evo.calculator") },
        { name: "Clipboard", icon: "󰅍", keywords: ["clipboard", "copy", "paste"], command: ipc(home, "toggle evo.side.clipboard") },
        { name: "Screenshot", icon: "󰆴", keywords: ["screenshot", "capture", "omasnap"], command: "omasnap" },
        { name: "Shell commands", icon: "󰆍", keywords: ["shell", "ipc", "commands", "evo", "quickshell"], submenu: "shell" },
        { name: "Lock", icon: "󰌾", keywords: ["lock", "screen"], command: evo + " system lock" },
        { name: "Restart shell", icon: "󰑐", keywords: ["evo", "shell", "bar", "quickshell", "refresh"], command: evo + " system restart" },
        { name: "Reboot", icon: "󰐥", keywords: ["reboot", "restart", "system"], command: evo + " system reboot" },
        { name: "Shutdown", icon: "󰐥", keywords: ["shutdown", "poweroff", "off"], command: evo + " system shutdown" }
    ]
}

function mapEntry(entry) {
    return {
        kind: entry.submenu ? "submenu" : (entry.mode ? "mode" : "command"),
        name: entry.name,
        icon: entry.icon,
        keywords: entry.keywords || [],
        command: entry.command || "",
        submenu: entry.submenu || "",
        mode: entry.mode || ""
    }
}

function scoreText(text, query) {
    if (!query) return 0
    var value = String(text || "").toLowerCase()
    var needle = String(query).toLowerCase()
    if (!value || !needle) return 0
    if (value === needle) return 1000
    if (value.startsWith(needle)) return 800
    if (value.indexOf(needle) >= 0) return 600
    return 0
}

function entryMatchScore(entry, query) {
    if (!query || !entry) return 0
    var best = 0
    best = Math.max(best, scoreText(entry.name, query))
    best = Math.max(best, scoreText(entry.id, query))
    best = Math.max(best, scoreText(entry.keys, query))
    best = Math.max(best, scoreText(entry.command, query))
    best = Math.max(best, scoreText(entry.detail, query))
    best = Math.max(best, scoreText(entry.files, query))
    if (entry.keywords) {
        for (var i = 0; i < entry.keywords.length; i++)
            best = Math.max(best, scoreText(entry.keywords[i], query))
    }
    return best
}

function matchesQuery(entry, query) {
    return entryMatchScore(entry, query) > 0
}

function bestMatchIndex(list, query) {
    if (!query || !list || list.length === 0) return 0
    var bestIdx = 0
    var bestScore = 0
    for (var i = 0; i < list.length; i++) {
        var score = entryMatchScore(list[i], query)
        if (score > bestScore) {
            bestScore = score
            bestIdx = i
        }
    }
    return bestIdx
}

function runnerEntries(home, binOverride, extensionPanels) {
    var layout = systemSectionLayout(home, binOverride, extensionPanels)
    var raw = []
    if (layout.panels && layout.panels.entries)
        raw = raw.concat(layout.panels.entries)
    if (layout.right) {
        for (var i = 0; i < layout.right.length; i++)
            raw = raw.concat(layout.right[i].entries || [])
    }
    return raw.map(mapEntry)
}

function systemMenuEntries(home, binOverride) {
    return systemEntries(home, binOverride).map(mapEntry)
}

function systemMenuSections(home, binOverride) {
    return systemSections(home, binOverride)
}
