import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import "../../commons"

Item {
    id: root

    property var trayItem: null
    property int iconSize: 18
    property int iconSourceSize: iconSize
    property bool insyncSyncing: false

    readonly property string trayKey: {
        if (!trayItem)
            return ""
        return String(trayItem.id || trayItem.title || "").toLowerCase()
    }

    readonly property bool isInsyncTray: trayKey.indexOf("insync") >= 0
    readonly property bool shouldSpin: isInsyncTray && insyncSyncing
    readonly property string insyncScript: Util.evoshellScript(Quickshell.env("HOME") || "", shell, "evo-bar-insync popup")

    readonly property var glyphRules: ({
        "insync": {
            defaultGlyph: "󰓦"
        },
        "steam": {
            defaultGlyph: "󰓓"
        }
    })

    readonly property var matchedRule: {
        var key = trayKey
        if (!key)
            return null
        if (glyphRules[key])
            return glyphRules[key]
        for (var id in glyphRules) {
            if (key.indexOf(id) >= 0)
                return glyphRules[id]
        }
        return null
    }

    readonly property string overrideGlyph: {
        var rule = matchedRule
        if (!rule)
            return ""
        var iconHint = String(trayItem.icon || "").toLowerCase()
        if (rule.syncingGlyph && rule.syncHint && iconHint.indexOf(rule.syncHint) >= 0)
            return rule.syncingGlyph
        return rule.defaultGlyph || ""
    }

    readonly property bool useOverride: overrideGlyph !== ""

    readonly property bool attentionPulse: trayItem && trayItem.status === Status.NeedsAttention

    readonly property bool trayHasContent: {
        if (!trayItem)
            return false
        if (useOverride)
            return true
        return String(trayItem.icon || "") !== ""
    }

    implicitWidth: iconSize
    implicitHeight: iconSize

    function refreshInsyncSync() {
        if (!isInsyncTray || !insyncScript || insyncProc.running)
            return
        insyncProc.running = true
    }

    function applyInsyncPayload(raw) {
        var text = String(raw || "").trim()
        if (!text)
            return
        try {
            var json = JSON.parse(text)
            insyncSyncing = Array.isArray(json.files) && json.files.length > 0 && json.paused !== true
        } catch (e) {
        }
    }

    onIsInsyncTrayChanged: {
        if (!isInsyncTray)
            insyncSyncing = false
        else
            refreshInsyncSync()
    }

    Timer {
        id: insyncPoll
        interval: 2000
        repeat: true
        running: root.isInsyncTray
        onTriggered: root.refreshInsyncSync()
        onRunningChanged: if (running) triggered()
    }

    Process {
        id: insyncProc
        command: ["bash", "-lc", root.insyncScript]
        stdout: StdioCollector {
            onStreamFinished: root.applyInsyncPayload(text)
        }
    }

    Item {
        id: iconHost
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize

        RotationAnimation on rotation {
            from: 0
            to: 360
            duration: 4000
            loops: Animation.Infinite
            running: root.shouldSpin
        }

        Text {
            id: overrideGlyphText
            anchors.centerIn: parent
            visible: root.useOverride
            text: root.overrideGlyph
            opacity: root.attentionPulse ? Theme.barIconPulseMax : Theme.barIconOpacity
            font.family: Theme.fontFamily
            font.pixelSize: root.iconSize
            font.bold: Theme.fontBold
        }

        BarIconPulse {
            target: overrideGlyphText
            running: root.useOverride && root.attentionPulse
        }

        Image {
            anchors.centerIn: parent
            visible: !root.useOverride
            width: root.iconSize
            height: root.iconSize
            source: trayItem ? trayItem.icon : ""
            sourceSize.width: root.iconSourceSize
            sourceSize.height: root.iconSourceSize
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            cache: false
            asynchronous: true
        }
    }

    onShouldSpinChanged: if (!shouldSpin)
        iconHost.rotation = 0
}
