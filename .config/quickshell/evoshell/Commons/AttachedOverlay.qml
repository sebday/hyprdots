import Quickshell
import Quickshell.Wayland
import QtQuick

Item {
    id: root

    property bool opened: false
    property int contentWidth: 420
    property int contentHeight: 320
    property int contentMargin: 12
    property int contentTopMargin: contentMargin
    readonly property int screenEdgeOffset: 20
    readonly property int borderWidth: Theme.hoverPopupBorderWidth
    property var anchorItem: null
    property var anchorWindow: null
    property var shell: null
    property string barPosition: "bottom"
    property string layerNamespace: "evo-overlay"
    signal hoverEntered()
    signal hoverLeft()

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
        if (x < 8)
            x = 8
        if (x + width > screenW - 8)
            x = Math.max(8, screenW - width - 8)
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
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        Rectangle {
            id: box
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: root.barOnBottom ? parent.top : undefined
            anchors.bottom: root.barOnBottom ? undefined : parent.bottom
            height: root.contentHeight
            color: Theme.mantle
            border.color: Theme.accent
            border.width: root.opened ? root.borderWidth : 0
            radius: Theme.panelCornerRadius
        }

        HoverHandler {
            onHoveredChanged: {
                if (hovered)
                    root.hoverEntered()
                else
                    root.hoverLeft()
            }
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
}
