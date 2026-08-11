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
    property string title: ""
    property bool showCloseButton: false
    property int contentSpacing: 10
    property int contentMargin: 12

    readonly property bool onRight: side === "right"

    signal closeRequested()

    default property alias content: contentLayout.children

    function reveal() {
        shown = true
        opened = true
    }

    function conceal() {
        opened = false
    }

    PanelWindow {
        visible: dock.shown
        anchors.top: true
        anchors.bottom: true
        anchors.left: !dock.onRight
        anchors.right: dock.onRight
        implicitWidth: dock.panelWidth
        color: Theme.panelBackground
        exclusiveZone: dock.opened ? dock.panelWidth : 0
        exclusionMode: ExclusionMode.Normal
        WlrLayershell.namespace: dock.layerNamespace
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: dock.opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        Behavior on exclusiveZone {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
                onRunningChanged: {
                    if (!running && !dock.opened) dock.shown = false
                }
            }
        }

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

        Item {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: dock.contentMargin - 2
            anchors.rightMargin: dock.contentMargin - 4
            width: 28
            height: 28
            visible: dock.showCloseButton
            z: 1

            Text {
                id: closeIcon
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
