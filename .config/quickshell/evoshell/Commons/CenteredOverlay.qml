import Quickshell
import Quickshell.Wayland
import QtQuick

Item {
    id: root

    property bool opened: false
    property int contentWidth: 420
    property int contentHeight: 520
    property int contentMargin: 16
    property bool framed: true
    property int borderWidth: 1
    property bool fillScreen: false
    property color backgroundColor: "transparent"
    property string layerNamespace: "evo-overlay"
    property Item keysTarget: null
    signal dismissed()

    default property alias content: contentHost.data

    PanelWindow {
        visible: root.opened
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.namespace: root.layerNamespace
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore

        MouseArea {
            anchors.fill: parent
            onClicked: root.dismissed()
        }

        Item {
            id: contentFrame
            z: 1
            anchors.centerIn: root.fillScreen ? undefined : parent
            anchors.fill: root.fillScreen ? parent : undefined
            width: root.fillScreen ? undefined : root.contentWidth
            height: root.fillScreen ? undefined : root.contentHeight
            focus: root.opened

            Keys.forwardTo: root.keysTarget ? [root.keysTarget] : []
            Keys.onEscapePressed: root.dismissed()

            Rectangle {
                z: 0
                anchors.fill: parent
                visible: root.backgroundColor !== "transparent"
                color: root.backgroundColor
            }

            Rectangle {
                z: 0
                visible: root.framed
                anchors.fill: parent
                color: Theme.overlaySurface
                border.color: Theme.accent
                border.width: root.borderWidth
            }

            Item {
                id: contentHost
                z: 1
                anchors.fill: parent
                anchors.margins: root.contentMargin
            }
        }
    }
}
