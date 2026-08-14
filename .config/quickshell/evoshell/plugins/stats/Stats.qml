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

    BarHoverPopup {
        shell: root.shell
        opened: root.opened
        layerNamespace: "evo-stats"
        contentWidth: 580
        contentHeight: 380
        contentMargin: 10

        StatsModule {
            id: statsContent
            anchors.fill: parent
            host: root
        }
    }
}
