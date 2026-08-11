import QtQuick
import Quickshell.Hyprland
import "../../../Commons"

Row {
    property var bar: null
    property var settings: ({})
    spacing: 4
    height: Theme.barHeight

    Repeater {
        model: Hyprland.workspaces

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
