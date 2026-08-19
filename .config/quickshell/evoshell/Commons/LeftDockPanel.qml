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
    property bool showSideButton: false
    property int contentSpacing: Theme.spacingL
    property int contentMargin: Theme.panelDockPad
    property bool hovered: false
    property color surfaceColor: ""

    readonly property bool onRight: side === "right"
    readonly property int edgeGap: Theme.gapsOut
    readonly property bool surfaceActive: dock.hovered
    readonly property color surfaceFill: surfaceColor !== ""
        ? surfaceColor
        : Theme.background
    readonly property bool scrimActive: shown && opened && !pinned
    readonly property color panelBorderIdle: Theme.inactiveBorder
    readonly property color panelBorderActive: Theme.accent

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

    function resetDockWindow() {
        var wasShown = shown
        conceal()
        Qt.callLater(function() {
            if (wasShown)
                reveal()
        })
    }

    function syncHover() {
        hovered = hoverCatcher.containsMouse
    }

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
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            MouseArea {
                anchors.fill: parent
                onPressed: dock.closeRequested()
            }
        }
    }

    PanelWindow {
        visible: dock.shown && !dock.pinned
        screen: dock.screen
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        color: "transparent"
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: dock.layerNamespace + "-scrim-local"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: dock.closeRequested()
        }
    }

    PanelWindow {
        id: dockWindow
        visible: dock.shown
        screen: dock.screen
        anchors.top: true
        anchors.bottom: true
        anchors.left: !dock.onRight
        anchors.right: dock.onRight
        margins.top: dock.edgeGap
        margins.bottom: dock.edgeGap
        margins.left: dock.onRight ? 0 : dock.edgeGap
        margins.right: dock.onRight ? dock.edgeGap : 0
        implicitWidth: dock.panelWidth
        color: "transparent"
        exclusiveZone: (dock.opened && dock.pinned) ? dock.panelWidth : 0
        exclusionMode: dock.pinned ? ExclusionMode.Normal : ExclusionMode.Ignore
        WlrLayershell.namespace: dock.layerNamespace
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: dock.opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        Item {
            id: panelHost
            anchors.fill: parent

            MouseArea {
                id: hoverCatcher
                anchors.fill: parent
                z: 100
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onContainsMouseChanged: dock.syncHover()
                onWheel: function(wheel) { wheel.accepted = false }
            }

            Rectangle {
                id: panelBg
                anchors.fill: parent
                z: -1
                color: dock.surfaceFill
                border.width: 2
                border.color: dock.surfaceActive ? dock.panelBorderActive : dock.panelBorderIdle
                radius: Theme.panelCornerRadius

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Row {
                id: chromeButtons
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: dock.contentMargin - 2
                spacing: Theme.spacing2
                z: 10
                visible: dock.showSideButton

                Item {
                    width: 28
                    height: 28
                    visible: dock.showSideButton

                    Text {
                        anchors.centerIn: parent
                        text: dock.onRight ? "󰁍" : "󰁔"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize2xl
                        font.bold: Theme.fontBold
                        opacity: sideMouse.containsMouse ? 1 : Theme.opacityHover
                    }

                    MouseArea {
                        id: sideMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dock.sideRequested()
                    }
                }
            }

            MouseArea {
                id: blockMouse
                anchors.fill: parent
                anchors.bottomMargin: chromeButtons.visible ? chromeButtons.height + dock.contentMargin : 0
                z: 0
                acceptedButtons: Qt.AllButtons
            }

            ColumnLayout {
                id: contentLayout
                anchors.fill: parent
                anchors.margins: dock.contentMargin
                anchors.bottomMargin: dock.contentMargin + (chromeButtons.visible ? chromeButtons.height : 0)
                spacing: dock.contentSpacing
                z: 1

                Text {
                    visible: dock.title !== ""
                    Layout.fillWidth: true
                    text: dock.title
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeL
                    font.bold: Theme.fontBold
                }
            }
        }
    }

    onSideChanged: if (shown) resetDockWindow()
    onShownChanged: {
        if (!shown)
            hovered = false
    }
}
