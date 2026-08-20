import QtQuick
import "../../../Commons"

Item {
    id: root

    property string text: ""
    property bool active: false
    property bool clickable: false
    property color activeFill: Theme.withOpacity(Theme.accent, 0.18)
    property color inactiveFill: Theme.foregroundGhost
    property color activeText: Theme.accent
    property color inactiveText: Theme.foreground
    property real inactiveOpacity: Theme.opacitySecondary
    property int fontSize: Theme.fontSizeS

    signal clicked()

    implicitWidth: pill.implicitWidth
    implicitHeight: 24
    width: implicitWidth
    height: implicitHeight
    visible: root.text !== ""

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: 12
        color: root.active ? root.activeFill : root.inactiveFill
        border.width: root.active ? 1 : 0
        border.color: Theme.accent
        implicitWidth: label.implicitWidth + 16

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            color: root.active ? root.activeText : root.inactiveText
            font.family: Theme.fontFamily
            font.pixelSize: root.fontSize
            font.bold: Theme.fontBold
            opacity: root.active ? 1 : root.inactiveOpacity
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.clickable
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
