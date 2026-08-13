import QtQuick
import "../../Commons"
import "."

Item {
    id: root

    property var shell: null
    property bool opened: false

    function open(payloadJson) {
        opened = true
        cursorContent.onActivated()
    }

    function close() {
        opened = false
    }

    BarHoverPopup {
        shell: root.shell
        opened: root.opened
        layerNamespace: "evo-cursor"
        contentWidth: 380
        contentHeight: Math.max(320, cursorContent.implicitHeight + 24)
        contentMargin: 12

        CursorModule {
            id: cursorContent
            anchors.fill: parent
            host: root
            breakdownInset: 8
        }
    }
}
