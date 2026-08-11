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
        panel: { side: "left", output: "DP-1" },
        bar: {
            id: "evo.bar",
            position: "bottom",
            layout: {
                left: [{ id: "evo.menu" }],
                center: [{ id: "evo.workspaces" }, { id: "evo.clock", format: "%a %d %H:%M" }],
                right: [{ id: "evo.audio" }, { id: "evo.tray" }]
            }
        }
    })

    readonly property var pluginTable: ({
        "evo.background": { kinds: ["service"], path: "plugins/background/Background.qml", keepLoaded: true },
        "evo.audio": { kinds: ["service"], path: "plugins/audio/Service.qml", keepLoaded: true },
        "evo.idle": { kinds: ["service"], path: "plugins/idle/Service.qml" },
        "evo.lock": { kinds: ["service"], path: "plugins/lock/Service.qml", keepLoaded: true },
        "evo.notifications": { kinds: ["service"], path: "plugins/notifications/Service.qml", keepLoaded: true },
        "evo.menu": { kinds: ["menu"], path: "plugins/menu/Menu.qml", keepLoaded: true },
        "evo.weather": { kinds: ["menu"], path: "plugins/weather/Weather.qml", keepLoaded: true },
        "evo.stats": { kinds: ["menu"], path: "plugins/stats/Stats.qml", keepLoaded: true },
        "evo.calendar": { kinds: ["menu"], path: "plugins/calendar/Calendar.qml", keepLoaded: true },
        "evo.clipboard": { kinds: ["service"], path: "plugins/clipboard/Service.qml", keepLoaded: true },
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

    function summon(id, payloadJson) {
        var pluginId = String(id || "")
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
        var pluginId = String(id || "")
        if (!openPanelIds[pluginId] && !isPluginOpen(pluginId)) return true
        var next = ({})
        for (var k in openPanelIds) if (k !== pluginId) next[k] = openPanelIds[k]
        openPanelIds = next
        invokeIfLoaded(pluginId, "close", null)
        return true
    }

    function toggle(id, payloadJson) {
        var pluginId = String(id || "")
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
        var loader = panelLoaders[String(id)]
        if (loader && loader.item && loader.item.opened !== undefined) return loader.item.opened === true
        return openPanelIds[String(id)] === true
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

    readonly property var panelPluginIds: ["evo.menu", "evo.panel", "evo.weather", "evo.stats", "evo.calendar"]

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
                notif.showBrief("evo-shell", "reloaded")
        }

        function onReloadFailed() {
            Quickshell.inhibitReloadPopup()
            var notif = shell.serviceFor("evo.notifications")
            if (notif && typeof notif.showBrief === "function")
                notif.showBrief("evo-shell", "reload failed")
        }
    }
}
