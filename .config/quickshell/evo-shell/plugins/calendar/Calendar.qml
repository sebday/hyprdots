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
        calendarContent.onActivated()
    }

    function close() {
        opened = false
    }

    function dismiss() {
        if (shell) shell.hide("evo.calendar")
        else close()
    }

    CenteredOverlay {
        opened: root.opened
        layerNamespace: "evo-calendar"
        contentWidth: 520
        contentHeight: 440
        onDismissed: root.dismiss()

        CalendarModule {
            id: calendarContent
            anchors.fill: parent
            host: root
        }
    }
}
