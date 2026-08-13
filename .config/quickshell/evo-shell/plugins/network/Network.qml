import Quickshell
import QtQuick
import "../../Commons"
import "."

Item {
    id: root

    property var shell: null
    property bool opened: false

    function open(payloadJson) {
        opened = true
        networkContent.onActivated()
    }

    function close() {
        opened = false
        networkContent.onDeactivated()
    }

    BarHoverPopup {
        shell: root.shell
        opened: root.opened
        layerNamespace: "evo-network"
        contentWidth: 420
        contentHeight: networkContent.implicitHeight + 24
        contentMargin: 12

        NetworkModule {
            id: networkContent
            width: parent.width
            host: root
        }
    }
}
