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
    readonly property int borderWidth: Theme.hoverPopupBorderWidth
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

    default property alias content: contentHost.data

    readonly property bool barOnBottom: String(barPosition || "bottom") !== "top"
    readonly property var barOutputScreen: {
        if (!shell || !shell.barConfig)
            return null
        return Util.screenForOutput(shell.barConfig.output, "HDMI-A-1")
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
    onContentHeightChanged: if (opened) Qt.callLater(reposition)
    onHostScreenChanged: if (opened) Qt.callLater(applyHostScreen)

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
                    duration: Theme.hoverPopupRevealDuration
                    easing.type: Easing.OutCubic
                }
            }

            transform: Translate {
                y: root.revealed ? 0 : (root.barOnBottom ? Theme.hoverPopupRevealOffset : -Theme.hoverPopupRevealOffset)
            }

            Rectangle {
                id: box
                anchors.fill: parent
                color: Theme.mantle
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
                } else
                    root.hoverLeft()
            }
        }

        Shortcut {
            sequence: "Meta+Space"
            enabled: root.opened && root.revealed && root.keyboardFocusEnabled
            context: Qt.WindowShortcut
            onActivated: {
                if (root.shell && typeof root.shell.toggleSystemMenu === "function")
                    root.shell.toggleSystemMenu()
            }
        }

        Shortcut {
            sequence: "Escape"
            enabled: root.opened && root.revealed && root.keyboardFocusEnabled
            context: Qt.WindowShortcut
            onActivated: root.escapePressed()
        }

        Shortcut {
            sequence: "P"
            enabled: root.opened && root.revealed && root.keyboardFocusEnabled
            context: Qt.WindowShortcut
            onActivated: root.pinPressed()
        }
    }
}
