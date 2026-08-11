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
        clipboardContent.onActivated()
    }

    function close() {
        opened = false
    }

    function dismiss() {
        if (shell) shell.hide("evo.clipboard-history")
        else close()
    }

    CenteredOverlay {
        opened: root.opened
        layerNamespace: "evo-clipboard-history"
        preferredOutput: root.shell ? root.shell.overlayOutput : "DP-1"
        contentWidth: 460
        contentHeight: 560
        onDismissed: root.dismiss()

        ClipboardModule {
            id: clipboardContent
            anchors.fill: parent
            host: root
            shell: root.shell
        }
    }
}
