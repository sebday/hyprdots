import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

Item {
    id: dock

    property string layerNamespace: "evo-dock"
    property int panelWidth: 350
    property string side: "left"
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

    PanelWindow {
        visible: dock.shown
        anchors.top: true
        anchors.bottom: true
        anchors.left: !dock.onRight
        anchors.right: dock.onRight
        implicitWidth: dock.panelWidth
        color: Theme.panelBackground
        exclusiveZone: (dock.opened && dock.pinned) ? dock.panelWidth : 0
        exclusionMode: dock.pinned ? ExclusionMode.Normal : ExclusionMode.Ignore
        WlrLayershell.namespace: dock.layerNamespace
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: dock.opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        ColumnLayout {
            id: contentLayout
            anchors.fill: parent
            anchors.margins: dock.contentMargin
            spacing: dock.contentSpacing

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
            z: 1
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
