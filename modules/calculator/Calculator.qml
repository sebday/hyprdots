import Quickshell
import QtQuick
import qs.commons
import "."

Item {
    id: root

    property var shell: null
    property bool opened: false

    function open(payloadJson) {
        opened = true
        calcContent.onActivated()
    }

    function close() {
        opened = false
    }

    function dismiss() {
        if (shell)
            shell.hide("evo.calculator")
        else
            close()
    }

    CenteredOverlay {
        opened: root.opened
        layerNamespace: "evo-calculator"
        contentWidth: Theme.clipboardPanelWidth
        fitContentHeight: true
        maxContentHeight: Theme.menuPanelHeight(
            Quickshell.screens.length > 0 ? Quickshell.screens[0].height : 1080)
        framed: true
        borderWidth: 2
        keysTarget: calcContent
        onDismissed: root.dismiss()

        AppCalc {
            id: calcContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            host: root
            shell: root.shell
        }
    }
}
