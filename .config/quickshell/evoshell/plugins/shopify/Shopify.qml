import Quickshell
import QtQuick
import "../../Commons"
import "."

Item {
    id: root

    property var shell: null

    readonly property string dashOutput: {
        if (shell && shell.shellConfig && shell.shellConfig.notifications && shell.shellConfig.notifications.output)
            return String(shell.shellConfig.notifications.output).trim()
        if (shell && shell.barConfig && shell.barConfig.output)
            return String(shell.barConfig.output).trim()
        return "HDMI-A-1"
    }

    readonly property var dashScreen: {
        var screens = Quickshell.screens
        if (!screens || screens.length === 0)
            return null
        var output = dashOutput
        if (output) {
            for (var i = 0; i < screens.length; i++) {
                if (screens[i] && String(screens[i].name) === output)
                    return screens[i]
            }
        }
        return screens[0]
    }

    FloatingWindow {
        id: dashWindow
        visible: true
        title: "shopify"
        screen: root.dashScreen
        color: Theme.background
        minimumSize: Qt.size(720, 520)

        ShopifyModule {
            anchors.fill: parent
            shell: root.shell
        }
    }
}
