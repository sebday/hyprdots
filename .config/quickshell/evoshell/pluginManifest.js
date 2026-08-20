.pragma library

function namespaceFromId(id) {
    return String(id || "").replace(/\./g, "-")
}

var plugins = {
    "evo.sys.wallpaper": {
        kinds: ["menu", "service"],
        path: "Evosys/Wallpaper/Picker.qml",
        servicePath: "Evosys/Wallpaper/Service.qml",
        keepLoaded: true
    },
    "evo.bar.media.audio": {
        kinds: ["service"],
        path: "Evobar/Media/Audio/Service.qml",
        keepLoaded: true
    },
    "evo.sys.lock-screen.idle": {
        kinds: ["service"],
        path: "Evosys/LockScreen/IdleService.qml"
    },
    "evo.sys.lock-screen.lock": {
        kinds: ["service"],
        path: "Evosys/LockScreen/LockService.qml",
        keepLoaded: true
    },
    "evo.sys.notifications": {
        kinds: ["service"],
        path: "Evosys/Notifications/Service.qml",
        keepLoaded: true
    },
    "evo.sys.menu": {
        kinds: ["menu"],
        path: "Evosys/Menu/Menu.qml",
        keepLoaded: true
    },
    "evo.bar.popups.calendar": {
        kinds: ["menu"],
        path: "Evobar/Popups/Calendar/Calendar.qml",
        keepLoaded: true
    },
    "evo.bar.popups.cursor-usage": {
        kinds: ["menu"],
        path: "Evobar/Popups/CursorUsage/Cursor.qml",
        keepLoaded: true
    },
    "evo.bar.popups.weather": {
        kinds: ["menu"],
        path: "Evobar/Popups/Weather/Weather.qml",
        keepLoaded: true
    },
    "evo.bar.network.stats": {
        kinds: ["menu"],
        path: "Evobar/Network/Stats/Network.qml",
        keepLoaded: true
    },
    "evo.bar.media.volume": {
        kinds: ["menu"],
        path: "Evobar/Media/Volume/Volume.qml",
        keepLoaded: true
    },
    "evo.bar.media.now-playing": {
        kinds: ["menu"],
        path: "Evobar/Media/NowPlaying/Media.qml",
        keepLoaded: true
    },
    "evo.bar.popups.github": {
        kinds: ["menu"],
        path: "Evobar/Popups/GitHub/Github.qml",
        keepLoaded: true
    },
    "evo.bar.popups.system-stats": {
        kinds: ["menu"],
        path: "Evobar/Popups/SystemStats/System.qml",
        keepLoaded: true
    },
    "evo.bar.network.transmission": {
        kinds: ["menu"],
        path: "Evobar/Network/Transmission/Transmission.qml",
        keepLoaded: true
    },
    "evo.bar.popups.insync": {
        kinds: ["menu"],
        path: "Evobar/Popups/Insync/Insync.qml",
        keepLoaded: true
    },
    "evo.bar.steam": {
        kinds: ["menu"],
        path: "Evobar/Steam/Steam.qml",
        keepLoaded: true
    },
    "evo.bar.popups.stocks": {
        kinds: ["menu"],
        path: "Evobar/Popups/Stocks/Stocks.qml",
        keepLoaded: true
    },
    "evo.bar.popups.cloudflare": {
        kinds: ["menu", "service"],
        path: "Evobar/Popups/Cloudflare/Cloudflare.qml",
        servicePath: "Evobar/Popups/Cloudflare/CloudflareService.qml",
        keepLoaded: true
    },
    "evo.bar.media.library": {
        kinds: ["menu"],
        path: "Evobar/Media/Library/Library.qml",
        keepLoaded: true
    },
    "evo.sys.themes": {
        kinds: ["menu"],
        path: "Evosys/Themes/Theme.qml",
        keepLoaded: true
    },
    "evo.side.clipboard": {
        kinds: ["menu", "service"],
        path: "Evoside/Clipboard/Clipboard.qml",
        servicePath: "Evoside/Clipboard/Service.qml",
        keepLoaded: true
    },
    "evo.sys.settings": {
        kinds: ["menu"],
        path: "Evosys/Settings/Settings.qml",
        keepLoaded: true
    },
    "evo.side": {
        kinds: ["panel"],
        path: "Evoside/Evoside.qml",
        keepLoaded: true
    },
    "evo.bar": {
        kinds: ["bar"],
        path: "Evobar/Bar.qml"
    },
    "evo.panel.shopify": {
        kinds: ["dashboard"],
        path: "Evopanel/Shopify/Shopify.qml"
    },
    "evo.panel.player": {
        kinds: ["dashboard"],
        path: "Evopanel/Evoplayer/Player.qml"
    },
    "evo.panel.player.monitor": {
        kinds: ["service"],
        path: "Evopanel/Evoplayer/Service.qml",
        keepLoaded: true
    }
}

var panelPluginIds = [
    "evo.sys.menu",
    "evo.side",
    "evo.sys.settings",
    "evo.bar.popups.calendar",
    "evo.bar.popups.cursor-usage",
    "evo.bar.popups.weather",
    "evo.bar.network.stats",
    "evo.bar.media.volume",
    "evo.bar.media.now-playing",
    "evo.bar.popups.github",
    "evo.bar.popups.system-stats",
    "evo.bar.popups.stocks",
    "evo.bar.popups.cloudflare",
    "evo.bar.network.transmission",
    "evo.bar.popups.insync",
    "evo.bar.steam",
    "evo.bar.media.library",
    "evo.sys.themes",
    "evo.sys.wallpaper",
    "evo.side.clipboard"
]

var dashboardIds = ["evo.panel.shopify", "evo.panel.player"]

function dashboardPinKind(id) {
    if (id === "evo.panel.shopify") return "shopify"
    if (id === "evo.panel.player") return "player"
    return ""
}
