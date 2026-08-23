import Quickshell
import QtQuick
import "../../commons"
import "."

Item {
    id: root

    property var shell: null
    property bool opened: false
    readonly property string activeModule: "settings"

    readonly property int viewportMaxHeight: Theme.menuPanelHeight(
        Quickshell.screens.length > 0 ? Quickshell.screens[0].height : 1080)

    function open(payloadJson) {
        opened = true
        settingsContent.onActivated()
    }

    function close() {
        opened = false
    }

    function dismiss() {
        if (shell)
            shell.hide("evo.sys.settings")
        else
            close()
    }

    CenteredOverlay {
        opened: root.opened
        layerNamespace: "evo-sys-settings"
        contentWidth: Theme.settingsPanelWidth
        contentHeight: root.viewportMaxHeight
        fitContentHeight: false
        maxContentHeight: root.viewportMaxHeight
        framed: true
        borderWidth: 2
        keysTarget: settingsContent
        onDismissed: root.dismiss()

        SettingsModule {
            id: settingsContent
            width: parent.width
            height: parent.height
            host: root
            shell: root.shell
        }
    }
}
