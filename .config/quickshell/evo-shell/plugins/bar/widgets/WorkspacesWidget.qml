import QtQuick
import Quickshell.Hyprland
import "../../../Commons"

Row {
    property var bar: null
    property var settings: ({})

    readonly property var visibleWorkspaces: {
        var out = []
        var all = Hyprland.workspaces || []
        for (var i = 0; i < all.length; i++) {
            var ws = all[i]
            if (!ws) continue
            var id = Number(ws.id)
            if (!isFinite(id) || id <= 0) continue
            out.push(ws)
        }
        out.sort(function(a, b) { return Number(a.id) - Number(b.id) })
        return out
    }

    spacing: 4
    height: Theme.barHeight

    Repeater {
        model: visibleWorkspaces

        Item {
            required property var modelData
            width: wsLabel.implicitWidth + 8
            height: Theme.barHeight

            Text {
                id: wsLabel
                anchors.centerIn: parent
                text: String(modelData ? modelData.id : "")
                color: (Hyprland.focusedWorkspace && modelData && modelData.id === Hyprland.focusedWorkspace.id) ? Theme.accent : Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPixelSize
                font.bold: Theme.fontBold
            }

            MouseArea {
                anchors.fill: parent
                onClicked: if (modelData) Hyprland.dispatch("workspace " + modelData.id)
            }
        }
    }
}
