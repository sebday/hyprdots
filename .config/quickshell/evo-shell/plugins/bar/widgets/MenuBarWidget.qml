import QtQuick
import "../../../Commons"

Item {
    property var bar: null
    property var shell: null
    property var settings: ({})

    implicitWidth: label.implicitWidth
    implicitHeight: Theme.barHeight

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        text: "󰍉"
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.barFontPixelSize
        font.bold: Theme.fontBold
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (shell) shell.toggle("evo.panel", '{"module":"settings"}')
    }
}
