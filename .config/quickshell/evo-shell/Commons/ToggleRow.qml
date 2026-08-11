import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string label: ""
    property string detail: ""
    property bool checked: false
    property bool enabled: true

    signal toggled()

    implicitHeight: row.implicitHeight
    implicitWidth: 200

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: root.label
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.bold: Theme.fontBold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                visible: root.detail !== ""
                text: root.detail
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 11
                opacity: 0.55
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Item {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 24

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: root.checked ? Theme.accent : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.16)
                opacity: root.enabled ? 1 : 0.45

                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    y: 3
                    x: root.checked ? parent.width - width - 3 : 3
                    color: root.checked ? Theme.background : Theme.foreground
                    Behavior on x {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
