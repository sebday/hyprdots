import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Io
import "./Commons"

ShellRoot {
    id: shell

    readonly property string home: Quickshell.env("HOME")
    readonly property string shellDir: Quickshell.shellDir
    readonly property string userConfigPath: shellDir + "/shell.json"

    readonly property var builtinShellConfig: ({
        version: 1,
        idle: { screensaver: 1800, lock: 900 },
        notifications: { durationMs: 3000 },
        panel: { side: "left" },
        bar: {
            id: "evo.bar",
            position: "bottom",
            layout: {
                left: [{ id: "evo.menu" }],
                center: [{ id: "evo.clock", format: "%a %d %H:%M" }],
                right: [{ id: "evo.audio" }, { id: "evo.tray" }]
            }
        }
    })

    readonly property var pluginTable: ({
        "evo.wallpaper": { kinds: ["menu", "service"], path: "plugins/wallpaper/Picker.qml", servicePath: "plugins/wallpaper/Service.qml", keepLoaded: true },
        "evo.audio": { kinds: ["service"], path: "plugins/audio/Service.qml", keepLoaded: true },
        "evo.idle": { kinds: ["service"], path: "plugins/idle/Service.qml" },
        "evo.lock": { kinds: ["service"], path: "plugins/lock/Service.qml", keepLoaded: true },
        "evo.notifications": { kinds: ["service"], path: "plugins/notifications/Service.qml", keepLoaded: true },
        "evo.menu": { kinds: ["menu"], path: "plugins/menu/Menu.qml", keepLoaded: true },
        "evo.calendar": { kinds: ["menu"], path: "plugins/calendar/Calendar.qml", keepLoaded: true },
        "evo.shopify_diy": { kinds: ["menu"], path: "plugins/shopify/ShopifyDiy.qml", keepLoaded: true },
        "evo.shopify_tgs": { kinds: ["menu"], path: "plugins/shopify/ShopifyTgs.qml", keepLoaded: true },
        "evo.cursor": { kinds: ["menu"], path: "plugins/cursor/Cursor.qml", keepLoaded: true },
        "evo.weather": { kinds: ["menu"], path: "plugins/weather/Weather.qml", keepLoaded: true },
        "evo.network": { kinds: ["menu"], path: "plugins/network/Network.qml", keepLoaded: true },
        "evo.volume": { kinds: ["menu"], path: "plugins/volume/Volume.qml", keepLoaded: true },
        "evo.media": { kinds: ["menu"], path: "plugins/media/Media.qml", keepLoaded: true },
        "evo.github": { kinds: ["menu"], path: "plugins/github/Github.qml", keepLoaded: true },
        "evo.system": { kinds: ["menu"], path: "plugins/system/System.qml", keepLoaded: true },
        "evo.transmission": { kinds: ["menu"], path: "plugins/transmission/Transmission.qml", keepLoaded: true },
        "evo.transmission.add": { kinds: ["menu"], path: "plugins/transmission/TransmissionAdd.qml", keepLoaded: true },
        "evo.stocks": { kinds: ["menu"], path: "plugins/stocks/Stocks.qml", keepLoaded: true },
        "evo.cloudflare": { kinds: ["menu", "service"], path: "plugins/cloudflare/Cloudflare.qml", servicePath: "plugins/cloudflare/CloudflareService.qml", keepLoaded: true },
        "evo.library": { kinds: ["menu"], path: "plugins/library/Library.qml", keepLoaded: true },
        "evo.clipboard": { kinds: ["menu", "service"], path: "plugins/clipboard/Clipboard.qml", servicePath: "plugins/clipboard/Service.qml", keepLoaded: true },
        "evo.panel": { kinds: ["panel"], path: "plugins/panel/Panel.qml", keepLoaded: true },
        "evo.bar": { kinds: ["bar"], path: "plugins/bar/Bar.qml" },
        "evo.shopify": { kinds: ["dashboard"], path: "plugins/shopify/Shopify.qml", keepLoaded: true },
        "evo.player": { kinds: ["dashboard"], path: "plugins/player/Player.qml", keepLoaded: true }
    })

    property var shellConfig: builtinShellConfig
    property var barConfig: builtinShellConfig.bar
    property string _barLoaderKey: ""
    property bool _barReloadPending: false
    property var _services: ({})
    property var openPanelIds: ({})
    property var panelLoaders: ({})
    property var pendingPayloads: ({})
    property var popupAnchorItem: null
    property var popupAnchorWindow: null
    property string hoverPopupId: ""
    property string pendingHoverId: ""
    property var pendingHoverItem: null
    property var pendingHoverWindow: null
    property var hoverPopupData: ({})
    property string peekHoverId: ""

    function setHoverPopupData(key, json) {
        var id = String(key || "")
        if (!id || !Util.isPlainObject(json))
            return
        var next = ({})
        for (var k in hoverPopupData)
            next[k] = hoverPopupData[k]
        next[id] = json
        hoverPopupData = next
    }

    function hoverPopupDataFor(key) {
        var id = String(key || "")
        if (!id)
            return null
        return hoverPopupData[id] || null
    }

    FileView {
        id: userConfigFile
        path: shell.userConfigPath
        watchChanges: true
        printErrors: false
        onLoaded: shell.applyShellConfig()
        onLoadFailed: shell.applyShellConfig()
        onFileChanged: reload()
    }

    function applyShellConfig() {
        var text = userConfigFile.text() || ""
        if (!text.trim()) {
            shellConfig = builtinShellConfig
        } else {
            try {
                var parsed = JSON.parse(text)
                if (Util.isPlainObject(parsed) && parsed.version === 1) shellConfig = parsed
                else shellConfig = builtinShellConfig
            } catch (e) {
                shellConfig = builtinShellConfig
            }
        }
        barConfig = Util.isPlainObject(shellConfig.bar) ? shellConfig.bar : builtinShellConfig.bar
        syncServices()
        reloadBar()
    }

    function pluginUrl(relPath) {
        return shell.shellDir + "/" + relPath
    }

    function syncServices() {
        for (var id in pluginTable) {
            var meta = pluginTable[id]
            if (!meta || meta.kinds.indexOf("service") === -1) continue
            if (_services[id]) continue
            ensureService(id, meta)
        }
    }

    function ensureService(id, meta) {
        var relPath = meta.servicePath || meta.path
        var url = pluginUrl(relPath)
        var comp = Qt.createComponent(url, Component.PreferSynchronous)
        if (comp.status !== Component.Ready) {
            console.warn("service load failed", id, comp.errorString())
            return
        }
        var inst = comp.createObject(serviceHost, { shell: shell })
        if (!inst) return
        var next = ({})
        for (var k in _services) next[k] = _services[k]
        next[id] = inst
        _services = next
    }

    function serviceFor(id) {
        return _services[String(id)] || null
    }

    function canonicalPluginId(id) {
        return String(id || "")
    }

    function dashboardLoaderFor(id) {
        var pluginId = canonicalPluginId(id)
        if (pluginId === "evo.shopify") return shopifyLoader
        if (pluginId === "evo.player") return playerLoader
        return null
    }

    function pinKindForDashboard(id) {
        var pluginId = canonicalPluginId(id)
        if (pluginId === "evo.shopify") return "shopify"
        if (pluginId === "evo.player") return "player"
        return ""
    }

    function openDashboardOnly(pluginId) {
        var dash = dashboardLoaderFor(pluginId)
        if (!dash || !dash.item || typeof dash.item.open !== "function")
            return false
        dash.item.open()
        return true
    }

    function revealDashboard(pluginId) {
        var dash = dashboardLoaderFor(pluginId)
        if (!dash || !dash.item || typeof dash.item.open !== "function")
            return false
        dash.item.open()
        return true
    }

    function summon(id, payloadJson) {
        var pluginId = canonicalPluginId(id)
        var dash = dashboardLoaderFor(pluginId)
        if (dash && dash.item && typeof dash.item.open === "function") {
            revealDashboard(pluginId)
            return true
        }
        var meta = pluginTable[pluginId]
        if (!meta) return false
        if (meta.kinds.indexOf("menu") !== -1 || meta.kinds.indexOf("panel") !== -1) {
            var next = ({})
            for (var k in openPanelIds) next[k] = openPanelIds[k]
            next[pluginId] = true
            openPanelIds = next
            var pending = ({})
            for (var p in pendingPayloads) pending[p] = pendingPayloads[p].slice()
            var queue = pending[pluginId] || []
            queue.push(payloadJson || "")
            pending[pluginId] = queue
            pendingPayloads = pending
            deliverIfLoaded(pluginId)
            return true
        }
        return false
    }

    function hide(id) {
        var pluginId = canonicalPluginId(id)
        var dash = dashboardLoaderFor(pluginId)
        if (dash && dash.item && typeof dash.item.close === "function") {
            dash.item.close()
            return true
        }
        if (hoverPopupId === pluginId) {
            hoverPopupId = ""
            popupAnchorItem = null
            popupAnchorWindow = null
        }
        if (!openPanelIds[pluginId] && !isPluginOpen(pluginId)) return true
        var next = ({})
        for (var k in openPanelIds) if (k !== pluginId) next[k] = openPanelIds[k]
        openPanelIds = next
        invokeIfLoaded(pluginId, "close", null)
        return true
    }

    function peekHoverPopup(id, item, barPanel, durationMs) {
        var pluginId = canonicalPluginId(id)
        hoverShowTimer.stop()
        hoverHideTimer.stop()
        pendingHoverId = ""
        pendingHoverItem = null
        pendingHoverWindow = null
        var previous = hoverPopupId
        if (previous && previous !== pluginId)
            hide(previous)
        hoverPopupId = pluginId
        peekHoverId = pluginId
        popupAnchorItem = item
        popupAnchorWindow = barPanel
        if (!isPluginOpen(pluginId))
            summon(pluginId, "")
        peekHideTimer.interval = durationMs > 0 ? durationMs : 2200
        peekHideTimer.restart()
    }

    function clearPeekHover() {
        var id = peekHoverId
        if (!id)
            return
        peekHoverId = ""
        peekHideTimer.stop()
        if (hoverPopupId === id) {
            hide(id)
            hoverPopupId = ""
            popupAnchorItem = null
            popupAnchorWindow = null
        }
    }

    function hoverEnter(id, item, barPanel) {
        var pluginId = canonicalPluginId(id)
        peekHideTimer.stop()
        peekHoverId = ""
        hoverHideTimer.stop()
        pendingHoverId = pluginId
        pendingHoverItem = item
        pendingHoverWindow = barPanel
        if (hoverPopupId === pluginId) {
            popupAnchorItem = item
            popupAnchorWindow = barPanel
            return
        }
        hoverShowTimer.restart()
    }

    function hoverLeave(id) {
        var pluginId = canonicalPluginId(id)
        if (pluginId === pendingHoverId) {
            hoverShowTimer.stop()
            pendingHoverId = ""
            pendingHoverItem = null
            pendingHoverWindow = null
        }
        if (pluginId === hoverPopupId)
            hoverHideTimer.restart()
    }

    function popupHoverEnter() {
        hoverHideTimer.stop()
        hoverShowTimer.stop()
        peekHideTimer.stop()
        peekHoverId = ""
    }

    function popupHoverLeave() {
        if (hoverPopupId)
            hoverHideTimer.restart()
    }

    function applyPendingHover() {
        var pluginId = pendingHoverId
        if (!pluginId)
            return
        var item = pendingHoverItem
        var win = pendingHoverWindow
        var previous = hoverPopupId
        pendingHoverId = ""
        pendingHoverItem = null
        pendingHoverWindow = null
        if (previous && previous !== pluginId)
            hide(previous)
        hoverPopupId = pluginId
        popupAnchorItem = item
        popupAnchorWindow = win
        if (!isPluginOpen(pluginId))
            summon(pluginId, "")
    }

    function clearHoverPopup() {
        hoverShowTimer.stop()
        hoverHideTimer.stop()
        peekHideTimer.stop()
        peekHoverId = ""
        if (hoverPopupId)
            hide(hoverPopupId)
        hoverPopupId = ""
        pendingHoverId = ""
        pendingHoverItem = null
        pendingHoverWindow = null
        popupAnchorItem = null
        popupAnchorWindow = null
    }

    Timer {
        id: hoverShowTimer
        interval: 90
        repeat: false
        onTriggered: shell.applyPendingHover()
    }

    Timer {
        id: hoverHideTimer
        interval: 220
        repeat: false
        onTriggered: shell.clearHoverPopup()
    }

    Timer {
        id: peekHideTimer
        interval: 2200
        repeat: false
        onTriggered: shell.clearPeekHover()
    }

    function toggle(id, payloadJson) {
        var pluginId = canonicalPluginId(id)
        var dash = dashboardLoaderFor(pluginId)
        if (dash && dash.item) {
            if (dash.item.opened) {
                if (typeof dash.item.close === "function")
                    dash.item.close()
                return true
            }
            revealDashboard(pluginId)
            return true
        }
        if (isPluginOpen(pluginId)) {
            var loader = panelLoaders[pluginId]
            if (payloadJson && loader && loader.item && typeof loader.item.reopen === "function") {
                if (loader.item.reopen(payloadJson))
                    return true
            }
            return hide(pluginId)
        }
        return summon(pluginId, payloadJson)
    }

    function isPluginOpen(id) {
        var pluginId = canonicalPluginId(id)
        var dash = dashboardLoaderFor(pluginId)
        if (dash && dash.item && dash.item.opened !== undefined)
            return dash.item.opened === true
        var loader = panelLoaders[pluginId]
        if (loader && loader.item && loader.item.opened !== undefined) return loader.item.opened === true
        return openPanelIds[pluginId] === true
    }

    function invokeIfLoaded(id, method, arg) {
        var loader = panelLoaders[String(id)]
        if (!loader || !loader.item || typeof loader.item[method] !== "function") return false
        try { loader.item[method](arg) } catch (e) { console.warn("invoke failed", id, method, e) }
        return true
    }

    function deliverIfLoaded(id) {
        var loader = panelLoaders[id]
        if (!loader || !loader.item) return
        var queue = pendingPayloads[id]
        if (!Array.isArray(queue) || queue.length === 0) return
        if (typeof loader.item.open !== "function") return
        for (var i = 0; i < queue.length; i++) loader.item.open(queue[i])
        var cleared = ({})
        for (var p in pendingPayloads) if (p !== id) cleared[p] = pendingPayloads[p]
        pendingPayloads = cleared
    }

    function registerPanelLoader(id, loader) {
        var next = ({})
        for (var k in panelLoaders) next[k] = panelLoaders[k]
        next[id] = loader
        panelLoaders = next
        deliverIfLoaded(id)
    }

    function reloadBar() {
        var key = JSON.stringify({
            output: barConfig && barConfig.output ? String(barConfig.output) : "",
            position: barConfig && barConfig.position ? String(barConfig.position) : ""
        })
        if (barLoader.item && "barConfig" in barLoader.item && key === _barLoaderKey) {
            barLoader.item.barConfig = shell.barConfig
            return
        }
        if (_barReloadPending && key === _barLoaderKey)
            return
        _barLoaderKey = key
        _barReloadPending = true
        if (barLoader.active || barLoader.source !== "") {
            barLoader.active = false
            barLoader.source = ""
        }
        barReloadTimer.restart()
    }

    function applyBarReload() {
        _barReloadPending = false
        barLoader.source = shell.pluginUrl(shell.pluginTable["evo.bar"].path)
        barLoader.active = true
    }

    Timer {
        id: barReloadTimer
        interval: 0
        repeat: false
        onTriggered: shell.applyBarReload()
    }

    Item { id: serviceHost; visible: false }

    Loader {
        id: barLoader
        active: false
        onLoaded: {
            if (!item) return
            shell._barReloadPending = false
            if ("shell" in item) item.shell = shell
            if ("barConfig" in item) item.barConfig = shell.barConfig
        }
        onActiveChanged: {
            if (!active)
                shell._barReloadPending = false
        }
        onStatusChanged: {
            if (status === Loader.Error) {
                shell._barReloadPending = false
                console.warn("bar load error:", String(barLoader.errorString))
            }
        }
    }

    Loader {
        id: shopifyLoader
        active: true
        source: shell.pluginUrl(shell.pluginTable["evo.shopify"].path)
        onLoaded: {
            if (item && "shell" in item) item.shell = shell
            shell.ensureStartupDashboards()
        }
        onStatusChanged: {
            if (status === Loader.Error) console.warn("shopify load error:", String(shopifyLoader.errorString))
        }
    }

    Loader {
        id: playerLoader
        active: true
        source: shell.pluginUrl(shell.pluginTable["evo.player"].path)
        onLoaded: {
            if (item && "shell" in item) item.shell = shell
            shell.ensureStartupDashboards()
        }
        onStatusChanged: {
            if (status === Loader.Error) console.warn("player load error:", String(playerLoader.errorString))
        }
    }

    readonly property var panelPluginIds: ["evo.menu", "evo.panel", "evo.calendar", "evo.shopify_diy", "evo.shopify_tgs", "evo.cursor", "evo.weather", "evo.network", "evo.volume", "evo.media", "evo.github", "evo.system", "evo.stocks", "evo.cloudflare", "evo.transmission.add", "evo.library", "evo.wallpaper", "evo.clipboard"]

    Instantiator {
        model: shell.panelPluginIds

        delegate: Loader {
            required property string modelData
            active: (shell.pluginTable[modelData] && shell.pluginTable[modelData].keepLoaded) || shell.openPanelIds[modelData] === true
            source: shell.pluginUrl(shell.pluginTable[modelData].path)
            onLoaded: {
                if (item && "shell" in item) item.shell = shell
                shell.registerPanelLoader(modelData, this)
            }
            onActiveChanged: if (!active) shell.registerPanelLoader(modelData, this)
        }
    }

    property bool _startupDashboardsPinned: false

    function ensureStartupDashboards() {
        if (_startupDashboardsPinned)
            return
        if (!shopifyLoader.item || !playerLoader.item)
            return
        _startupDashboardsPinned = true
        Qt.callLater(function() {
            openDashboardOnly("evo.shopify")
            openDashboardOnly("evo.player")
        })
    }

    IpcHandler {
        target: "shell"

        function ping(): string { return "ok" }

        function summon(id: string, payloadJson: string): string {
            return shell.summon(id, payloadJson) ? "ok" : "unknown"
        }

        function hide(id: string): string {
            shell.hide(id)
            return "ok"
        }

        function toggle(id: string, payloadJson: string): string {
            shell.toggle(id, payloadJson || "")
            return "ok"
        }

        function openDashboard(id: string): string {
            return shell.openDashboardOnly(id) ? "ok" : "unknown"
        }

        function call(id: string, method: string, arg: string): string {
            var svc = shell.serviceFor(id)
            if (!svc || typeof svc[method] !== "function") return "unknown"
            try { return String(svc[method](arg)) } catch (e) { return "error:" + e }
        }

        function reloadConfig(): string {
            userConfigFile.reload()
            return "ok"
        }

        function listPlugins(): string {
            return JSON.stringify(shell.pluginTable)
        }

    }

    Component.onCompleted: {
        applyShellConfig()
    }

    Connections {
        target: Quickshell

        function onReloadCompleted() {
            Quickshell.inhibitReloadPopup()
            var notif = shell.serviceFor("evo.notifications")
            if (notif && typeof notif.showBrief === "function")
                notif.showBrief("evoshell", "reloaded")
        }

        function onReloadFailed() {
            Quickshell.inhibitReloadPopup()
            var notif = shell.serviceFor("evo.notifications")
            if (notif && typeof notif.showBrief === "function")
                notif.showBrief("evoshell", "reload failed")
        }
    }
}
