import Quickshell
import QtQuick
import "../../../commons"
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
        if (shell) shell.hide("evo.panels.media.library")
        else close()
    }

    CenteredOverlay {
        opened: root.opened
        layerNamespace: "evo-panels-media-library"
        framed: false
        fillScreen: true
        backgroundColor: Theme.background
        contentMargin: 0
        contentTopMargin: 0
        keysTarget: libraryContent
        onDismissed: root.dismiss()

        LibraryModule {
            id: libraryContent
            anchors.fill: parent
            host: root
        }
    }
}
