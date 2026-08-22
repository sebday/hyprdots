import Quickshell
import QtQuick
import "../../commons"
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
            shell.hide("evo.side.clipboard")
        else
            close()
    }

    CenteredOverlay {
        opened: root.opened
        layerNamespace: "evo-side-clipboard"
        contentWidth: Theme.clipboardPanelWidth
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
