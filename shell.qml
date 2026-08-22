//@ pragma IconTheme evo-current

import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "./commons"
import "pluginManifest.js" as PluginManifest

ShellRoot {
    id: shell

    readonly property string home: Quickshell.env("HOME")
    readonly property string shellDir: Quickshell.shellDir
    readonly property string configDir: {
        var env = Quickshell.env("EVOSHELL_CONFIG")
        if (env && String(env).trim() !== "")
            return String(env).trim()
        return home + "/.config/evoshell"
    }
    readonly property string defaultConfigPath: shell.shellDir + "/config/shell.json"
    readonly property string userOverridePath: configDir + "/overrides.json"
    readonly property string evoshellBin: Quickshell.env("EVOSHELL_BIN") || (home + "/.local/lib/evoshell/bin")
    readonly property string evoBin: home + "/.local/bin/evo"
    readonly property string stateDir: Util.stateDir(home)
    readonly property string cacheDir: Util.cacheDir(home)

    readonly property var builtinShellConfig: ({
        version: 1,
        idle: { lock: 900 },
        notifications: {
            durationMs: 3000,
            shellLogs: {
                enabled: true,
                pollIntervalMs: 5000,
                dedupeWindowSec: 300,
                userJournal: true
            }
        },
        panel: { side: "left" },
        bar: {
            id: "evo.bar",
            position: "bottom",
            layout: {
                left: [{ id: "evo.sys.menu" }],
                center: [{ id: "evo.bar.clock", format: "%a %d %H:%M" }],
                right: [{ id: "evo.bar.volume" }, { id: "evo.bar.tray" }]
            }
        },
        dashboards: {
            openOnStart: []
        }
    })

    readonly property string pluginOverlayPath: configDir + "/plugins/manifest.json"
    property var pluginOverlay: ({})

    readonly property var pluginTable: PluginManifest.mergePlugins(PluginManifest.plugins, pluginOverlay)
    readonly property var panelPluginIdsList: PluginManifest.mergePanelPluginIds(PluginManifest.panelPluginIds, pluginOverlay)
    readonly property var allDashboardIds: PluginManifest.mergeDashboardIds(PluginManifest.dashboardIds, pluginOverlay)
    readonly property var extensionDashboardIds: PluginManifest.extensionDashboardIds(PluginManifest.dashboardIds, pluginOverlay)
    readonly property var extensionStartupDashboards: PluginManifest.extensionStartupDashboards(PluginManifest.dashboardIds, pluginOverlay)
    readonly property var extensionTrayWidgets: PluginManifest.extensionTrayWidgets(pluginOverlay)
    readonly property var trayWidgetOrder: PluginManifest.resolveTrayWidgetOrder(
        pluginOverlay,
        shellConfig && shellConfig.bar && Array.isArray(shellConfig.bar.trayWidgetOrder)
            ? shellConfig.bar.trayWidgetOrder : null)
    readonly property var trayWidgetSettingsOrder: trayWidgetOrder

    property var shellConfig: builtinShellConfig
    property var _lastGoodShellConfig: builtinShellConfig
    property var barConfig: builtinShellConfig.bar
    property bool defaultConfigReady: false
    property bool overrideConfigReady: false
    property string _barLoaderKey: ""
    property bool _barReloadPending: false
    property var _services: ({})
    property var openPanelIds: ({})
    property var panelLoaders: ({})
    property var dashboardLoaders: ({})
    property var pendingPayloads: ({})
    property var pendingDashboardOpenIds: ({})
    property var popupAnchorItem: null
    property var popupAnchorWindow: null
    property string hoverPanelId: ""
    property string pendingHoverId: ""
    property var pendingHoverItem: null
    property var pendingHoverWindow: null
    property var hoverPanelData: ({})
    property string peekHoverId: ""
    property var pinnedHoverPanelIds: ({})

    function isHoverPanelPinned(id) {
        var pluginId = canonicalPluginId(id)
        return pinnedHoverPanelIds[pluginId] === true
    }

    function pinHoverPanel(id) {
        var pluginId = canonicalPluginId(id)
        var next = ({})
        for (var k in pinnedHoverPanelIds)
            next[k] = pinnedHoverPanelIds[k]
        next[pluginId] = true
        pinnedHoverPanelIds = next
        hoverHideTimer.stop()
        peekHideTimer.stop()
    }

    function unpinHoverPanel(id) {
        var pluginId = canonicalPluginId(id)
        if (!pinnedHoverPanelIds[pluginId])
            return
        var next = ({})
        for (var k in pinnedHoverPanelIds) {
            if (k !== pluginId)
                next[k] = pinnedHoverPanelIds[k]
        }
        pinnedHoverPanelIds = next
    }

    function toggleHoverPanelPinFromBar(id) {
        var pluginId = canonicalPluginId(id)
        if (!pluginId || !isPluginOpen(pluginId))
            return false
        if (hoverPanelId !== pluginId && !isHoverPanelPinned(pluginId))
            return false
        hoverHideTimer.stop()
        peekHideTimer.stop()
        return invokeIfLoaded(pluginId, "togglePin", null)
    }

    function setHoverPanelData(key, json) {
        var id = String(key || "")
        if (!id || !Util.isPlainObject(json))
            return
        var next = ({})
        for (var k in hoverPanelData)
            next[k] = hoverPanelData[k]
        next[id] = json
        hoverPanelData = next
    }

    function hoverPanelDataFor(key) {
        var id = String(key || "")
        if (!id)
            return null
        return hoverPanelData[id] || null
    }

    FileView {
        id: defaultConfigFile
        path: shell.defaultConfigPath
        watchChanges: true
        printErrors: false
        onLoaded: {
            shell.defaultConfigReady = true
            shell.applyShellConfig()
        }
        onLoadFailed: {
            shell.defaultConfigReady = true
            shell.applyShellConfig()
        }
        onFileChanged: reload()
    }

    FileView {
        id: userOverrideFile
        path: shell.userOverridePath
        watchChanges: true
        printErrors: false
        onLoaded: {
            shell.overrideConfigReady = true
            shell.applyShellConfig()
        }
        onLoadFailed: {
            shell.overrideConfigReady = true
            shell.applyShellConfig()
        }
        onFileChanged: reload()
    }

    FileView {
        id: pluginOverlayFile
        path: shell.pluginOverlayPath
        watchChanges: true
        printErrors: false
        onLoaded: shell.applyPluginOverlay()
        onLoadFailed: shell.applyPluginOverlay()
        onFileChanged: reload()
    }

    function applyPluginOverlay() {
        var next = ({})
        var text = pluginOverlayFile.text()
        if (String(text || "").trim()) {
            try {
                var parsed = JSON.parse(text)
                if (Util.isPlainObject(parsed))
                    next = parsed
            } catch (e) {
                console.warn("plugin overlay parse failed:", String(e))
            }
        }
        pluginOverlay = next
        if (defaultConfigReady && overrideConfigReady)
            scheduleStartupDashboards()
    }

    function parseShellConfig(text) {
        if (!String(text || "").trim())
            return null
        try {
            var parsed = JSON.parse(text)
            if (Util.isPlainObject(parsed) && parsed.version === 1)
                return parsed
        } catch (e) {}
        return null
    }

    function applyShellConfig() {
        var merged = Util.deepMerge(builtinShellConfig, {})
        var repo = parseShellConfig(defaultConfigFile.text())
        if (repo)
            merged = Util.deepMerge(merged, repo)
        var overrides = parseShellConfig(userOverrideFile.text())
        if (overrides)
            merged = Util.deepMerge(merged, overrides)
        if (merged.version === 1) {
            shellConfig = merged
            _lastGoodShellConfig = merged
        } else {
            shellConfig = _lastGoodShellConfig || builtinShellConfig
        }
        barConfig = Util.isPlainObject(shellConfig.bar) ? shellConfig.bar : builtinShellConfig.bar
        syncServices()
        reloadBar()
        if (defaultConfigReady && overrideConfigReady)
            scheduleStartupDashboards()
    }

    function scheduleStartupDashboards() {
        startupDashboardTimer.restart()
    }

    function pluginUrl(metaOrPath) {
        if (typeof metaOrPath === "string")
            return shellDir + "/" + metaOrPath
        if (metaOrPath && metaOrPath.root === "plugins")
            return configDir + "/plugins/" + metaOrPath.path
        if (metaOrPath && metaOrPath.path)
            return shellDir + "/" + metaOrPath.path
        return ""
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
        var relPath = meta.servicePath ? ({ path: meta.servicePath, root: meta.root }) : meta
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

    function playerDisplayArtReady(trackPath, artPath) {
        var loader = dashboardLoaderFor("evo.panels.player")
        if (!loader || !loader.item || typeof loader.item.applyDisplayArt !== "function")
            return
        loader.item.applyDisplayArt(trackPath, artPath)
    }

    function registerDashboardLoader(id, loader) {
        var pluginId = canonicalPluginId(id)
        var next = ({})
        for (var k in dashboardLoaders)
            next[k] = dashboardLoaders[k]
        next[pluginId] = loader
        dashboardLoaders = next
    }

    function canonicalPluginId(id) {
        return String(id || "")
    }

    function dashboardLoaderFor(id) {
        var pluginId = canonicalPluginId(id)
        if (dashboardLoaders[pluginId])
            return dashboardLoaders[pluginId]
        if (pluginId === "evo.panels.player") return playerLoader
        return null
    }

    function ensureDashboardLoader(pluginId) {
        var loader = dashboardLoaderFor(pluginId)
        if (!loader)
            return false
        var meta = pluginTable[pluginId]
        if (!meta)
            return false
        if (!loader.active || loader.source === "") {
            loader.source = shell.pluginUrl(meta)
            loader.active = true
        }
        return true
    }

    function pinKindForDashboard(id) {
        return PluginManifest.dashboardPinKind(canonicalPluginId(id), pluginOverlay)
    }

    function openDashboardOnly(pluginId) {
        return requestDashboardOpen(pluginId)
    }

    function revealDashboard(pluginId) {
        return requestDashboardOpen(pluginId)
    }

    function requestDashboardOpen(pluginId) {
        var meta = pluginTable[pluginId]
        if (!meta || meta.kinds.indexOf("dashboard") === -1)
            return false

        var next = ({})
        for (var k in pendingDashboardOpenIds)
            next[k] = pendingDashboardOpenIds[k]
        next[pluginId] = true
        pendingDashboardOpenIds = next

        if (!ensureDashboardLoader(pluginId))
            return false
        var dash = dashboardLoaderFor(pluginId)
        if (dash && dash.item)
            fulfillDashboardOpen(pluginId, dash.item)
        return true
    }

    function fulfillDashboardOpen(pluginId, item) {
        if (!pendingDashboardOpenIds[pluginId] || !item
                || typeof item.open !== "function")
            return

        var next = ({})
        for (var k in pendingDashboardOpenIds) {
            if (k !== pluginId)
                next[k] = pendingDashboardOpenIds[k]
        }
        pendingDashboardOpenIds = next
        item.open()
    }

    function startupDashboardIds() {
        var cfg = shellConfig && shellConfig.dashboards
        if (!Util.isPlainObject(cfg))
            return []
        var ids = cfg.openOnStart
        if (!Array.isArray(ids))
            return []
        return ids
    }

    function orderedStartupDashboardIds() {
        var ids = startupDashboardIds()
        var ordered = []
        var playerId = ""
        for (var i = 0; i < ids.length; i++) {
            var id = canonicalPluginId(ids[i])
            if (!id)
                continue
            if (id === "evo.panels.player")
                playerId = id
            else
                ordered.push(id)
        }
        if (playerId)
            ordered.push(playerId)
        return ordered
    }

    function openStartupDashboards() {
        var ids = orderedStartupDashboardIds()
        for (var i = 0; i < ids.length; i++) {
            var id = ids[i]
            if (id === "evo.panels.player") {
                Qt.callLater(function() {
                    var dash = dashboardLoaderFor("evo.panels.player")
                    if (dash && dash.item && dash.item.opened === true)
                        return
                    requestDashboardOpen("evo.panels.player")
                })
                continue
            }
            var dash = dashboardLoaderFor(id)
            if (dash && dash.item && dash.item.opened === true)
                continue
            requestDashboardOpen(id)
        }
    }

    function summon(id, payloadJson) {
        var pluginId = canonicalPluginId(id)
        var dash = dashboardLoaderFor(pluginId)
        if (dash)
            return requestDashboardOpen(pluginId)
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
        unpinHoverPanel(pluginId)
        var dash = dashboardLoaderFor(pluginId)
        if (dash && dash.item && typeof dash.item.close === "function") {
            dash.item.close()
            return true
        }
        if (hoverPanelId === pluginId) {
            hoverPanelId = ""
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

    function peekHoverPanel(id, item, barPanel, durationMs) {
        var pluginId = canonicalPluginId(id)
        hoverShowTimer.stop()
        hoverHideTimer.stop()
        pendingHoverId = ""
        pendingHoverItem = null
        pendingHoverWindow = null
        var previous = hoverPanelId
        if (previous && previous !== pluginId && !isHoverPanelPinned(previous))
            hide(previous)
        hoverPanelId = pluginId
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
        if (hoverPanelId === id) {
            hide(id)
            hoverPanelId = ""
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
        if (hoverPanelId === pluginId) {
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
        if (pluginId === hoverPanelId && !isHoverPanelPinned(pluginId))
            hoverHideTimer.restart()
    }

    function popupHoverEnter() {
        hoverHideTimer.stop()
        hoverShowTimer.stop()
        peekHideTimer.stop()
        peekHoverId = ""
    }

    function popupHoverLeave() {
        if (hoverPanelId && !isHoverPanelPinned(hoverPanelId))
            hoverHideTimer.restart()
    }

    function applyPendingHover() {
        var pluginId = pendingHoverId
        if (!pluginId)
            return
        var item = pendingHoverItem
        var win = pendingHoverWindow
        var previous = hoverPanelId
        pendingHoverId = ""
        pendingHoverItem = null
        pendingHoverWindow = null
        if (previous && previous !== pluginId && !isHoverPanelPinned(previous))
            hide(previous)
        hoverPanelId = pluginId
        popupAnchorItem = item
        popupAnchorWindow = win
        summon(pluginId, "")
    }

    function clearHoverPanel() {
        hoverShowTimer.stop()
        hoverHideTimer.stop()
        peekHideTimer.stop()
        peekHoverId = ""
        if (hoverPanelId && !isHoverPanelPinned(hoverPanelId))
            hide(hoverPanelId)
        hoverPanelId = ""
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
        onTriggered: shell.clearHoverPanel()
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
        barLoader.source = shell.pluginUrl(shell.pluginTable["evo.bar"])
        barLoader.active = true
    }

    Timer {
        id: barReloadTimer
        interval: 0
        repeat: false
        onTriggered: shell.applyBarReload()
    }

    Timer {
        id: startupDashboardTimer
        interval: 300
        repeat: false
        onTriggered: shell.openStartupDashboards()
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

    Instantiator {
        id: extensionDashboardInstantiator
        model: shell.extensionDashboardIds

        delegate: Loader {
            required property string modelData
            readonly property string dashId: modelData
            active: false
            visible: false
            onLoaded: {
                if (item && "shell" in item) item.shell = shell
                shell.fulfillDashboardOpen(dashId, item)
            }
            onStatusChanged: {
                if (status === Loader.Error)
                    console.warn("dashboard load error:", dashId, String(errorString))
            }
            Component.onCompleted: {
                var meta = shell.pluginTable[dashId]
                if (meta)
                    source = shell.pluginUrl(meta)
                shell.registerDashboardLoader(dashId, this)
            }
        }
    }

    Loader {
        id: playerLoader
        active: false
        visible: false
        onLoaded: {
            if (item && "shell" in item) item.shell = shell
            shell.registerDashboardLoader("evo.panels.player", playerLoader)
            shell.fulfillDashboardOpen("evo.panels.player", item)
        }
        onStatusChanged: {
            if (status === Loader.Error) console.warn("player load error:", String(playerLoader.errorString))
        }
    }

    Component.onCompleted: {
        applyPluginOverlay()
        var playerMeta = pluginTable["evo.panels.player"]
        if (playerMeta)
            playerLoader.source = shell.pluginUrl(playerMeta)
        applyShellConfig()
    }

    Instantiator {
        model: shell.panelPluginIdsList

        delegate: Loader {
            required property string modelData
            active: (shell.pluginTable[modelData] && shell.pluginTable[modelData].keepLoaded) || shell.openPanelIds[modelData] === true
            source: shell.pluginUrl(shell.pluginTable[modelData])
            onLoaded: {
                if (item && "shell" in item) item.shell = shell
                shell.registerPanelLoader(modelData, this)
                if (item && "pluginId" in item) item.pluginId = modelData
            }
            onActiveChanged: if (!active) shell.registerPanelLoader(modelData, this)
        }
    }

    function toggleSystemMenu() {
        return toggle("evo.sys.menu", '{"mode":"power"}')
    }

    function toggleAppLauncher() {
        return toggle("evo.sys.menu", '{"mode":"apps"}')
    }

    GlobalShortcut {
        appid: "evoshell"
        name: "systemMenu"
        description: "System menu"
        onPressed: shell.toggleSystemMenu()
    }

    GlobalShortcut {
        appid: "evoshell"
        name: "appLauncher"
        description: "App launcher"
        onPressed: shell.toggleAppLauncher()
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

        function toggleSystemMenu(): string {
            shell.toggleSystemMenu()
            return "ok"
        }

        function toggleAppLauncher(): string {
            shell.toggleAppLauncher()
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
            Quickshell.execDetached(Util.evoCommand(shell.home, ["system", "restart"]))
            return "ok"
        }

        function listPlugins(): string {
            return JSON.stringify(shell.pluginTable)
        }

    }

    Connections {
        target: Quickshell

        function onReloadCompleted() {
            Quickshell.inhibitReloadPopup()
        }

        function onReloadFailed() {
            Quickshell.inhibitReloadPopup()
        }
    }
}
