import QtQuick
import Quickshell.Services.SystemTray
import "../../../Commons"

Item {
    id: root

    property var trayItem: null
    property int iconSize: 18
    property int iconSourceSize: iconSize

    readonly property string trayKey: {
        if (!trayItem)
            return ""
        return String(trayItem.id || trayItem.title || "").toLowerCase()
    }

    readonly property var glyphRules: ({
        "insync": {
            defaultGlyph: "󰉋",
            syncingGlyph: "󰉚",
            syncHint: "syncing"
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

    readonly property color glyphColor: {
        if (!trayItem)
            return Theme.foreground
        if (trayItem.status === Status.NeedsAttention)
            return Theme.urgent
        return Theme.foreground
    }

    implicitWidth: iconSize
    implicitHeight: iconSize

    Text {
        anchors.centerIn: parent
        visible: root.useOverride
        text: root.overrideGlyph
        color: root.glyphColor
        font.family: Theme.fontFamily
        font.pixelSize: root.iconSize
        font.bold: Theme.fontBold
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
