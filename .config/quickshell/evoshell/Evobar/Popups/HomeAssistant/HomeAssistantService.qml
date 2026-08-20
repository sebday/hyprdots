import QtQuick
import Quickshell
import Quickshell.Io
import "../../../Commons"
import "Api.js" as Api

Item {
    id: root
    visible: false

    property var shell: null

    function traySettings() {
        if (!shell || !shell.barConfig || !shell.barConfig.layout)
            return ({})
        var layout = shell.barConfig.layout
        var sections = [layout.center, layout.left, layout.right]
        for (var s = 0; s < sections.length; s++) {
            var list = sections[s]
            if (!Array.isArray(list))
                continue
            for (var i = 0; i < list.length; i++) {
                var item = list[i]
                if (item && String(item.id) === "evo.bar.tray" && item.homeAssistant)
                    return item.homeAssistant
            }
        }
        return ({})
    }

    function setting(name, fallback) {
        var settings = traySettings()
        var value = settings ? settings[name] : undefined
        return value === undefined || value === null ? fallback : value
    }

    function intSetting(name, fallback, min, max) {
        var n = parseInt(String(setting(name, fallback)), 10)
        if (!isFinite(n))
            n = fallback
        return Math.max(min, Math.min(max, n))
    }

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 30, 10, 3600)
    readonly property int snapshotIntervalSec: intSetting("snapshotIntervalSec", 20, 5, 600)
    readonly property var cameraEntities: asArray(setting("cameraEntities", []))
    readonly property var lightEntities: asArray(setting("lightEntities", []))
    readonly property var temperatureEntities: asArray(setting("temperatureEntities", []))

    property var data: ({ ok: false })
    property var snapshots: ({})
    property bool refreshing: false
    property bool snapshotRefreshing: false
    property bool acting: false
    property string lastError: ""
    property string actionStatus: ""
    property double lastRefreshMs: 0
    property bool popupActive: false

    readonly property bool configured: data && data.ok === true
    readonly property bool busy: refreshing || snapshotRefreshing || acting
    readonly property bool warning: configured && (
        (data.summary && data.summary.camerasOnline < data.summary.camerasTotal)
        || lastError !== ""
    )
    readonly property string haUrl: data && data.url ? String(data.url) : ""
    readonly property var temperatures: configured && Array.isArray(data.temperatures) ? data.temperatures : []
    readonly property var cameras: configured && Array.isArray(data.cameras) ? data.cameras : []
    readonly property var lights: configured && Array.isArray(data.lights) ? data.lights : []

    function asArray(value) {
        return Array.isArray(value) ? value : []
    }

    function configJson() {
        return JSON.stringify({
            cameraEntities: root.cameraEntities,
            lightEntities: root.lightEntities,
            temperatureEntities: root.temperatureEntities
        })
    }

    function mergeSnapshot(entityId, payload) {
        if (!entityId || !payload || payload.ok !== true)
            return
        var next = {}
        for (var key in root.snapshots)
            next[key] = root.snapshots[key]
        next[String(entityId)] = {
            path: String(payload.path || ""),
            url: Api.fileUrl(payload.path),
            updatedAt: Number(payload.updatedAt) || Date.now()
        }
        root.snapshots = next
    }

    function snapshotFor(entityId) {
        return root.snapshots[String(entityId || "")] || null
    }

    function flashStatus(text) {
        root.actionStatus = String(text || "")
        statusTimer.restart()
    }

    function refresh() {
        if (statesProc.running)
            return
        root.refreshing = true
        statesProc.command = Api.statesCommand(root.home, root.configJson())
        statesProc.running = true
    }

    function refreshSnapshots() {
        if (!root.configured || root.cameras.length === 0)
            return
        if (snapshotQueue.length === 0) {
            snapshotQueue = root.cameras.map(function(cam) {
                return String(cam.entityId || "")
            }).filter(function(id) { return id !== "" })
        }
        drainSnapshotQueue()
    }

    property var snapshotQueue: []

    function drainSnapshotQueue() {
        if (snapshotProc.running || root.snapshotQueue.length === 0) {
            if (root.snapshotQueue.length === 0)
                root.snapshotRefreshing = false
            return
        }
        root.snapshotRefreshing = true
        var entityId = root.snapshotQueue.shift()
        snapshotProc.entityId = entityId
        snapshotProc.command = Api.snapshotCommand(root.home, entityId)
        snapshotProc.running = true
    }

    function setLight(entityId, on, brightnessPct) {
        if (!entityId || lightProc.running)
            return
        root.acting = true
        lightProc.entityId = String(entityId)
        lightProc.command = on
            ? Api.lightCommand(root.home, entityId, "on", brightnessPct)
            : Api.lightCommand(root.home, entityId, "off")
        lightProc.running = true
    }

    function toggleLight(entityId, on, brightnessPct) {
        root.setLight(entityId, on, brightnessPct)
    }

    function openDashboard() {
        if (!root.haUrl)
            return
        Quickshell.execDetached(["bash", "-lc",
            root.home + "/.local/bin/evo-bar-brave open brave-home-assistant " + Util.shellQuote(root.haUrl)
        ])
    }

    Process {
        id: statesProc
        stdout: StdioCollector { id: statesOut; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(exitCode) {
            root.refreshing = false
            var parsed = Api.parseJson(statesOut.text)
            if (exitCode !== 0 || parsed.ok !== true) {
                root.data = parsed && typeof parsed === "object" ? parsed : { ok: false, error: "request failed" }
                root.lastError = String(parsed.error || parsed.detail || "request failed")
                return
            }
            root.data = parsed
            root.lastRefreshMs = Date.now()
            if (root.lastError !== "" && parsed.ok === true)
                root.lastError = ""
            if (root.popupActive)
                root.refreshSnapshots()
        }
    }

    Process {
        id: snapshotProc
        property string entityId: ""
        stdout: StdioCollector { id: snapshotOut; waitForEnd: true }
        onExited: function(exitCode) {
            var parsed = Api.parseJson(snapshotOut.text)
            if (exitCode === 0 && parsed.ok === true)
                root.mergeSnapshot(snapshotProc.entityId, parsed)
            Qt.callLater(function() { root.drainSnapshotQueue() })
        }
    }

    Process {
        id: lightProc
        property string entityId: ""
        stdout: StdioCollector { waitForEnd: true }
        onExited: function(exitCode) {
            root.acting = false
            if (exitCode === 0)
                root.flashStatus("Updated " + lightProc.entityId)
            else
                root.flashStatus("Light action failed")
            root.refresh()
        }
    }

    Timer {
        id: resourceTimer
        interval: root.refreshIntervalSec * 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        id: snapshotTimer
        interval: root.snapshotIntervalSec * 1000
        repeat: true
        running: root.popupActive
        onTriggered: {
            root.snapshotQueue = []
            root.refreshSnapshots()
        }
    }

    Timer {
        id: statusTimer
        interval: 2600
        onTriggered: root.actionStatus = ""
    }

    onPopupActiveChanged: {
        if (root.popupActive) {
            root.refresh()
            root.snapshotQueue = []
            root.refreshSnapshots()
            snapshotTimer.restart()
        } else {
            snapshotTimer.stop()
        }
    }
}
