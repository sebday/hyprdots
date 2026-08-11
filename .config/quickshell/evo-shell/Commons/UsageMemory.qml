pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string statePath: (Quickshell.env("HOME") || "") + "/.local/state/evo-shell/usage.json"
    readonly property string bumpScript: (Quickshell.env("HOME") || "") + "/.local/bin/evo-usage.sh"

    property var counts: ({ apps: {}, emojis: {} })

    FileView {
        id: usageFile
        path: root.statePath
        watchChanges: false
        printErrors: false
        onLoaded: root.loadFromFile()
        onLoadFailed: root.resetCounts()
    }

    function resetCounts() {
        counts = { apps: {}, emojis: {} }
    }

    function loadFromFile() {
        var text = usageFile.text() || ""
        if (!text.trim()) {
            resetCounts()
            return
        }
        try {
            var parsed = JSON.parse(text)
            counts = {
                apps: parsed.apps || {},
                emojis: parsed.emojis || {}
            }
        } catch (e) {
            resetCounts()
        }
    }

    function reload() {
        usageFile.reload()
    }

    function score(bucket, key) {
        var k = String(key || "")
        if (!k) return 0
        var bucketData = counts[bucket] || {}
        return bucketData[k] || 0
    }

    function bump(bucket, key) {
        var k = String(key || "")
        if (!k || !bumpScript) return
        Quickshell.execDetached(["bash", bumpScript, "bump", String(bucket), k])
        var next = {
            apps: {},
            emojis: {}
        }
        for (var a in counts.apps) next.apps[a] = counts.apps[a]
        for (var e in counts.emojis) next.emojis[e] = counts.emojis[e]
        if (bucket === "apps") next.apps[k] = (next.apps[k] || 0) + 1
        else if (bucket === "emojis") next.emojis[k] = (next.emojis[k] || 0) + 1
        counts = next
    }

    function sortByUsage(items, bucket, keyFn, nameFn) {
        var copy = items.slice()
        copy.sort(function(a, b) {
            var sa = score(bucket, keyFn(a))
            var sb = score(bucket, keyFn(b))
            if (sa !== sb) return sb - sa
            if (nameFn) return String(nameFn(a)).localeCompare(String(nameFn(b)))
            return 0
        })
        return copy
    }

    Component.onCompleted: reload()
}
