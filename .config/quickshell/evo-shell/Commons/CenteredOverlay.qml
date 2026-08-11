import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

Item {
    id: root

    property bool opened: false
    property int contentWidth: 420
    property int contentHeight: 520
    property int contentMargin: 16
    property string layerNamespace: "evo-overlay"
    property var hostScreen: null
    signal dismissed()

    default property alias content: contentHost.data

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

    onOpenedChanged: {
        if (opened)
            hostScreen = resolveHostScreen()
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.opened && root.hostScreen && modelData && modelData.name !== root.hostScreen.name
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            WlrLayershell.namespace: root.layerNamespace
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            Rectangle {
                anchors.fill: parent
                color: Theme.background
                opacity: 0.58
            }
        }
    }

    PanelWindow {
        screen: root.hostScreen
        visible: root.opened
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.namespace: root.layerNamespace
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore

        Rectangle {
            anchors.fill: parent
            color: Theme.background
            opacity: 0.58
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.dismissed()
        }

        Item {
            id: contentFrame
            z: 1
            anchors.centerIn: parent
            width: root.contentWidth
            height: root.contentHeight
            focus: root.opened

            Keys.onEscapePressed: root.dismissed()

            MouseArea {
                anchors.fill: parent
                onClicked: mouse.accepted = true
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.background
                border.color: Theme.accent
                border.width: 1
            }

            Item {
                id: contentHost
                anchors.fill: parent
                anchors.margins: root.contentMargin
            }
        }
    }
}
