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
    readonly property var lightEntities: asArray(setting("lightEntities", []))
    readonly property var lightAreas: asArray(setting("lightAreas", []))
    readonly property bool lightGroupsOnly: setting("lightGroupsOnly", false) === true
    readonly property var climateEntities: asArray(setting("climateEntities", []))
    readonly property var lightBrightnessEntities: asArray(setting("lightBrightnessEntities", []))
    readonly property var lightColorEntities: asArray(setting("lightColorEntities", []))

    property var data: ({ ok: false })
    property bool refreshing: false
    property bool acting: false
    property string lastError: ""
    property double lastRefreshMs: 0
    property bool popupActive: false
    property var lightOptimistic: ({})
    property var climateOptimistic: ({})

    readonly property bool configured: data && data.ok === true
    readonly property bool busy: refreshing || acting
    readonly property bool climateBusy: climateProc.running
    readonly property bool warning: configured && lastError !== ""
    readonly property string haUrl: data && data.url ? String(data.url) : ""
    readonly property var climates: configured && Array.isArray(data.climates) ? data.climates : []
    readonly property var lights: configured && Array.isArray(data.lights) ? data.lights : []
    readonly property bool heatingActive: {
        if (!root.configured)
            return false
        var list = root.climates
        for (var i = 0; i < list.length; i++) {
            if (String(list[i].mode || "off") !== "off")
                return true
        }
        return false
    }

    function asArray(value) {
        return Array.isArray(value) ? value : []
    }

    function configJson() {
        return JSON.stringify({
            lightEntities: root.lightEntities,
            lightAreas: root.lightAreas,
            lightGroupsOnly: root.lightGroupsOnly,
            climateEntities: root.climateEntities,
            lightBrightnessEntities: root.lightBrightnessEntities,
            lightColorEntities: root.lightColorEntities
        })
    }

    function entityAllowed(list, entityId) {
        if (!Array.isArray(list) || list.length === 0)
            return false
        return list.indexOf(String(entityId || "")) >= 0
    }

    function lightHasBrightness(entityId) {
        return root.entityAllowed(root.lightBrightnessEntities, entityId)
    }

    function lightHasColor(entityId) {
        return root.entityAllowed(root.lightColorEntities, entityId)
    }

    function cloneData() {
        var next = {}
        if (!root.data || typeof root.data !== "object")
            return next
        for (var key in root.data)
            next[key] = root.data[key]
        return next
    }

    function patchClimate(entityId, patch) {
        if (!root.configured || !Array.isArray(root.data.climates))
            return
        var id = String(entityId || "")
        var climates = root.data.climates.map(function(row) {
            if (String(row.entityId || "") !== id)
                return row
            var next = {}
            for (var key in row)
                next[key] = row[key]
            for (var field in patch)
                next[field] = patch[field]
            return next
        })
        var nextData = root.cloneData()
        nextData.climates = climates
        root.data = nextData
    }

    function patchLight(entityId, patch) {
        if (!root.configured || !Array.isArray(root.data.lights))
            return
        var id = String(entityId || "")
        var lights = root.data.lights.map(function(row) {
            if (String(row.entityId || "") !== id)
                return row
            var next = {}
            for (var key in row)
                next[key] = row[key]
            for (var field in patch)
                next[field] = patch[field]
            return next
        })
        var nextData = root.cloneData()
        nextData.lights = lights
        root.data = nextData
    }

    function hsClose(a, b, toleranceDeg) {
        if (!Array.isArray(a) || !Array.isArray(b) || a.length < 1 || b.length < 1)
            return false
        var tol = toleranceDeg !== undefined ? toleranceDeg : 15
        var delta = Math.abs(Math.round(Number(a[0])) - Math.round(Number(b[0])))
        if (delta > 180)
            delta = 360 - delta
        return delta <= tol
    }

    function hsMatchesTarget(rowHs, wantHs) {
        if (!Array.isArray(wantHs) || wantHs.length < 1)
            return true
        if (!Array.isArray(rowHs) || rowHs.length < 1)
            return false
        return root.hsClose(rowHs, wantHs)
    }

    function setLightOptimistic(entityId, patch) {
        var id = String(entityId || "")
        if (!id || !patch || typeof patch !== "object")
            return
        var prev = root.lightOptimistic[id] || {}
        var merged = {
            on: prev.on,
            hs: prev.hs,
            brightnessPct: prev.brightnessPct
        }
        if (patch.on !== undefined)
            merged.on = patch.on === true
        if (patch.hs !== undefined)
            merged.hs = patch.hs
        if (patch.brightnessPct !== undefined)
            merged.brightnessPct = Math.max(1, Math.min(100, Math.round(Number(patch.brightnessPct))))
        var next = {}
        for (var key in root.lightOptimistic)
            next[key] = root.lightOptimistic[key]
        next[id] = merged
        root.lightOptimistic = next
    }

    function applyLightOptimistic(lights) {
        if (!Array.isArray(lights))
            return lights
        var opt = root.lightOptimistic
        var hasAny = false
        for (var checkId in opt) {
            hasAny = true
            break
        }
        if (!hasAny)
            return lights

        var cleared = {}
        var out = lights.map(function(row) {
            var id = String(row.entityId || "")
            var want = opt[id]
            if (!want)
                return row
            var onMatches = want.on === undefined || row.on === want.on
            var hsMatches = !want.hs || root.hsMatchesTarget(row.hsColor, want.hs)
            var brightnessMatches = want.brightnessPct === undefined
                || Math.round(Number(row.brightnessPct)) === want.brightnessPct
            if (onMatches && hsMatches && brightnessMatches) {
                cleared[id] = true
                return row
            }
            var next = {}
            for (var key in row)
                next[key] = row[key]
            if (want.on !== undefined)
                next.on = want.on
            if (want.hs)
                next.hsColor = want.hs
            if (want.brightnessPct !== undefined)
                next.brightnessPct = want.brightnessPct
            return next
        })

        var stillPending = {}
        var changed = false
        for (var pendingId in opt) {
            if (cleared[pendingId]) {
                changed = true
                continue
            }
            stillPending[pendingId] = opt[pendingId]
        }
        if (changed)
            root.lightOptimistic = stillPending
        return out
    }

    function setClimateOptimistic(entityId, patch) {
        var id = String(entityId || "")
        if (!id || !patch || typeof patch !== "object")
            return
        var prev = root.climateOptimistic[id] || {}
        var merged = {
            heating: prev.heating,
            mode: prev.mode !== undefined ? String(prev.mode) : "off",
            target: prev.target
        }
        if (patch.heating !== undefined) {
            merged.heating = patch.heating === true
            merged.mode = merged.heating ? "heat" : "off"
        }
        if (patch.mode !== undefined) {
            merged.mode = String(patch.mode || "off")
            merged.heating = merged.mode !== "off"
        }
        if (patch.target !== undefined && patch.target !== null)
            merged.target = Math.round(Number(patch.target))
        var next = {}
        for (var key in root.climateOptimistic)
            next[key] = root.climateOptimistic[key]
        next[id] = merged
        root.climateOptimistic = next
    }

    function applyClimateOptimistic(climates) {
        if (!Array.isArray(climates))
            return climates
        var opt = root.climateOptimistic
        var hasAny = false
        for (var checkId in opt) {
            hasAny = true
            break
        }
        if (!hasAny)
            return climates

        var cleared = {}
        var out = climates.map(function(row) {
            var id = String(row.entityId || "")
            var want = opt[id]
            if (!want)
                return row
            var rowHeating = String(row.mode || "off") !== "off"
            var targetMatches = want.target === undefined || want.target === null
                || Math.round(Number(row.target)) === want.target
            if (rowHeating === want.heating && targetMatches) {
                cleared[id] = true
                return row
            }
            var next = {}
            for (var key in row)
                next[key] = row[key]
            next.mode = want.mode
            next.action = want.heating ? "heating" : "off"
            if (want.target !== undefined && want.target !== null)
                next.target = want.target
            return next
        })

        var stillPending = {}
        var changed = false
        for (var pendingId in opt) {
            if (cleared[pendingId]) {
                changed = true
                continue
            }
            stillPending[pendingId] = opt[pendingId]
        }
        if (changed)
            root.climateOptimistic = stillPending
        return out
    }

    function mergeStatesPayload(parsed) {
        if (!parsed || parsed.ok !== true)
            return parsed
        var next = {}
        for (var key in parsed)
            next[key] = parsed[key]
        if (Array.isArray(parsed.lights))
            next.lights = root.applyLightOptimistic(parsed.lights)
        if (Array.isArray(parsed.climates))
            next.climates = root.applyClimateOptimistic(parsed.climates)
        return next
    }

    function scheduleRefresh(fresh) {
        actionRefreshDebounce.fresh = fresh === true
        actionRefreshDebounce.restart()
    }

    function flushClimateModeRequest() {
        if (!climateModeQueue.entityId || climateProc.running)
            return
        var entityId = climateModeQueue.entityId
        var mode = climateModeQueue.mode
        climateModeQueue.entityId = ""
        climateModeQueue.mode = ""
        root.acting = true
        climateProc.entityId = entityId
        climateProc.action = "set-mode"
        climateProc.command = Api.climateModeCommand(root.home, entityId, mode)
        climateProc.running = true
    }

    function flushClimateTempRequest() {
        if (!climateTempQueue.entityId || climateProc.running)
            return
        var entityId = climateTempQueue.entityId
        var temperature = climateTempQueue.temperature
        climateTempQueue.entityId = ""
        climateProc.entityId = entityId
        climateProc.action = "set-temp"
        climateProc.command = Api.climateTempCommand(root.home, entityId, temperature)
        climateProc.running = true
    }

    signal lightCommandFinished(string entityId, bool ok)

    function flushLightRequest() {
        if (!lightQueue.command || lightProc.running)
            return
        var command = lightQueue.command
        var entityId = lightQueue.entityId
        lightQueue.command = ""
        lightQueue.entityId = ""
        lightProc.entityId = entityId
        root.acting = true
        lightProc.exec({ command: command })
    }

    function flashStatus(text) {
        var message = String(text || "").trim()
        if (!message)
            return
        var notif = root.shell ? root.shell.serviceFor("evo.sys.notifications") : null
        if (notif && typeof notif.showBrief === "function")
            notif.showBrief("Home assistant", message)
    }

    function refresh(fresh) {
        if (statesProc.running)
            return
        root.refreshing = true
        statesProc.command = Api.statesCommand(root.home, root.configJson(), fresh === true)
        statesProc.running = true
    }

    property var climateTempQueue: ({ entityId: "", temperature: 0 })
    property var climateModeQueue: ({ entityId: "", mode: "" })
    property var lightQueue: ({ entityId: "", command: "" })

    function lightRowFor(entityId) {
        var id = String(entityId || "")
        var list = root.lights
        for (var i = 0; i < list.length; i++) {
            if (String(list[i].entityId || "") === id)
                return list[i]
        }
        return null
    }

    function setLightBrightness(entityId, brightnessPct) {
        if (!entityId)
            return
        var id = String(entityId)
        var pct = Math.max(1, Math.min(100, Math.round(Number(brightnessPct))))
        var patch = { on: true, brightnessPct: pct, available: true }
        root.setLightOptimistic(id, { on: true, brightnessPct: pct })
        root.patchLight(id, patch)
        lightQueue.entityId = id
        lightQueue.command = Api.lightCommand(root.home, id, "on", pct)
        lightDebounce.restart()
    }

    function setLight(entityId, on, brightnessPct) {
        if (!entityId)
            return
        var id = String(entityId)
        var patch = { on: on === true, available: true }
        if (on && brightnessPct !== undefined && brightnessPct !== null)
            patch.brightnessPct = Math.max(1, Math.min(100, Math.round(Number(brightnessPct))))
        root.setLightOptimistic(id, { on: on === true })
        root.patchLight(id, patch)
        lightQueue.entityId = id
        lightQueue.command = on
            ? Api.lightCommand(root.home, id, "on", brightnessPct)
            : Api.lightCommand(root.home, id, "off")
        lightDebounce.restart()
    }

    function toggleLight(entityId, on, brightnessPct) {
        root.setLight(entityId, on, brightnessPct)
    }

    function setLightHue(entityId, hue, red, green, blue, brightnessPct) {
        if (!entityId)
            return
        var id = String(entityId)
        var rgb = [
            Math.max(0, Math.min(255, Math.round(Number(red)))),
            Math.max(0, Math.min(255, Math.round(Number(green)))),
            Math.max(0, Math.min(255, Math.round(Number(blue))))
        ]
        var h = Math.max(0, Math.min(1, Number(hue)))
        var hsH = Math.round(h * 360)
        var hs = [hsH, 100]
        var row = root.lightRowFor(id)
        var pct = brightnessPct
        if (pct === undefined || pct === null) {
            var current = row ? parseInt(row.brightnessPct, 10) : NaN
            pct = isNaN(current) ? undefined : current
        }
        var patch = {
            on: true,
            rgbColor: rgb,
            hsColor: hs,
            available: true
        }
        if (pct !== undefined && pct !== null)
            patch.brightnessPct = Math.max(1, Math.min(100, Math.round(Number(pct))))
        root.setLightOptimistic(id, { on: true, hs: hs })
        root.patchLight(id, patch)
        lightDebounce.stop()
        lightQueue.entityId = id
        lightQueue.command = Api.lightHueCommand(root.home, id, h, pct)
        root.flushLightRequest()
    }

    function setClimateTemperature(entityId, temperature) {
        if (!entityId)
            return
        var id = String(entityId)
        var temp = Math.round(Number(temperature))
        var row = root.climateRowFor(id)
        var heating = row && String(row.mode || "off") !== "off"
        var opt = root.climateOptimistic[id]
        if (opt && opt.heating !== undefined)
            heating = opt.heating === true
        root.setClimateOptimistic(id, { heating: heating, target: temp })
        root.patchClimate(id, { target: temp })
        climateTempQueue.entityId = id
        climateTempQueue.temperature = temp
        climateTempDebounce.restart()
    }

    function climateRowFor(entityId) {
        var id = String(entityId || "")
        var list = root.climates
        for (var i = 0; i < list.length; i++) {
            if (String(list[i].entityId || "") === id)
                return list[i]
        }
        return null
    }

    function setClimateMode(entityId, mode) {
        if (!entityId)
            return
        var id = String(entityId)
        var modeStr = String(mode || "off")
        var heating = modeStr !== "off"
        var patch = {
            mode: modeStr,
            action: heating ? "heating" : "off"
        }
        var opt = root.climateOptimistic[id]
        if (heating && opt && opt.target !== undefined && opt.target !== null)
            patch.target = opt.target
        else if (heating) {
            var row = root.climateRowFor(id)
            if (row && row.target !== undefined && row.target !== null)
                patch.target = Math.round(Number(row.target))
        }
        root.setClimateOptimistic(id, { heating: heating, mode: modeStr, target: patch.target })
        root.patchClimate(id, patch)
        if (climateProc.running) {
            climateModeQueue.entityId = id
            climateModeQueue.mode = modeStr
            return
        }
        root.acting = true
        climateProc.entityId = id
        climateProc.action = "set-mode"
        climateProc.command = Api.climateModeCommand(root.home, entityId, mode)
        climateProc.running = true
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
            root.data = root.mergeStatesPayload(parsed)
            root.lastRefreshMs = Date.now()
            if (root.lastError !== "" && parsed.ok === true)
                root.lastError = ""
        }
    }

    Process {
        id: lightProc
        property string entityId: ""
        stdout: StdioCollector { id: lightOut; waitForEnd: true }
        stderr: StdioCollector { id: lightErr; waitForEnd: true }
        onExited: function(exitCode) {
            root.acting = false
            var parsed = Api.parseJson(lightOut.text)
            var ok = exitCode === 0 && parsed && parsed.ok === true
            if (ok) {
                root.flashStatus("Updated " + lightProc.entityId)
                root.refresh(true)
            } else {
                var detail = parsed && parsed.error
                    ? String(parsed.error)
                    : String(lightErr.text || "Light action failed").trim()
                root.flashStatus(detail !== "" ? detail : "Light action failed")
            }
            root.lightCommandFinished(lightProc.entityId, ok)
            if (ok)
                root.scheduleRefresh(true)
            Qt.callLater(function() { root.flushLightRequest() })
        }
    }

    Process {
        id: climateProc
        property string entityId: ""
        property string action: ""
        stdout: StdioCollector { waitForEnd: true }
        onExited: function(exitCode) {
            root.acting = false
            if (exitCode === 0)
                root.flashStatus("Updated " + climateProc.entityId)
            else
                root.flashStatus("Climate action failed")
            root.scheduleRefresh(true)
            Qt.callLater(function() {
                root.flushClimateTempRequest()
                root.flushClimateModeRequest()
            })
        }
    }

    Timer {
        id: climateTempDebounce
        interval: 350
        onTriggered: root.flushClimateTempRequest()
    }

    Timer {
        id: lightDebounce
        interval: 450
        onTriggered: root.flushLightRequest()
    }

    Timer {
        id: actionRefreshDebounce
        property bool fresh: false
        interval: 900
        onTriggered: root.refresh(fresh)
    }

    Timer {
        id: resourceTimer
        interval: root.refreshIntervalSec * 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    onPopupActiveChanged: {
        if (root.popupActive)
            root.refresh()
    }
}
