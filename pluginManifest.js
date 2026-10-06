.pragma library

function namespaceFromId(id) {
    return String(id || "").replace(/\./g, "-")
}

// Path discovery cannot see: the player lives in the evoplayer repo.
var plugins = {
    "evo.panels.player": {
        kinds: ["dashboard"],
        path: "vendor/evoplayer/plugin/panel/Player.qml"
    },
    "evo.panels.player.monitor": {
        kinds: ["service"],
        path: "vendor/evoplayer/plugin/panel/Service.qml",
        keepLoaded: true
    }
}

var panelPluginIds = [
    "evo.sys.menu",
    "evo.side",
    "evo.sys.settings",
    "evo.panels.network.stats",
    "evo.panels.notifications",
    "evo.sys.themes",
    "evo.sys.wallpaper",
    "evo.side.clipboard"
]

var dashboardIds = ["evo.panels.player"]

function overlayObject(overlay) {
    if (!overlay || typeof overlay !== "object")
        return {}
    return overlay
}

// Kinds a plugin manifest.json may declare, mapped to its entryPoints key.
var manifestEntryPoints = {
    "service": "service",
    "menu": "menu",
    "panel": "panel",
    "overlay": "overlay",
    "dashboard": "dashboard",
    "bar": "bar",
    "bar-widget": "barWidget"
}

var popupKinds = ["menu", "panel", "overlay"]

// Convert one discovered manifest (from bin/evo-modules) into a module table entry.
// Paths stay relative to `dir`; pluginUrl() resolves them.
function tableEntryFromManifest(dir, manifest) {
    var m = manifest || {}
    var entry = m.entryPoints || {}
    var kinds = Array.isArray(m.kinds) ? m.kinds.slice() : []
    var meta = {
        kinds: kinds,
        dir: String(dir || ""),
        keepLoaded: m.keepLoaded === true,
        manifest: m
    }
    for (var i = 0; i < popupKinds.length; i++) {
        var key = manifestEntryPoints[popupKinds[i]]
        if (kinds.indexOf(popupKinds[i]) >= 0 && entry[key]) {
            meta.path = String(entry[key])
            break
        }
    }
    if (kinds.indexOf("dashboard") >= 0 && entry.dashboard)
        meta.path = String(entry.dashboard)
    if (kinds.indexOf("service") >= 0 && entry.service)
        meta.servicePath = String(entry.service)
    if (kinds.indexOf("bar") >= 0 && entry.bar)
        meta.barPath = String(entry.bar)
    if (kinds.indexOf("bar-widget") >= 0 && entry.barWidget)
        meta.barWidgetPath = String(entry.barWidget)
    return meta
}

function discoveredTable(discovered, disabled) {
    var out = {}
    if (!discovered || typeof discovered !== "object")
        return out
    var off = Array.isArray(disabled) ? disabled : []
    for (var id in discovered) {
        if (off.indexOf(id) >= 0)
            continue
        var d = discovered[id] || {}
        out[id] = tableEntryFromManifest(d.dir, d.manifest)
    }
    return out
}

function hasKind(meta, kind) {
    return !!(meta && Array.isArray(meta.kinds) && meta.kinds.indexOf(kind) >= 0)
}

function isPopupPlugin(meta) {
    if (!meta || !meta.path)
        return false
    for (var i = 0; i < popupKinds.length; i++) {
        if (hasKind(meta, popupKinds[i]))
            return true
    }
    return false
}

function mergePlugins(base, overlay, discovered) {
    var merged = {}
    var id
    for (id in base)
        merged[id] = base[id]
    var extra = overlayObject(overlay).plugins
    if (extra) {
        for (id in extra) {
            if (!(id in merged))
                merged[id] = extra[id]
        }
    }
    if (discovered) {
        for (id in discovered) {
            if (!(id in merged))
                merged[id] = discovered[id]
        }
    }
    return merged
}

function appendUnique(out, ids) {
    var seen = {}
    var i
    for (i = 0; i < out.length; i++)
        seen[out[i]] = true
    if (!Array.isArray(ids))
        return out
    for (i = 0; i < ids.length; i++) {
        var id = ids[i]
        if (!seen[id]) {
            seen[id] = true
            out.push(id)
        }
    }
    return out
}

function discoveredIdsWhere(discovered, predicate) {
    var out = []
    if (!discovered)
        return out
    for (var id in discovered) {
        if (predicate(discovered[id]))
            out.push(id)
    }
    out.sort()
    return out
}

function mergePanelPluginIds(base, overlay, discovered) {
    var out = appendUnique(base.slice(), overlayObject(overlay).panelPluginIds)
    return appendUnique(out, discoveredIdsWhere(discovered, isPopupPlugin))
}

function mergeDashboardIds(base, overlay, discovered) {
    var out = appendUnique(base.slice(), overlayObject(overlay).dashboardIds)
    return appendUnique(out, discoveredIdsWhere(discovered, function(meta) {
        return hasKind(meta, "dashboard") && !!meta.path
    }))
}

function discoveredBarWidgets(discovered) {
    return discoveredIdsWhere(discovered, function(meta) {
        return !!meta.barWidgetPath
    })
}

function extensionSettingsTabs(base, overlay) {
    var out = base.slice()
    var extra = overlayObject(overlay).settingsTabs
    if (!Array.isArray(extra))
        return out
    var i
    for (i = 0; i < extra.length; i++) {
        if (extra[i])
            out.push(extra[i])
    }
    return out
}

function extensionDashboardIds(base, overlay, discovered) {
    var all = mergeDashboardIds(base, overlay, discovered)
    var out = []
    var i
    for (i = 0; i < all.length; i++) {
        if (all[i] !== "evo.panels.player")
            out.push(all[i])
    }
    return out
}

function extensionTrayWidgets(overlay) {
    var widgets = overlayObject(overlay).trayWidgets
    if (!widgets || typeof widgets !== "object")
        return {}
    return widgets
}

var builtinTrayWidgetOrder = [
    "volume",
    "media",
    "workspaces",
    "notifications",
    "network"
]

var builtinTrayWidgetLabels = {
    workspaces: "Workspace",
    volume: "Volume",
    media: "Media",
    audio: "Volume",
    weather: "Weather",
    github: "GitHub",
    cursor: "Cursor",
    notifications: "Notifications",
    stocks: "Stocks",
    cloudflare: "Cloudflare",
    network: "Network"
}

var builtinTrayWidgetIcons = {
    workspaces: "󰍹",
    volume: "󰕾",
    media: "󰍹",
    weather: "󰖕",
    github: "󰊤",
    cursor: "󰍽",
    notifications: "󰂚",
    stocks: "󰄖",
    cloudflare: "󰑐",
    network: "󰛖"
}

var builtinBarChromeWidgetOrder = [
    "workspaces"
]

var builtinBarChromeWidgetLabels = {
    workspaces: "Workspace"
}

var builtinBarChromeWidgetIcons = {
    workspaces: "󰍹"
}

function isBarChromeWidgetId(id) {
    return builtinBarChromeWidgetOrder.indexOf(String(id || "")) >= 0
}

function barChromeWidgetSettingsLabel(id) {
    var key = String(id || "")
    if (builtinBarChromeWidgetLabels[key])
        return builtinBarChromeWidgetLabels[key]
    return key
}

function barChromeWidgetSettingsIcon(id) {
    var key = String(id || "")
    if (builtinBarChromeWidgetIcons[key])
        return builtinBarChromeWidgetIcons[key]
    return ""
}

function defaultBarChromeWidgetOrder() {
    return builtinBarChromeWidgetOrder.slice()
}

function normalizeTrayWidgetId(id) {
    var key = String(id || "")
    if (key === "audio")
        return "volume"
    return key
}

var trayWidgetSecretIds = {
    github: true,
    cursor: true,
    cloudflare: true
}

function trayWidgetSettingsOrder(overlay, configOrder) {
    return resolveTrayWidgetOrder(overlay, configOrder)
}

function defaultTrayWidgetOrder(overlay) {
    var order = builtinTrayWidgetOrder.slice()
    var ext = extensionTrayWidgets(overlay)
    var keys = Object.keys(ext)
    var i, id
    for (i = 0; i < keys.length; i++) {
        id = keys[i]
        if (order.indexOf(id) < 0)
            order.push(id)
    }
    return order
}

function resolveTrayWidgetOrder(overlay, configOrder) {
    var defaults = defaultTrayWidgetOrder(overlay)
    if (!Array.isArray(configOrder) || configOrder.length === 0)
        return defaults
    var valid = {}
    var out = []
    var i, id
    for (i = 0; i < defaults.length; i++)
        valid[defaults[i]] = true
    valid.volume = true
    valid.media = true
    for (i = 0; i < configOrder.length; i++) {
        id = normalizeTrayWidgetId(configOrder[i])
        if (valid[id] && out.indexOf(id) < 0)
            out.push(id)
    }
    for (i = 0; i < defaults.length; i++) {
        id = defaults[i]
        if (out.indexOf(id) < 0)
            out.push(id)
    }
    return out
}

function trayWidgetSettingsIcon(id, overlay) {
    var key = normalizeTrayWidgetId(id)
    var ext = extensionTrayWidgets(overlay)
    if (ext[key] && ext[key].icon)
        return String(ext[key].icon)
    if (builtinTrayWidgetIcons[key])
        return builtinTrayWidgetIcons[key]
    return ""
}

function trayWidgetSettingsLabel(id, overlay) {
    var key = String(id || "")
    var ext = extensionTrayWidgets(overlay)
    if (ext[key] && ext[key].label)
        return String(ext[key].label)
    if (builtinTrayWidgetLabels[key])
        return builtinTrayWidgetLabels[key]
    if (!key)
        return ""
    return key.charAt(0).toUpperCase() + key.slice(1)
}

function trayWidgetHasSecret(id) {
    return trayWidgetSecretIds[String(id || "")] === true
}

function startupDashboardLabel(id, overlay) {
    var labels = overlayObject(overlay).startupDashboards
    if (labels && labels[id] && labels[id].label)
        return String(labels[id].label)
    var kind = dashboardPinKind(id, overlay)
    if (kind)
        return kind.charAt(0).toUpperCase() + kind.slice(1)
    var parts = String(id || "").split(".")
    var last = parts[parts.length - 1] || String(id || "")
    if (!last)
        return String(id || "")
    return last.charAt(0).toUpperCase() + last.slice(1)
}

function extensionStartupDashboards(base, overlay, discovered) {
    var ids = extensionDashboardIds(base, overlay, discovered)
    var out = []
    var i
    for (i = 0; i < ids.length; i++) {
        out.push({
            id: ids[i],
            label: startupDashboardLabel(ids[i], overlay)
        })
    }
    return out
}

function evoBin(home) {
    return String(home || "") + "/.local/bin/evo"
}

// Runner entries come from overlay systemMenuPanels plus each discovered manifest's "menu" block.
function systemMenuPanelEntries(home, overlay, discovered) {
    var panels = {}
    var src = overlayObject(overlay).systemMenuPanels
    var id
    if (src && typeof src === "object") {
        for (id in src)
            panels[id] = src[id]
    }
    if (discovered) {
        for (id in discovered) {
            var m = discovered[id] && discovered[id].manifest
            if (m && m.menu && typeof m.menu === "object" && !(id in panels))
                panels[id] = { name: m.menu.name || m.name, icon: m.menu.icon, keywords: m.menu.keywords }
        }
    }
    var out = []
    for (id in panels) {
        if (!Object.prototype.hasOwnProperty.call(panels, id))
            continue
        var entry = panels[id] || {}
        var name = entry.name ? String(entry.name) : startupDashboardLabel(id, overlay)
        var icon = entry.icon ? String(entry.icon) : "󰐒"
        var keywords = Array.isArray(entry.keywords) ? entry.keywords.slice() : []
        out.push({
            name: name,
            icon: icon,
            keywords: keywords,
            command: evoBin(home) + " ipc shell toggle " + id
        })
    }
    return out
}

function dashboardPinKind(id, overlay) {
    if (id === "evo.panels.player") return "player"
    var pins = overlayObject(overlay).dashboardPinKinds
    if (pins && pins[id])
        return String(pins[id])
    return ""
}
