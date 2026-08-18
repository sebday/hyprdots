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
        spacing: Theme.spacingL

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing2

            Text {
                text: root.label
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeM
                font.bold: Theme.fontBold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                visible: root.detail !== ""
                text: root.detail
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                opacity: Theme.opacityMuted
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Item {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 24

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusToggleTrack
                color: root.checked ? Theme.accent : Theme.foregroundSubtle
                opacity: root.enabled ? 1 : Theme.opacityDisabled

                Rectangle {
                    width: 18
                    height: 18
                    radius: Theme.radiusToggleThumb
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
