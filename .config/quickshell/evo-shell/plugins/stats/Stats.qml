import Quickshell
import QtQuick
import "../../Commons"
import "../panel/modules"

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
        preferredOutput: root.shell ? root.shell.overlayOutput : "DP-1"
        contentWidth: 460
        contentHeight: 650
        onDismissed: root.dismiss()

        StatsModule {
            id: statsContent
            anchors.fill: parent
            host: root
        }
    }
}
