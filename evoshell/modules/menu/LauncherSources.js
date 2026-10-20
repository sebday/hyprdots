.pragma library
.import "MenuEntries.js" as MenuEntries

function runCount(counts, id) {
    if (!counts || !id)
        return 0
    var n = counts[id]
    if (typeof n === "number")
        return n
    return parseInt(n, 10) || 0
}

function markGroups(list) {
    var last = ""
    for (var i = 0; i < list.length; i++) {
        var entry = list[i]
        if (!entry)
            continue
        var group = String(entry.group || "")
        entry.showGroup = group !== "" && group !== last
        if (group !== "")
            last = group
    }
    return list
}

function tag(list, group) {
    var out = []
    for (var i = 0; i < list.length; i++) {
        var src = list[i]
        if (!src)
            continue
        var copy = {}
        for (var key in src) {
            if (key === "section")
                continue
            copy[key] = src[key]
        }
        copy.group = group
        out.push(copy)
    }
    return out
}

function sortByScore(list, query, counts) {
    var decorated = []
    for (var i = 0; i < list.length; i++) {
        var entry = list[i]
        var score = query ? MenuEntries.entryMatchScore(entry, query) : 1
        if (query && score <= 0)
            continue
        decorated.push({
            entry: entry,
            score: score,
            runs: runCount(counts, entry.id)
        })
    }
    decorated.sort(function(a, b) {
        if (a.score !== b.score)
            return b.score - a.score
        if (a.runs !== b.runs)
            return b.runs - a.runs
        return String(a.entry.name || "").localeCompare(String(b.entry.name || ""))
    })
    var out = []
    for (var j = 0; j < decorated.length; j++)
        out.push(decorated[j].entry)
    return out
}

function sortByUse(list, counts) {
    var copy = list.slice()
    copy.sort(function(a, b) {
        var ra = runCount(counts, a.id)
        var rb = runCount(counts, b.id)
        if (ra !== rb)
            return rb - ra
        return String(a.name || "").localeCompare(String(b.name || ""))
    })
    return copy
}

function take(list, limit) {
    if (!limit || list.length <= limit)
        return list
    return list.slice(0, limit)
}

function settingsActions(state) {
    state = state || {}
    function onOff(value) {
        return value ? "On" : "Off"
    }
    return [
        {
            kind: "setting",
            id: "toggle-gaps",
            name: "Toggle gaps",
            icon: "󰩌",
            keywords: ["gaps", "window", "spacing", "looks"],
            accessory: onOff(state.gapsOn === true),
            action: "toggleHypr",
            arg: "gaps",
            section: "Settings"
        },
        {
            kind: "setting",
            id: "toggle-animations",
            name: "Toggle animations",
            icon: "󰅁",
            keywords: ["animations", "motion", "looks"],
            accessory: onOff(state.animationsOn === true),
            action: "toggleHypr",
            arg: "animations",
            section: "Settings"
        },
        {
            kind: "setting",
            id: "toggle-rounding",
            name: "Toggle border radius",
            icon: "󰩊",
            keywords: ["radius", "rounding", "border", "corner", "looks"],
            accessory: onOff(state.roundingOn === true),
            action: "toggleHypr",
            arg: "rounding",
            section: "Settings"
        },
        {
            kind: "setting",
            id: "toggle-fieldset",
            name: "Toggle fieldset radius",
            icon: "󰩊",
            keywords: ["fieldset", "radius", "rounding", "corner", "looks"],
            accessory: onOff(state.fieldsetRoundingOn !== false),
            action: "toggleFieldsetRounding",
            arg: "",
            section: "Settings"
        },
        {
            kind: "setting",
            id: "opacity",
            name: "Opacity",
            icon: "󰂎",
            keywords: ["opacity", "transparency", "transparent", "active", "inactive", "looks"],
            view: "looks",
            section: "Settings"
        }
    ]
}

function skipSpace(state) {
    var s = state.s
    while (state.i < s.length && s.charAt(state.i) === " ")
        state.i++
}

function parseFactor(state) {
    skipSpace(state)
    var s = state.s
    if (state.i >= s.length)
        return null
    var ch = s.charAt(state.i)
    if (ch === "+" || ch === "-") {
        state.i++
        var signed = parseFactor(state)
        if (signed === null)
            return null
        return ch === "-" ? -signed : signed
    }
    if (ch === "(") {
        state.i++
        var inner = parseExpression(state)
        skipSpace(state)
        if (inner === null || s.charAt(state.i) !== ")")
            return null
        state.i++
        return inner
    }
    var start = state.i
    if (ch === ".")
        state.i++
    var sawDigit = false
    while (state.i < s.length) {
        var c = s.charAt(state.i)
        if (c >= "0" && c <= "9") {
            sawDigit = true
            state.i++
            continue
        }
        if (c === ".") {
            state.i++
            continue
        }
        break
    }
    if (!sawDigit || state.i === start)
        return null
    var num = Number(s.slice(start, state.i))
    if (!isFinite(num))
        return null
    return num
}

function parseTerm(state) {
    var value = parseFactor(state)
    if (value === null)
        return null
    while (true) {
        skipSpace(state)
        var op = state.s.charAt(state.i)
        if (op !== "*" && op !== "/")
            break
        state.i++
        var right = parseFactor(state)
        if (right === null)
            return null
        if (op === "/") {
            if (right === 0)
                return null
            value = value / right
        } else {
            value = value * right
        }
    }
    return value
}

function parseExpression(state) {
    var value = parseTerm(state)
    if (value === null)
        return null
    while (true) {
        skipSpace(state)
        var op = state.s.charAt(state.i)
        if (op !== "+" && op !== "-")
            break
        state.i++
        var right = parseTerm(state)
        if (right === null)
            return null
        value = op === "+" ? value + right : value - right
    }
    return value
}

function formatNumber(value) {
    if (!isFinite(value) || Math.abs(value) > 1e15)
        return ""
    var rounded = Math.round(value * 1e10) / 1e10
    var text = String(rounded)
    if (text.indexOf("e") >= 0 || text.indexOf("E") >= 0)
        return text
    if (text.indexOf(".") >= 0)
        text = text.replace(/0+$/, "").replace(/\.$/, "")
    return text
}

function calculatorEntry(query) {
    var q = String(query || "").trim()
    if (!q || q.length > 96)
        return null
    if (!/^[0-9+*/().\sxX×-]+$/.test(q))
        return null
    if (!/[+*/xX×]/.test(q) && !/\d\s*-\s*\d/.test(q) && !/\)\s*-/.test(q))
        return null
    var expr = q.replace(/×/g, "*").replace(/([0-9.)])[xX]([0-9.(])/g, "$1*$2")
    var state = { s: expr, i: 0 }
    var value = parseExpression(state)
    skipSpace(state)
    if (value === null || state.i !== expr.length)
        return null
    var text = formatNumber(value)
    if (!text)
        return null
    return {
        kind: "calc",
        name: text,
        icon: "󰪚",
        accessory: q,
        expr: q,
        result: text,
        group: "Calculator"
    }
}

function buildRoot(query, apps, counts, commands, settings, themes, wallpapers) {
    var q = String(query || "").trim()
    var out = []
    if (!q) {
        out = out.concat(tag(sortByUse(apps || [], counts), "Apps"))
        out = out.concat(tag(MenuEntries.viewEntries(), "Views"))
        out = out.concat(tag(commands || [], "Commands"))
        return markGroups(out)
    }
    var calc = calculatorEntry(q)
    if (calc)
        out.push(calc)
    out = out.concat(tag(sortByScore(apps || [], q, counts), "Apps"))
    out = out.concat(tag(sortByScore(commands || [], q, counts), "Commands"))
    out = out.concat(tag(sortByScore(settingsActions(settings), q, null), "Settings"))
    out = out.concat(tag(take(sortByScore(themes || [], q, null), 6), "Themes"))
    out = out.concat(tag(take(sortByScore(wallpapers || [], q, null), 6), "Wallpapers"))
    out = out.concat(tag(sortByScore(MenuEntries.viewEntries(), q, null), "Views"))
    return markGroups(out)
}

function filterEntries(entries, query) {
    return sortByScore(entries || [], String(query || "").trim(), null)
}

function withCurrent(entries, isCurrent) {
    var out = []
    for (var i = 0; i < entries.length; i++) {
        var src = entries[i]
        var copy = {}
        for (var key in src)
            copy[key] = src[key]
        copy.current = isCurrent(src) === true
        out.push(copy)
    }
    return out
}

function filterThemes(entries, query, currentName) {
    var matched = filterEntries(entries, query)
    var name = String(currentName || "").trim()
    return withCurrent(matched, function(entry) {
        return name !== "" && String(entry.name || "") === name
    })
}

function filterWallpapers(entries, query, filter, currentTheme, currentPath) {
    var mode = String(filter || "current")
    var theme = String(currentTheme || "").trim()
    var path = String(currentPath || "").trim()
    var scoped = []
    var list = entries || []
    for (var i = 0; i < list.length; i++) {
        var entry = list[i]
        var label = String(entry.name || "")
        var personal = label.indexOf("personal/") === 0
        var themeName = label.split("/")[0]
        if (mode === "personal" && !personal)
            continue
        if (mode === "current" && theme && (personal || themeName !== theme))
            continue
        scoped.push(entry)
    }
    var matched = filterEntries(scoped, query)
    return withCurrent(matched, function(entry) {
        var entryPath = String(entry.path || "")
        if (!path || !entryPath)
            return false
        return path === entryPath || path.endsWith("/" + entryPath.split("/").pop())
    })
}

function emojiMatches(item, query) {
    if (!query)
        return true
    var needle = String(query).toLowerCase()
    if (String(item.n || "").toLowerCase().indexOf(needle) >= 0)
        return true
    var words = item.k || []
    for (var i = 0; i < words.length; i++) {
        var word = String(words[i] || "").toLowerCase()
        if (word.indexOf(needle) === 0 || word === needle)
            return true
    }
    return MenuEntries.fuzzyScore(item.n, needle) > 0
}

function emojiEntry(item, recent) {
    return {
        kind: "emoji",
        name: String(item.n || ""),
        emoji: String(item.c || ""),
        icon: String(item.c || ""),
        keywords: item.k || [],
        recent: recent === true,
        section: recent ? "Recent" : "Emoji"
    }
}

function filterEmoji(all, query, recents) {
    var q = String(query || "").trim()
    var items = all || []
    var recentChars = recents || []
    var byChar = {}
    for (var i = 0; i < items.length; i++)
        byChar[items[i].c] = items[i]
    var out = []
    var seen = {}
    for (var r = 0; r < recentChars.length; r++) {
        var ch = String(recentChars[r] || "")
        var recentItem = byChar[ch]
        if (!recentItem || !emojiMatches(recentItem, q))
            continue
        seen[ch] = true
        out.push(emojiEntry(recentItem, true))
    }
    for (var j = 0; j < items.length; j++) {
        var item = items[j]
        if (!item || seen[item.c])
            continue
        if (!emojiMatches(item, q))
            continue
        out.push(emojiEntry(item, false))
    }
    return out
}

function actionsFor(entry) {
    if (!entry)
        return []
    switch (entry.kind) {
    case "app":
        return [
            { id: "launch", label: "Open" },
            { id: "launch-terminal", label: "Open in terminal", key: "t" }
        ]
    case "theme":
        return [{ id: "apply", label: "Apply" }]
    case "wallpaper":
        return [{ id: "set", label: "Set wallpaper" }]
    case "clipboard":
        return [
            { id: "copy", label: "Copy" },
            { id: "pin", label: entry.pinned ? "Unpin" : "Pin", key: "p" },
            { id: "delete", label: "Delete", key: "backspace" }
        ]
    case "emoji":
        return [
            { id: "copy", label: "Copy" },
            { id: "type", label: "Type", key: "t" }
        ]
    case "calc":
        return [{ id: "copy", label: "Copy result" }]
    case "setting":
        return [{ id: "run", label: entry.view ? "Open" : "Toggle" }]
    case "view":
        return [{ id: "open", label: "Open" }]
    default:
        return [{ id: "run", label: "Run" }]
    }
}

function primaryHint(entry) {
    var actions = actionsFor(entry)
    if (actions.length === 0)
        return "Open"
    return actions[0].label
}

function wallpaperPath(command) {
    var text = String(command || "")
    var marker = "evo-wallpaper set "
    var pos = text.indexOf(marker)
    if (pos < 0)
        return ""
    var tail = text.slice(pos + marker.length).trim()
    if (tail.length >= 2 && tail.charAt(0) === "'" && tail.charAt(tail.length - 1) === "'")
        tail = tail.slice(1, -1).replace(/'\\''/g, "'")
    return tail
}

function parseCatalog(raw, kind) {
    var lines = String(raw || "").split("\n")
    var out = []
    var section = kind === "wallpaper" ? "Wallpapers" : "Themes"
    var icon = kind === "wallpaper" ? "󰏘" : "󰸌"
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (!line)
            continue
        var parts = line.split("\t")
        var name = parts[0] || ""
        var command = parts[1] || ""
        out.push({
            kind: kind,
            name: name,
            command: command,
            preview: parts[2] || "",
            icon: icon,
            path: kind === "wallpaper" ? wallpaperPath(command) : "",
            keywords: name.split(/[\/._-]+/),
            section: section
        })
    }
    return out
}
