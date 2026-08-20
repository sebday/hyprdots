import Quickshell
import QtQuick
import "../../Commons"
import "../panel/modules"

Item {
    id: root

    property var shell: null
    property bool opened: false
    readonly property string activeModule: "settings"

    function open(payloadJson) {
        opened = true
        settingsContent.onActivated()
    }

    function close() {
        opened = false
    }

    function dismiss() {
        if (shell)
            shell.hide("evo.settings")
        else
            close()
    }

    CenteredOverlay {
        opened: root.opened
        layerNamespace: "evo-settings"
        contentWidth: Theme.overlayPanelWidth
        fitContentHeight: true
        framed: true
        borderWidth: 2
        keysTarget: settingsContent
        onDismissed: root.dismiss()

        SettingsModule {
            id: settingsContent
            width: parent.width
            host: root
            shell: root.shell
        }
    }
}
