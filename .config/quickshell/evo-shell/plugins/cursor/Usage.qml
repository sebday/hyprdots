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
        usageContent.onActivated()
    }

    function close() {
        opened = false
    }

    function dismiss() {
        if (shell) shell.hide("evo.cursor-usage")
        else close()
    }

    CenteredOverlay {
        opened: root.opened
        layerNamespace: "evo-cursor-usage"
        preferredOutput: root.shell ? root.shell.overlayOutput : "DP-1"
        contentWidth: 420
        contentHeight: 580
        onDismissed: root.dismiss()

        UsageModule {
            id: usageContent
            anchors.fill: parent
            host: root
        }
    }
}
