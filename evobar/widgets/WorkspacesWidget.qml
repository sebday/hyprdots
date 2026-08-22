import QtQuick
import Quickshell.Hyprland
import "../../commons"

Row {
    property var bar: null
    property var settings: ({})

    spacing: 4
    height: Theme.barHeight

    Repeater {
        model: Hyprland.workspaces

        Item {
            required property var modelData

            readonly property int workspaceId: modelData ? Number(modelData.id) : 0
            readonly property bool workspaceVisible: isFinite(workspaceId) && workspaceId > 0

            visible: workspaceVisible
            width: workspaceVisible ? wsLabel.implicitWidth + 8 : 0
            height: Theme.barHeight

            Text {
                id: wsLabel
                anchors.centerIn: parent
                text: String(modelData ? modelData.id : "")
                color: (Hyprland.focusedWorkspace && modelData && modelData.id === Hyprland.focusedWorkspace.id) ? Theme.accent : Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeM
                font.bold: Theme.fontBold
            }

            MouseArea {
                anchors.fill: parent
                enabled: workspaceVisible
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (modelData) Hyprland.dispatch("workspace " + modelData.id)
            }
        }
    }
}
