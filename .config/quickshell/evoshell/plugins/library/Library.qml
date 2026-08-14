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
        libraryContent.onActivated()
    }

    function close() {
        opened = false
    }

    function dismiss() {
        if (shell) shell.hide("evo.library")
        else close()
    }

    CenteredOverlay {
        opened: root.opened
        layerNamespace: "evo-library"
        framed: false
        scrim: true
        scrimColor: Theme.mantle
        fillScreen: true
        contentMargin: 24
        keysTarget: libraryContent
        onDismissed: root.dismiss()

        LibraryModule {
            id: libraryContent
            anchors.fill: parent
            host: root
        }
    }
}
