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

    BarHoverPopup {
        shell: root.shell
        opened: root.opened
        layerNamespace: "evo-calendar"
        contentWidth: 380
        contentHeight: Math.max(260, calendarContent.implicitHeight + 24)
        contentMargin: 12

        CalendarModule {
            id: calendarContent
            anchors.fill: parent
            host: root
        }
    }
}
