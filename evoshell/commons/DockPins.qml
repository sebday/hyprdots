pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Pinned apps shared by the dock and the launcher. Pins are stored as written
// in modules/dock/pins.json (a desktop id or a name for heuristic lookup), so
// reordering keeps hand-written entries intact.
Singleton {
    id: root

    property var pins: []
    property int entriesRevision: 0
    readonly property string pinsPath: Quickshell.shellDir + "/modules/dock/pins.json"

    // Desktop id per pin, "" when the pin does not resolve to an installed app.
    readonly property var resolvedIds: {
        var rev = entriesRevision
        var out = []
        for (var i = 0; i < pins.length; i++) {
            var entry = lookupEntry(pins[i])
            out.push(entry ? pinKey(entry.id) : "")
        }
        return out
    }

    function pinKey(id) {
        var key = String(id || "").trim()
        if (key.toLowerCase().endsWith(".desktop"))
            key = key.slice(0, -8)
        return key
    }

    function lookupEntry(pin) {
        var key = pinKey(pin)
        if (!key)
            return null
        var direct = DesktopEntries.byId(key)
        if (direct)
            return direct
        var withSuffix = DesktopEntries.byId(key + ".desktop")
        if (withSuffix)
            return withSuffix
        var guessed = DesktopEntries.heuristicLookup(key)
        if (guessed)
            return guessed
        var values = DesktopEntries.applications.values || []
        var want = key.toLowerCase()
        for (var i = 0; i < values.length; i++) {
            var entry = values[i]
            if (entry && pinKey(entry.id).toLowerCase() === want)
                return entry
        }
        return null
    }

    function pinIndexOf(appId) {
        var key = pinKey(appId)
        if (!key)
            return -1
        var ids = resolvedIds
        for (var i = 0; i < ids.length; i++) {
            if (ids[i] === key)
                return i
        }
        return -1
    }

    function isPinned(appId) {
        return pinIndexOf(appId) >= 0
    }

    function save(next) {
        pins = next
        pinsFile.setText(JSON.stringify(next, null, 2) + "\n")
    }

    function toggle(appId) {
        var key = pinKey(appId)
        if (!key)
            return
        var index = pinIndexOf(key)
        var next = pins.slice()
        if (index >= 0)
            next.splice(index, 1)
        else
            next.push(key)
        save(next)
    }

    // Move the pin at `from` so it lands before (or after) the pin at `target`.
    function movePin(from, target, after) {
        if (from < 0 || from >= pins.length || target < 0 || target >= pins.length)
            return
        var insertAt = after ? target + 1 : target
        if (insertAt > from)
            insertAt--
        if (insertAt === from)
            return
        var next = pins.slice()
        var moved = next.splice(from, 1)[0]
        next.splice(insertAt, 0, moved)
        save(next)
    }

    function moveApp(appId, targetAppId, after) {
        movePin(pinIndexOf(appId), pinIndexOf(targetAppId), after)
    }

    function applyText(raw) {
        var next = []
        try {
            var data = JSON.parse(String(raw || "").trim() || "[]")
            if (Array.isArray(data))
                next = data
        } catch (e) {
            next = []
        }
        pins = next
    }

    FileView {
        id: pinsFile
        path: root.pinsPath
        watchChanges: true
        printErrors: false
        onLoaded: root.applyText(text())
        onLoadFailed: root.pins = []
        onFileChanged: reload()
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.entriesRevision++
        }
    }
}
