import QtQuick
import "../../Commons"
import "."

Item {
    id: root

    property var shell: null
    property bool opened: false

    function open(payloadJson) {
        opened = true
        statsContent.onActivated()
    }

    function close() {
        opened = false
    }

    AttachedOverlay {
        opened: root.opened
        layerNamespace: "evo-stats"
        contentWidth: 580
        contentHeight: 380
        contentMargin: 10
        anchorItem: root.shell ? root.shell.popupAnchorItem : null
        anchorWindow: root.shell ? root.shell.popupAnchorWindow : null
        barPosition: root.shell && root.shell.barConfig && root.shell.barConfig.position
            ? String(root.shell.barConfig.position)
            : "bottom"
        onHoverEntered: if (root.shell) root.shell.popupHoverEnter()
        onHoverLeft: if (root.shell) root.shell.popupHoverLeave()

        StatsModule {
            id: statsContent
            anchors.fill: parent
            host: root
        }
    }
}
