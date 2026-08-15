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
        "evo.stats_diy": { kinds: ["menu"], path: "plugins/stats/StatsDiy.qml", keepLoaded: true },
        "evo.stats_tgs": { kinds: ["menu"], path: "plugins/stats/StatsTgs.qml", keepLoaded: true },
        "evo.cursor": { kinds: ["menu"], path: "plugins/cursor/Cursor.qml", keepLoaded: true },
        "evo.weather": { kinds: ["menu"], path: "plugins/weather/Weather.qml", keepLoaded: true },
        "evo.network": { kinds: ["menu"], path: "plugins/network/Network.qml", keepLoaded: true },
        "evo.sound": { kinds: ["menu"], path: "plugins/sound/Sound.qml", keepLoaded: true },
        "evo.github": { kinds: ["menu"], path: "plugins/github/Github.qml", keepLoaded: true },
        "evo.stocks": { kinds: ["menu"], path: "plugins/stocks/Stocks.qml", keepLoaded: true },
        "evo.library": { kinds: ["menu"], path: "plugins/library/Library.qml", keepLoaded: true },
        "evo.theme": { kinds: ["menu"], path: "plugins/theme/Theme.qml", keepLoaded: true },
        "evo.screenshot": { kinds: ["menu"], path: "plugins/screenshot/Screenshot.qml", keepLoaded: true },
        "evo.clipboard": { kinds: ["menu", "service"], path: "plugins/clipboard/Clipboard.qml", servicePath: "plugins/clipboard/Service.qml", keepLoaded: true },
        "evo.panel": { kinds: ["panel"], path: "plugins/panel/Panel.qml", keepLoaded: true },
        "evo.bar": { kinds: ["bar"], path: "plugins/bar/Bar.qml" }
    })

    property var shellConfig: builtinShellConfig
    property var barConfig: builtinShellConfig.bar
    property string _barLoaderKey: ""
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

    function summon(id, payloadJson) {
        var pluginId = canonicalPluginId(id)
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

    function hoverEnter(id, item, barPanel) {
        var pluginId = canonicalPluginId(id)
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

    function toggle(id, payloadJson) {
        var pluginId = canonicalPluginId(id)
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
        _barLoaderKey = key
        if (barLoader.item && "barConfig" in barLoader.item)
            barLoader.item.barConfig = shell.barConfig
        barLoader.active = false
        barLoader.source = ""
        Qt.callLater(function() {
            barLoader.source = shell.pluginUrl(shell.pluginTable["evo.bar"].path)
            barLoader.active = true
        })
    }

    Item { id: serviceHost; visible: false }

    Loader {
        id: barLoader
        active: true
        source: shell.pluginUrl(shell.pluginTable["evo.bar"].path)
        onLoaded: {
            if (!item) return
            if ("shell" in item) item.shell = shell
            if ("barConfig" in item) item.barConfig = shell.barConfig
        }
        onStatusChanged: {
            if (status === Loader.Error) console.warn("bar load error:", String(barLoader.errorString))
        }
    }

    readonly property var panelPluginIds: ["evo.menu", "evo.panel", "evo.calendar", "evo.stats_diy", "evo.stats_tgs", "evo.cursor", "evo.weather", "evo.network", "evo.sound", "evo.github", "evo.stocks", "evo.library", "evo.theme", "evo.wallpaper", "evo.screenshot", "evo.clipboard"]

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
