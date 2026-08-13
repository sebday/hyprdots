import Quickshell
import QtQuick
import "../../Commons"
import "."

Item {
    id: root

    property var shell: null
    property bool opened: false

    readonly property int overlayPad: 32
    readonly property int maxPopupHeight: {
        var screen = overlay.hostScreen
        if (screen && screen.height)
            return Math.max(480, screen.height - 80)
        return 1000
    }
    readonly property int wantedHeight: themeContent.implicitHeight + overlayPad
    readonly property int popupHeight: Math.min(Math.max(wantedHeight, 200), maxPopupHeight)

    function open(payloadJson) {
        opened = true
        themeContent.onActivated()
    }

    function close() {
        opened = false
    }

    function dismiss() {
        if (shell) shell.hide("evo.theme")
        else close()
    }

    CenteredOverlay {
        id: overlay
        opened: root.opened
        layerNamespace: "evo-theme"
        contentWidth: 656
        contentHeight: root.popupHeight
        onDismissed: root.dismiss()

        Flickable {
            anchors.fill: parent
            clip: interactive
            contentWidth: width
            contentHeight: themeContent.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            interactive: contentHeight > height

            ThemeModule {
                id: themeContent
                width: parent.width
            }
        }
    }
}
