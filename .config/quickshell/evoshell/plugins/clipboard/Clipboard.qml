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
        if (shell)
            shell.hide("evo.clipboard")
        else
            close()
    }

    CenteredOverlay {
        opened: root.opened
        layerNamespace: "evo-clipboard"
        contentWidth: Theme.overlayPanelWidth
        contentHeight: 640
        framed: true
        borderWidth: 2
        keysTarget: clipboardContent
        onDismissed: root.dismiss()

        AppClipboard {
            id: clipboardContent
            anchors.fill: parent
            host: root
            shell: root.shell
        }
    }
}
