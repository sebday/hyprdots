import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    property var modules: []
    property string activeId: ""
    property int buttonSize: 30

    signal moduleActivated(string id)

    spacing: 6

    Repeater {
        model: root.modules

        delegate: Item {
            required property var modelData
            Layout.preferredWidth: root.buttonSize
            Layout.preferredHeight: root.buttonSize

            readonly property bool isActive: modelData.id === root.activeId

            Rectangle {
                anchors.fill: parent
                radius: Theme.panelCornerRadius
                color: isActive ? Theme.panelMantle : "transparent"
                border.color: isActive ? Theme.accent : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.2)
                border.width: 1
                opacity: moduleMouse.containsMouse || isActive ? 1 : 0.75
            }

            Text {
                anchors.centerIn: parent
                text: modelData.icon
                color: isActive ? Theme.accent : Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.panelIconFontPixelSize
                font.bold: Theme.fontBold
            }

            MouseArea {
                id: moduleMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.moduleActivated(modelData.id)
            }
        }
    }

    Item { Layout.fillWidth: true }
}
