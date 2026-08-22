.pragma library

function namespaceFromId(id) {
    return String(id || "").replace(/\./g, "-")
}

var plugins = {
    "evo.sys.wallpaper": {
        kinds: ["menu", "service"],
        path: "evosys/wallpaper/Picker.qml",
        servicePath: "evosys/wallpaper/Service.qml",
        keepLoaded: true
    },
    "evo.sys.media.audio": {
        kinds: ["service"],
        path: "evosys/media/audio/Service.qml",
        keepLoaded: true
    },
    "evo.sys.lock-screen.idle": {
        kinds: ["service"],
        path: "evosys/lockscreen/IdleService.qml"
    },
    "evo.sys.lock-screen.lock": {
        kinds: ["service"],
        path: "evosys/lockscreen/LockService.qml",
        keepLoaded: true
    },
    "evo.sys.notifications": {
        kinds: ["service"],
        path: "evosys/notifications/Service.qml",
        keepLoaded: true
    },
    "evo.sys.menu": {
        kinds: ["menu"],
        path: "evosys/menu/Menu.qml",
        keepLoaded: true
    },
    "evo.panels.calendar": {
        kinds: ["menu"],
        path: "evopanels/calendar/Calendar.qml",
        keepLoaded: true
    },
    "evo.panels.cursor": {
        kinds: ["menu"],
        path: "evopanels/cursor/Cursor.qml",
        keepLoaded: true
    },
    "evo.panels.weather": {
        kinds: ["menu"],
        path: "evopanels/weather/Weather.qml",
        keepLoaded: true
    },
    "evo.panels.network.stats": {
        kinds: ["menu"],
        path: "evopanels/network/stats/Network.qml",
        keepLoaded: true
    },
    "evo.panels.media.volume": {
        kinds: ["menu"],
        path: "evopanels/media/volume/Volume.qml",
        keepLoaded: true
    },
    "evo.panels.media.now-playing": {
        kinds: ["menu"],
        path: "evopanels/media/now-playing/Media.qml",
        keepLoaded: true
    },
    "evo.panels.github": {
        kinds: ["menu"],
        path: "evopanels/github/GitHub.qml",
        keepLoaded: true
    },
    "evo.panels.system": {
        kinds: ["menu"],
        path: "evopanels/system/System.qml",
        keepLoaded: true
    },
    "evo.panels.network.transmission": {
        kinds: ["menu"],
        path: "evopanels/network/transmission/Transmission.qml",
        keepLoaded: true
    },
    "evo.panels.insync": {
        kinds: ["menu"],
        path: "evopanels/insync/Insync.qml",
        keepLoaded: true
    },
    "evo.panels.notifications": {
        kinds: ["menu"],
        path: "evopanels/notifications/Notifications.qml",
        keepLoaded: true
    },
    "evo.panels.steam": {
        kinds: ["menu"],
        path: "evopanels/steam/Steam.qml",
        keepLoaded: true
    },
    "evo.panels.stocks": {
        kinds: ["menu"],
        path: "evopanels/stocks/Stocks.qml",
        keepLoaded: true
    },
    "evo.panels.cloudflare": {
        kinds: ["menu", "service"],
        path: "evopanels/cloudflare/Cloudflare.qml",
        servicePath: "evopanels/cloudflare/CloudflareService.qml",
        keepLoaded: true
    },
    "evo.panels.homeassistant": {
        kinds: ["menu", "service"],
        path: "evopanels/homeassistant/HomeAssistant.qml",
        servicePath: "evopanels/homeassistant/HomeAssistantService.qml",
        keepLoaded: true
    },
    "evo.panels.media.library": {
        kinds: ["menu"],
        path: "evopanels/media/library/Library.qml",
        keepLoaded: true
    },
    "evo.sys.themes": {
        kinds: ["menu"],
        path: "evosys/themes/Theme.qml",
        keepLoaded: true
    },
    "evo.side.clipboard": {
        kinds: ["menu", "service"],
        path: "evoside/clipboard/Clipboard.qml",
        servicePath: "evoside/clipboard/Service.qml",
        keepLoaded: true
    },
    "evo.sys.settings": {
        kinds: ["menu"],
        path: "evosys/settings/Settings.qml",
        keepLoaded: true
    },
    "evo.side": {
        kinds: ["panel"],
        path: "evoside/Side.qml",
        keepLoaded: true
    },
    "evo.bar": {
        kinds: ["bar"],
        path: "evobar/Bar.qml"
    },
    "evo.panels.player": {
        kinds: ["dashboard"],
        path: "vendor/evoplayer/qml/panel/Player.qml"
    },
    "evo.panels.player.monitor": {
        kinds: ["service"],
        path: "vendor/evoplayer/qml/panel/Service.qml",
        keepLoaded: true
    }
}

var panelPluginIds = [
    "evo.sys.menu",
    "evo.side",
    "evo.sys.settings",
    "evo.panels.calendar",
    "evo.panels.cursor",
    "evo.panels.weather",
    "evo.panels.network.stats",
    "evo.panels.media.volume",
    "evo.panels.media.now-playing",
    "evo.panels.github",
    "evo.panels.system",
    "evo.panels.stocks",
    "evo.panels.cloudflare",
    "evo.panels.homeassistant",
    "evo.panels.network.transmission",
    "evo.panels.insync",
    "evo.panels.notifications",
    "evo.panels.steam",
    "evo.panels.media.library",
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

function mergePlugins(base, overlay) {
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
    return merged
}

function mergePanelPluginIds(base, overlay) {
    var out = base.slice()
    var seen = {}
    var i
    for (i = 0; i < out.length; i++)
        seen[out[i]] = true
    var extra = overlayObject(overlay).panelPluginIds
    if (Array.isArray(extra)) {
        for (i = 0; i < extra.length; i++) {
            var id = extra[i]
            if (!seen[id]) {
                seen[id] = true
                out.push(id)
            }
        }
    }
    return out
}

function mergeDashboardIds(base, overlay) {
    var out = base.slice()
    var seen = {}
    var i
    for (i = 0; i < out.length; i++)
        seen[out[i]] = true
    var extra = overlayObject(overlay).dashboardIds
    if (Array.isArray(extra)) {
        for (i = 0; i < extra.length; i++) {
            var id = extra[i]
            if (!seen[id]) {
                seen[id] = true
                out.push(id)
            }
        }
    }
    return out
}

function extensionDashboardIds(base, overlay) {
    var all = mergeDashboardIds(base, overlay)
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
    "weather",
    "homeAssistant",
    "github",
    "notifications",
    "stocks",
    "cursor",
    "cloudflare",
    "network"
]

var builtinTrayWidgetLabels = {
    volume: "Volume",
    media: "Media",
    audio: "Volume",
    weather: "Weather",
    github: "GitHub",
    cursor: "Cursor",
    notifications: "Notifications",
    stocks: "Stocks",
    cloudflare: "Cloudflare",
    homeAssistant: "Home Assistant",
    network: "Network"
}

var builtinTrayWidgetIcons = {
    volume: "󰕾",
    media: "󰍹",
    weather: "󰖕",
    github: "󰊤",
    cursor: "󰍽",
    notifications: "󰂚",
    stocks: "󰄖",
    cloudflare: "󰑐",
    homeAssistant: "󰠵",
    network: "󰛖"
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
    cloudflare: true,
    homeAssistant: true
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

function extensionStartupDashboards(base, overlay) {
    var ids = extensionDashboardIds(base, overlay)
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

function systemMenuPanelEntries(home, overlay) {
    var panels = overlayObject(overlay).systemMenuPanels
    if (!panels || typeof panels !== "object")
        return []
    var out = []
    var id
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
