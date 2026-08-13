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
    property bool hovered: false

    readonly property bool onRight: side === "right"
    readonly property bool surfaceActive: dock.hovered
    readonly property bool scrimActive: shown && opened && !pinned
    readonly property string screenName: screen ? String(screen.name) : ""

    readonly property var otherScreens: {
        if (!dock.scrimActive)
            return []
        var screens = Quickshell.screens
        if (!screens || screens.length === 0)
            return []
        var panelName = dock.screenName
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

    default property alias content: contentStash.data

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
        rebuildWindow()
        Qt.callLater(function() {
            if (wasShown)
                reveal()
        })
    }

    function moveChildren(fromItem, toItem) {
        if (!fromItem || !toItem) return
        var kids = fromItem.children
        while (kids.length > 0)
            kids[0].parent = toItem
    }

    function parkContent() {
        var win = winLoader.item
        if (win && win.contentLayout)
            moveChildren(win.contentLayout, contentStash)
    }

    function adoptContent() {
        var win = winLoader.item
        if (win && win.contentLayout)
            moveChildren(contentStash, win.contentLayout)
    }

    function rebuildWindow() {
        parkContent()
        winLoader.active = false
        winLoader.active = dock.screen !== null
    }

    function syncHover(containsMouse) {
        hovered = containsMouse === true
        Theme.panelSurfaceActive = surfaceActive
    }

    onSurfaceActiveChanged: Theme.panelSurfaceActive = surfaceActive
    onScreenNameChanged: rebuildWindow()
    onSideChanged: if (shown) resetDockWindow()
    onShownChanged: {
        if (!shown) {
            hovered = false
            Theme.panelSurfaceActive = false
        }
    }

    Item {
        id: contentStash
        visible: false
        width: 0
        height: 0
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
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            MouseArea {
                anchors.fill: parent
                onClicked: dock.closeRequested()
            }
        }
    }

    Loader {
        id: winLoader
        active: false
        sourceComponent: windowComp
        onLoaded: dock.adoptContent()
    }

    Component {
        id: windowComp

        Item {
            property alias contentLayout: contentLayout

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
                visible: dock.shown
                screen: dock.screen
                anchors.top: true
                anchors.bottom: true
                anchors.left: !dock.onRight
                anchors.right: dock.onRight
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
                        onContainsMouseChanged: dock.syncHover(containsMouse)
                        onWheel: function(wheel) { wheel.accepted = false }
                    }

                    Rectangle {
                        id: panelBg
                        anchors.fill: parent
                        z: -1
                        color: dock.surfaceActive ? Theme.overlaySurface : Theme.overlaySurfaceInactive

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Row {
                        id: chromeButtons
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: dock.contentMargin - 2
                        anchors.rightMargin: dock.contentMargin - 4
                        spacing: 2
                        z: 10
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
                                font.pixelSize: Theme.panelIconFontPixelSize
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
                                font.pixelSize: Theme.panelIconFontPixelSize
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
                                font.pixelSize: Theme.panelIconFontPixelSize
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

                    MouseArea {
                        id: blockMouse
                        anchors.fill: parent
                        anchors.topMargin: chromeButtons.height + dock.contentMargin
                        z: 0
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
                            font.pixelSize: Theme.panelTitleFontPixelSize
                            font.bold: Theme.fontBold
                        }
                    }
                }
            }
        }
    }
}
