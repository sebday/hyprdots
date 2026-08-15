import QtQuick
import "../../Commons"
import "."

Item {
    id: root

    property var shell: null
    property bool opened: false

    function open(payloadJson) {
        opened = true
        soundContent.onActivated()
    }

    function close() {
        opened = false
        soundContent.onDeactivated()
    }

    BarHoverPopup {
        shell: root.shell
        opened: root.opened
        layerNamespace: "evo-sound"
        contentWidth: 400
        contentHeight: soundContent.implicitHeight + 24
        contentMargin: 12

        SoundModule {
            id: soundContent
            anchors.fill: parent
            host: root
        }
    }
}
