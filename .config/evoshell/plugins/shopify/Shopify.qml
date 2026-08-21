import Quickshell
import QtQuick
import "../commons"
import "."

Item {
    id: root

    property var shell: null
    property bool opened: false
    property bool demoMode: false

    readonly property var dashScreen: Util.screenForOutput(
        shell && shell.barConfig ? shell.barConfig.output : "",
        "HDMI-A-1"
    )

    function close() {
        opened = false
    }

    function open() {
        if (dashScreen && dashWindow)
            dashWindow.screen = dashScreen
        opened = true
        Qt.callLater(function() { keySurface.forceActiveFocus() })
    }

    function toggle() {
        if (opened)
            close()
        else
            open()
    }

    function toggleDemoMode() {
        demoMode = !demoMode
    }

    FloatingWindow {
        id: dashWindow
        visible: root.opened && root.dashScreen !== null
        title: root.demoMode ? "evo.panels.shopify (demo)" : "evo.panels.shopify"
        screen: root.dashScreen
        color: Theme.background
        minimumSize: Qt.size(720, 680)

        Item {
            id: keySurface
            anchors.fill: parent
            focus: true

            Shortcut {
                sequence: "D"
                context: Qt.WindowShortcut
                onActivated: root.toggleDemoMode()
            }

            Shortcut {
                sequence: "Q"
                context: Qt.WindowShortcut
                onActivated: root.close()
            }

            MouseArea {
                anchors.fill: parent
                propagateComposedEvents: true
                onPressed: function(mouse) {
                    keySurface.forceActiveFocus()
                    mouse.accepted = false
                }
            }

            ShopifyModule {
                anchors.fill: parent
                shell: root.shell
                demoMode: root.demoMode
            }
        }
    }
}
