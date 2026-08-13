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

    AttachedOverlay {
        opened: root.opened
        layerNamespace: "evo-cursor"
        contentWidth: 380
        contentHeight: Math.max(320, cursorContent.implicitHeight + 24)
        contentMargin: 12
        anchorItem: root.shell ? root.shell.popupAnchorItem : null
        anchorWindow: root.shell ? root.shell.popupAnchorWindow : null
        barPosition: root.shell && root.shell.barConfig && root.shell.barConfig.position
            ? String(root.shell.barConfig.position)
            : "bottom"
        onHoverEntered: if (root.shell) root.shell.popupHoverEnter()
        onHoverLeft: if (root.shell) root.shell.popupHoverLeave()

        CursorModule {
            id: cursorContent
            anchors.fill: parent
            host: root
            breakdownInset: 8
        }
    }
}
