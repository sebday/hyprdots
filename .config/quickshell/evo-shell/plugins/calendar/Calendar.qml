import QtQuick
import "../../Commons"
import "."

Item {
    id: root

    property var shell: null
    property bool opened: false

    function open(payloadJson) {
        opened = true
        calendarContent.onActivated()
    }

    function close() {
        opened = false
    }

    AttachedOverlay {
        opened: root.opened
        layerNamespace: "evo-calendar"
        contentWidth: 380
        contentHeight: Math.max(260, calendarContent.implicitHeight + 24)
        contentMargin: 12
        anchorItem: root.shell ? root.shell.popupAnchorItem : null
        anchorWindow: root.shell ? root.shell.popupAnchorWindow : null
        barPosition: root.shell && root.shell.barConfig && root.shell.barConfig.position
            ? String(root.shell.barConfig.position)
            : "bottom"
        onHoverEntered: if (root.shell) root.shell.popupHoverEnter()
        onHoverLeft: if (root.shell) root.shell.popupHoverLeave()

        CalendarModule {
            id: calendarContent
            anchors.fill: parent
            host: root
        }
    }
}
