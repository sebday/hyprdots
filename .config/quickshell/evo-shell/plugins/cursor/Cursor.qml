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
        cursorContent.onActivated()
    }

    function close() {
        opened = false
    }

    function dismiss() {
        if (shell) shell.hide("evo.cursor")
        else close()
    }

    CenteredOverlay {
        opened: root.opened
        layerNamespace: "evo-cursor"
        contentWidth: 440
        contentHeight: Math.max(360, cursorContent.implicitHeight + 32)
        onDismissed: root.dismiss()

        UsageModule {
            id: cursorContent
            width: parent.width
            host: root
            expandModels: true
        }
    }
}
