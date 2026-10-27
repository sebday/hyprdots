.pragma library

function evoBin(home) {
    return String(home || "") + "/.local/bin/evo"
}

function commandEntries(home, extensionPanels) {
    var evo = evoBin(home)
    var raw = [
        { name: "Music", icon: "󰎈", keywords: ["music", "player", "mpv"], command: evo + " ipc shell toggle evo.panels.player" },
        { name: "Calculator", icon: "󰪚", keywords: ["calc", "calculator", "math"], command: evo + " ipc shell toggle evo.calculator" },
        { name: "Screenshot", icon: "󰆴", keywords: ["screenshot", "capture", "omasnap"], command: "omasnap" },
        { name: "Lock", icon: "󰌾", keywords: ["lock", "screen"], command: evo + " system lock" },
        { name: "Restart shell", icon: "󰑐", keywords: ["evo", "shell", "bar", "quickshell", "refresh", "restart"], command: evo + " system restart" },
        { name: "Reboot", icon: "󰐥", keywords: ["reboot", "restart", "system"], command: evo + " system reboot" },
        { name: "Shutdown", icon: "󰐥", keywords: ["shutdown", "poweroff", "off", "power"], command: evo + " system shutdown" }
    ]
    var insertAt = raw.length
    for (var m = 0; m < raw.length; m++) {
        if (raw[m].name === "Music") {
            insertAt = m + 1
            break
        }
    }
    if (extensionPanels && extensionPanels.length) {
        for (var i = 0; i < extensionPanels.length; i++) {
            var panel = extensionPanels[i]
            if (!panel)
                continue
            if (String(panel.name || "") === "Shopify") {
                raw.splice(insertAt, 0, panel)
                insertAt++
            } else {
                raw.push(panel)
            }
        }
    }
    return raw.map(mapEntry)
}

function viewEntries() {
    return [
        { kind: "view", name: "Themes", icon: "󰸌", keywords: ["theme", "themes", "colours", "colors", "gtk", "appearance"], view: "themes", section: "Views" },
        { kind: "view", name: "Wallpapers", icon: "󰏘", keywords: ["wallpaper", "wallpapers", "background"], view: "wallpapers", section: "Views" },
        { kind: "view", name: "Clipboard", icon: "󰅍", keywords: ["clipboard", "copy", "paste", "history", "clip"], view: "clipboard", section: "Views" },
        { kind: "view", name: "Emoji", icon: "󰞅", keywords: ["emoji", "emoticon", "glyph", "smiley"], view: "emoji", section: "Views" },
        { kind: "view", name: "Looks", icon: "󰒠", keywords: ["looks", "settings", "appearance", "gaps", "opacity"], view: "looks", section: "Views" }
    ]
}

function mapEntry(entry) {
    var kind = "command"
    if (entry.kind)
        kind = entry.kind
    else if (entry.view)
        kind = "view"
    return {
        kind: kind,
        name: entry.name,
        icon: entry.icon || "",
        keywords: entry.keywords || [],
        command: entry.command || "",
        view: entry.view || "",
        section: entry.section || "Commands"
    }
}

function fuzzyScore(text, query) {
    var value = String(text || "").toLowerCase()
    var needle = String(query || "").toLowerCase()
    if (!value || needle.length < 2)
        return 0
    var ti = 0
    var first = -1
    var streak = 0
    var best = 0
    var gaps = 0
    for (var i = 0; i < value.length && ti < needle.length; i++) {
        if (value.charAt(i) === needle.charAt(ti)) {
            if (first < 0)
                first = i
            streak++
            if (streak > best)
                best = streak
            ti++
        } else if (ti > 0) {
            if (streak > 0)
                gaps++
            streak = 0
        }
    }
    if (ti < needle.length)
        return 0
    var score = 180 + best * 24 - gaps * 8 - Math.min(first, 40)
    if (score < 1)
        score = 1
    if (score > 550)
        score = 550
    return score
}

function scoreText(text, query) {
    if (!query)
        return 0
    var value = String(text || "").toLowerCase()
    var needle = String(query).toLowerCase()
    if (!value || !needle)
        return 0
    if (value === needle)
        return 1000
    if (value.indexOf(needle) === 0)
        return 800
    if (value.indexOf(needle) >= 0)
        return 600
    return fuzzyScore(value, needle)
}

function literalScore(text, query) {
    var value = String(text || "").toLowerCase()
    var needle = String(query || "").toLowerCase()
    if (!value || !needle)
        return 0
    if (value === needle)
        return 1000
    if (value.indexOf(needle) === 0)
        return 800
    if (value.indexOf(needle) >= 0)
        return 500
    return 0
}

function entryMatchScore(entry, query) {
    if (!query || !entry)
        return 0
    var best = 0
    best = Math.max(best, scoreText(entry.name, query))
    best = Math.max(best, scoreText(entry.id, query))
    best = Math.max(best, scoreText(entry.accessory, query))
    best = Math.max(best, scoreText(entry.detail, query))
    // Commands and wallpaper paths are long. Fuzzy matching them pulls in
    // unrelated files whenever the letters happen to appear in order.
    best = Math.max(best, literalScore(entry.command, query))
    if (entry.keywords) {
        for (var i = 0; i < entry.keywords.length; i++)
            best = Math.max(best, scoreText(entry.keywords[i], query))
    }
    return best
}
