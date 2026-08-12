import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import "../../Commons"
import "."

Item {
    id: root

    property var shell: null
    property bool opened: false
    property var hostScreen: null

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/evo-media.sh"

    function resolveHostScreen() {
        try {
            var mon = Hyprland.focusedMonitor
            if (mon) {
                for (var i = 0; i < Quickshell.screens.length; i++) {
                    var s = Quickshell.screens[i]
                    if (s && s.name === mon.name)
                        return s
                }
            }
        } catch (e) {}
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }

    function open(payloadJson) {
        hostScreen = resolveHostScreen()
        opened = true
        mediaContent.onActivated()
    }

    function close() {
        opened = false
        mediaContent.resetView()
    }

    function dismiss() {
        if (shell) shell.hide("evo.media")
        else close()
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.opened && root.hostScreen && modelData && modelData.name !== root.hostScreen.name
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            color: "transparent"
            WlrLayershell.namespace: "evo-media"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            Rectangle {
                anchors.fill: parent
                color: Theme.background
            }
        }
    }

    PanelWindow {
        id: panel
        screen: root.hostScreen
        visible: root.opened
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        color: "transparent"
        WlrLayershell.namespace: "evo-media"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore

        Rectangle {
            anchors.fill: parent
            color: Theme.background
        }

        MediaModule {
            id: mediaContent
            anchors.fill: parent
            host: root
            shell: root.shell
            active: root.opened
        }
    }
}
