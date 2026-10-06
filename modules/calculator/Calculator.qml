import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs.commons
import "."

Item {
    id: root

    property var shell: null
    property bool opened: false
    property var openScreen: null

    // Qt names screens by model, so identical panels never match a connector.
    function focusedScreen() {
        var screens = Quickshell.screens
        var monitor = Hyprland.focusedMonitor
        if (!monitor)
            return screens.length > 0 ? screens[0] : null
        var name = String(monitor.name || "")
        for (var i = 0; i < screens.length; i++) {
            if (screens[i] && String(screens[i].name || "") === name)
                return screens[i]
        }
        for (var j = 0; j < screens.length; j++) {
            var screen = screens[j]
            if (screen && screen.x === monitor.x && screen.y === monitor.y)
                return screen
        }
        return screens.length > 0 ? screens[0] : null
    }

    function open(payloadJson) {
        openScreen = focusedScreen()
        opened = true
        calcContent.onActivated()
    }

    function close() {
        opened = false
    }

    function dismiss() {
        if (shell)
            shell.hide("evo.calculator")
        else
            close()
    }

    FloatingWindow {
        id: calcWindow
        title: "Calculator"
        visible: root.opened
        screen: root.openScreen
        color: Theme.background
        implicitWidth: Theme.clipboardPanelWidth
        implicitHeight: Math.max(1, calcContent.implicitHeight + Theme.overlayTopInset + Theme.overlayMargin)

        // Super+W closes the toplevel. Escape goes through the input.
        onClosed: {
            if (root.opened)
                root.dismiss()
        }

        AppCalc {
            id: calcContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Theme.overlaySideInset
            anchors.rightMargin: Theme.overlaySideInset
            anchors.topMargin: Theme.overlayTopInset
            host: root
            shell: root.shell
        }
    }
}
