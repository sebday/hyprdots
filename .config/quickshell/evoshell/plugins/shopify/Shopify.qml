import Quickshell
import QtQuick
import "../../Commons"
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

    function handleKey(event) {
        if (event.key === Qt.Key_Q) {
            root.close()
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_D) {
            root.toggleDemoMode()
            event.accepted = true
        }
    }

    FloatingWindow {
        id: dashWindow
        visible: root.opened && root.dashScreen !== null
        title: root.demoMode ? "evo.shopify (demo)" : "evo.shopify"
        screen: root.dashScreen
        color: Theme.background
        minimumSize: Qt.size(720, 680)

        Item {
            id: keySurface
            anchors.fill: parent
            focus: false

            MouseArea {
                anchors.fill: parent
                propagateComposedEvents: true
                onPressed: function(mouse) {
                    keySurface.forceActiveFocus()
                    mouse.accepted = false
                }
            }

            Keys.onPressed: root.handleKey(event)

            ShopifyModule {
                anchors.fill: parent
                shell: root.shell
                demoMode: root.demoMode
            }
        }
    }
}
