import QtQuick
import "../../Commons"

Text {
    property var shell: null

    text: "󰍉"
    color: Theme.foreground
    font.family: Theme.fontFamily
    font.pixelSize: 14

    MouseArea {
        anchors.fill: parent
        onClicked: if (shell) shell.toggle("evo.menu", '{"mode":"system"}')
    }
}
