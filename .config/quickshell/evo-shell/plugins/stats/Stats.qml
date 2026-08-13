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
        statsContent.onActivated()
    }

    function close() {
        opened = false
    }

    function dismiss() {
        if (shell) shell.hide("evo.stats")
        else close()
    }

    CenteredOverlay {
        opened: root.opened
        layerNamespace: "evo-stats"
        contentWidth: 720
        contentHeight: 380
        onDismissed: root.dismiss()

        StatsModule {
            id: statsContent
            anchors.fill: parent
            host: root
        }
    }
}
