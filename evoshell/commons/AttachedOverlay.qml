import Quickshell
import Quickshell.Wayland
import QtQuick

Item {
    id: root

    property bool opened: false
    property bool revealed: true
    property bool pointerInside: false
    property bool keyboardFocusEnabled: false
    property int contentWidth: Theme.overlayWidthDefault
    property int contentHeight: 320
    property int contentMargin: Theme.overlayMargin
    property int contentTopMargin: contentMargin
    readonly property int screenEdgeOffset: Theme.screenEdgeInset
    readonly property int borderWidth: Theme.hoverPanelBorderWidth
    property var anchorItem: null
    property var anchorWindow: null
    property var shell: null
    property string barPosition: "bottom"
    property string layerNamespace: "evo-overlay"
    signal hoverEntered()
    signal hoverLeft()
    signal revealedHoverEntered()
    signal escapePressed()
    signal pinPressed()
    signal outsidePressed()

    default property alias content: contentHost.data

    readonly property bool barOnBottom: String(barPosition || "bottom") !== "top"
    readonly property var barOutputScreen: {
        if (!shell || !shell.barConfig)
            return null
        var screen = Util.screenForOutput(shell.barConfig.output, "")
        if (screen)
            return screen
        var screens = Quickshell.screens
        return screens && screens.length > 0 ? screens[0] : null
    }
    readonly property var hostScreen: {
        if (barOutputScreen)
            return barOutputScreen
        if (anchorWindow && anchorWindow.screen)
            return anchorWindow.screen
        if (anchorItem && anchorItem.QsWindow && anchorItem.QsWindow.window && anchorItem.QsWindow.window.screen)
            return anchorItem.QsWindow.window.screen
        return null
    }

    property int boxX: 0

    function resolveAnchorWindow() {
        if (anchorWindow)
            return anchorWindow
        if (anchorItem && anchorItem.QsWindow)
            return anchorItem.QsWindow.window
        return null
    }

    function applyHostScreen() {
        if (!overlayPanel || !hostScreen)
            return
        overlayPanel.screen = hostScreen
        reposition()
    }

    function reposition() {
        var screen = hostScreen
        var screenW = screen && screen.width ? screen.width : 1920
        var width = contentWidth
        var x = Math.round((screenW - width) / 2)
        var win = resolveAnchorWindow()
        if (anchorItem && win && win.contentItem) {
            var point = anchorItem.mapToItem(win.contentItem, 0, 0)
            x = Math.round(point.x + (anchorItem.width - width) / 2)
        }
        if (x < Theme.spacingM)
            x = Theme.spacingM
        if (x + width > screenW - Theme.spacingM)
            x = Math.max(Theme.spacingM, screenW - width - Theme.spacingM)
        boxX = x
    }

    onOpenedChanged: if (opened) Qt.callLater(applyHostScreen)
    onAnchorItemChanged: if (opened) Qt.callLater(applyHostScreen)
    onAnchorWindowChanged: if (opened) Qt.callLater(applyHostScreen)
    onContentWidthChanged: if (opened) Qt.callLater(reposition)
    onContentHeightChanged: {
        if (!opened)
            return
        // Clearing or hiding a row shrinks the panel under the cursor.
        // That hover-leave would dismiss it before the click is useful.
        resizeHoldTimer.restart()
        Qt.callLater(reposition)
    }

    Timer {
        id: resizeHoldTimer
        interval: 350
        repeat: false
    }
    onHostScreenChanged: if (opened) Qt.callLater(applyHostScreen)

    PanelWindow {
        id: dismissWindow
        visible: root.opened && root.revealed && root.hostScreen
        screen: root.hostScreen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: root.layerNamespace + "-dismiss"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Leave the bar strip to the bar, so an icon click still toggles.
        // Leave the panel rectangle too: this surface is mapped above the
        // panel, and a click on Clear or a row button would otherwise land
        // here and dismiss the panel.
        mask: Region {
            x: 0
            y: 0
            width: dismissWindow.width
            height: dismissWindow.height

            Region {
                intersection: Intersection.Subtract
                x: 0
                y: root.barOnBottom ? Math.max(0, dismissWindow.height - Theme.barHeight) : 0
                width: dismissWindow.width
                height: Theme.barHeight
            }

            Region {
                intersection: Intersection.Subtract
                x: root.boxX
                y: root.barOnBottom
                    ? Math.max(0, dismissWindow.height - root.contentHeight - (Theme.barHeight + root.screenEdgeOffset))
                    : (Theme.barHeight + root.screenEdgeOffset)
                width: root.contentWidth
                height: root.contentHeight
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: root.outsidePressed()
        }
    }

    Variants {
        model: root.opened && root.revealed ? Quickshell.screens : []

        delegate: PanelWindow {
            required property var modelData

            visible: root.hostScreen && modelData.name !== root.hostScreen.name
            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: root.layerNamespace + "-dismiss"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: root.outsidePressed()
            }
        }
    }

    PanelWindow {
        id: overlayPanel
        screen: root.hostScreen
        visible: root.opened
        color: "transparent"
        implicitWidth: root.contentWidth
        implicitHeight: root.contentHeight
        anchors.bottom: root.barOnBottom
        anchors.top: !root.barOnBottom
        anchors.left: true
        margins.bottom: root.barOnBottom ? Theme.barHeight + root.screenEdgeOffset : 0
        margins.top: root.barOnBottom ? 0 : Theme.barHeight + root.screenEdgeOffset
        margins.left: root.boxX
        WlrLayershell.namespace: root.layerNamespace
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.keyboardFocusEnabled
            ? WlrKeyboardFocus.OnDemand
            : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        Item {
            id: revealHost
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: root.barOnBottom ? parent.top : undefined
            anchors.bottom: root.barOnBottom ? undefined : parent.bottom
            height: root.contentHeight
            opacity: root.revealed ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.hoverPanelRevealDuration
                    easing.type: Easing.OutCubic
                }
            }

            transform: Translate {
                y: root.revealed ? 0 : (root.barOnBottom ? Theme.hoverPanelRevealOffset : -Theme.hoverPanelRevealOffset)
            }

            Rectangle {
                id: box
                anchors.fill: parent
                color: Theme.background
                border.color: Theme.accent
                border.width: root.opened ? root.borderWidth : 0
                radius: Theme.panelCornerRadius
            }

            Item {
                id: contentHost
                anchors.left: box.left
                anchors.right: box.right
                anchors.top: box.top
                anchors.bottom: box.bottom
                anchors.leftMargin: root.contentMargin + (root.opened ? root.borderWidth : 0)
                anchors.rightMargin: root.contentMargin + (root.opened ? root.borderWidth : 0)
                anchors.topMargin: root.contentTopMargin + (root.opened ? root.borderWidth : 0)
                anchors.bottomMargin: root.contentMargin + (root.opened ? root.borderWidth : 0)
            }
        }

        HoverHandler {
            enabled: root.opened
            onHoveredChanged: {
                root.pointerInside = hovered
                if (!root.revealed)
                    return
                if (hovered) {
                    root.hoverEntered()
                    root.revealedHoverEntered()
                } else if (!resizeHoldTimer.running) {
                    root.hoverLeft()
                }
            }
        }

        // Behind the panel content. Left clicks on Clear, hide, and remove
        // belong to those controls. This only sees presses that miss them,
        // and it must not dismiss the panel.
        MouseArea {
            anchors.fill: revealHost
            z: -1
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            enabled: root.opened && root.revealed
            onPressed: function(mouse) {
                if (root.shell && typeof root.shell.popupHoverEnter === "function")
                    root.shell.popupHoverEnter()
                mouse.accepted = true
            }
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton)
                    root.pinPressed()
            }
        }

        Shortcut {
            sequence: "Meta+D"
            enabled: root.opened && root.revealed && root.keyboardFocusEnabled
            context: Qt.WindowShortcut
            onActivated: {
                if (root.shell && typeof root.shell.toggleSystemMenu === "function")
                    root.shell.toggleSystemMenu()
            }
        }

        Shortcut {
            sequence: "Escape"
            enabled: root.opened && root.revealed
            context: Qt.WindowShortcut
            onActivated: root.escapePressed()
        }
    }
}
