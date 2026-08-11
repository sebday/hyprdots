import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

Item {
    id: dock

    property string layerNamespace: "evo-dock"
    property int panelWidth: 350
    property string side: "left"
    property var screen: null
    property bool opened: false
    property bool shown: false
    property bool pinned: false
    property string title: ""
    property bool showCloseButton: false
    property bool showPinButton: false
    property bool showSideButton: false
    property int contentSpacing: 10
    property int contentMargin: 12

    readonly property bool onRight: side === "right"
    readonly property bool scrimActive: shown && opened && !pinned

    // Other outputs only — panel screen uses the in-window dismiss catcher.
    readonly property var otherScreens: {
        if (!dock.scrimActive)
            return []
        var screens = Quickshell.screens
        if (!screens || screens.length === 0)
            return []
        var panelName = dock.screen ? String(dock.screen.name) : ""
        var out = []
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i]
            if (!s)
                continue
            if (panelName && String(s.name) === panelName)
                continue
            out.push(s)
        }
        return out
    }

    signal closeRequested()
    signal pinRequested()
    signal sideRequested()

    default property alias content: contentLayout.children

    function reveal() {
        shown = true
        opened = true
    }

    function conceal() {
        opened = false
        shown = false
    }

    // Dismiss when clicking other monitors while unpinned.
    Variants {
        model: dock.otherScreens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: true
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            WlrLayershell.namespace: dock.layerNamespace + "-scrim"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            MouseArea {
                anchors.fill: parent
                onClicked: dock.closeRequested()
            }
        }
    }

    PanelWindow {
        visible: dock.shown
        screen: dock.screen
        // Unpinned: fullscreen so outside clicks hit the catcher below the panel.
        // Pinned: edge strip with exclusive zone.
        anchors.top: true
        anchors.bottom: true
        anchors.left: !dock.onRight || !dock.pinned
        anchors.right: dock.onRight || !dock.pinned
        implicitWidth: dock.pinned ? dock.panelWidth : 0
        color: "transparent"
        exclusiveZone: (dock.opened && dock.pinned) ? dock.panelWidth : 0
        exclusionMode: dock.pinned ? ExclusionMode.Normal : ExclusionMode.Ignore
        WlrLayershell.namespace: dock.layerNamespace
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: dock.opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            enabled: dock.scrimActive
            onClicked: dock.closeRequested()
        }

        Item {
            id: panelHost
            z: 1
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: dock.onRight ? undefined : parent.left
            anchors.right: dock.onRight ? parent.right : undefined
            width: dock.panelWidth

            Rectangle {
                anchors.fill: parent
                color: Theme.overlaySurface
            }

            // Absorb clicks on empty panel chrome so they don't reach the dismiss area.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }

            ColumnLayout {
                id: contentLayout
                anchors.fill: parent
                anchors.margins: dock.contentMargin
                spacing: dock.contentSpacing
                z: 1

                Text {
                    visible: dock.title !== ""
                    Layout.fillWidth: true
                    text: dock.title
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.bold: Theme.fontBold
                }
            }

            Row {
                id: chromeButtons
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: dock.contentMargin - 2
                anchors.rightMargin: dock.contentMargin - 4
                spacing: 2
                z: 2
                visible: dock.showCloseButton || dock.showPinButton || dock.showSideButton

                Item {
                    width: 28
                    height: 28
                    visible: dock.showSideButton

                    Text {
                        anchors.centerIn: parent
                        text: dock.onRight ? "󰁍" : "󰁔"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        font.bold: Theme.fontBold
                        opacity: sideMouse.containsMouse ? 1 : 0.65
                    }

                    MouseArea {
                        id: sideMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dock.sideRequested()
                    }
                }

                Item {
                    width: 28
                    height: 28
                    visible: dock.showPinButton

                    Text {
                        anchors.centerIn: parent
                        text: dock.pinned ? "󰐃" : "󰤱"
                        color: dock.pinned ? Theme.accent : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        font.bold: Theme.fontBold
                        opacity: pinMouse.containsMouse || dock.pinned ? 1 : 0.65
                    }

                    MouseArea {
                        id: pinMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dock.pinRequested()
                    }
                }

                Item {
                    width: 28
                    height: 28
                    visible: dock.showCloseButton

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        font.bold: Theme.fontBold
                        opacity: closeMouse.containsMouse ? 1 : 0.65
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dock.closeRequested()
                    }
                }
            }
        }
    }
}
