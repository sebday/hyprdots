import Quickshell
import QtQuick
import "../../Commons"
import "."

Item {
    id: root

    property var shell: null
    property bool opened: false
    property string pluginId: "evo.theme"
    property string kind: "themes"
    property string layerNamespace: "evo-theme"

    readonly property int maxPopupHeight: {
        var screens = Quickshell.screens
        if (screens && screens.length > 0 && screens[0].height)
            return Math.max(480, screens[0].height - 80)
        return 1000
    }
    readonly property int popupWidth: Math.max(pickerContent.implicitWidth, 200)
    readonly property int popupHeight: Math.min(
        Math.max(pickerContent.implicitHeight, 200),
        maxPopupHeight
    )

    function open(payloadJson) {
        opened = true
        pickerContent.onActivated()
        Qt.callLater(function() {
            pickerFlick.ensureCursorVisible()
        })
    }

    function close() {
        opened = false
    }

    function dismiss() {
        if (shell) shell.hide(pluginId)
        else close()
    }

    CenteredOverlay {
        id: overlay
        opened: root.opened
        layerNamespace: root.layerNamespace
        framed: false
        contentMargin: 0
        contentWidth: root.popupWidth
        contentHeight: root.popupHeight
        keysTarget: pickerContent
        onDismissed: root.dismiss()

        Flickable {
            id: pickerFlick
            anchors.fill: parent
            clip: interactive
            contentWidth: width
            contentHeight: pickerContent.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            interactive: contentHeight > height

            function ensureCursorVisible() {
                var y = pickerContent.cursorY()
                var h = pickerContent.tileHeight
                if (y < contentY)
                    contentY = Math.max(0, y - 12)
                else if (y + h > contentY + height)
                    contentY = Math.min(Math.max(0, contentHeight - height), y + h - height + 12)
            }

            ThemeModule {
                id: pickerContent
                kind: root.kind
                width: implicitWidth
                height: implicitHeight
                anchors.horizontalCenter: parent.horizontalCenter
                onCursorMoved: pickerFlick.ensureCursorVisible()
                onPicked: root.dismiss()
            }
        }
    }
}
