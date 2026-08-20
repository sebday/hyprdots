import Quickshell
import QtQuick
import "../../../Commons"
import "."

Item {
    id: root

    property var shell: null
    property bool opened: false

    function open(payloadJson) {
        libraryContent.applyOpenRequest(payloadJson)
        opened = true
        libraryContent.onActivated()
    }

    function reopen(payloadJson) {
        open(payloadJson)
        return true
    }

    function close() {
        opened = false
    }

    function dismiss() {
        if (shell) shell.hide("evo.bar.media.library")
        else close()
    }

    CenteredOverlay {
        opened: root.opened
        layerNamespace: "evo-bar-media-library"
        framed: true
        fillScreen: false
        contentWidth: 1600
        contentHeight: 900
        borderWidth: 2
        keysTarget: libraryContent
        onDismissed: root.dismiss()

        LibraryModule {
            id: libraryContent
            anchors.fill: parent
            host: root
        }
    }
}
