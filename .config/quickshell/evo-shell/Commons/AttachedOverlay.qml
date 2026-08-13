import Quickshell
import Quickshell.Wayland
import QtQuick

Item {
    id: root

    property bool opened: false
    property int contentWidth: 420
    property int contentHeight: 320
    property int contentMargin: 12
    property int caretWidth: 28
    property int caretHeight: 20
    property var anchorItem: null
    property var anchorWindow: null
    property string barPosition: "bottom"
    property string layerNamespace: "evo-overlay"
    signal hoverEntered()
    signal hoverLeft()

    default property alias content: contentHost.data

    readonly property bool barOnBottom: String(barPosition || "bottom") !== "top"
    readonly property var hostScreen: {
        if (anchorWindow && anchorWindow.screen)
            return anchorWindow.screen
        if (anchorItem && anchorItem.QsWindow && anchorItem.QsWindow.window)
            return anchorItem.QsWindow.window.screen
        return null
    }

    property int boxX: 0
    property int caretX: 0

    function resolveAnchorWindow() {
        if (anchorWindow)
            return anchorWindow
        if (anchorItem && anchorItem.QsWindow)
            return anchorItem.QsWindow.window
        return null
    }

    function reposition() {
        var screen = hostScreen
        var screenW = screen && screen.width ? screen.width : 1920
        var width = contentWidth
        var x = Math.round((screenW - width) / 2)
        var win = resolveAnchorWindow()
        var anchorCenter = x + width / 2
        if (anchorItem && win && win.contentItem) {
            var point = anchorItem.mapToItem(win.contentItem, 0, 0)
            x = Math.round(point.x + (anchorItem.width - width) / 2)
            anchorCenter = point.x + anchorItem.width / 2
        }
        if (x < 8)
            x = 8
        if (x + width > screenW - 8)
            x = Math.max(8, screenW - width - 8)
        boxX = x
        var pad = Math.ceil(caretWidth / 2) + 8
        caretX = Math.round(Math.max(pad, Math.min(width - pad, anchorCenter - x)))
    }

    onOpenedChanged: if (opened) Qt.callLater(reposition)
    onAnchorItemChanged: if (opened) Qt.callLater(reposition)
    onAnchorWindowChanged: if (opened) Qt.callLater(reposition)
    onContentWidthChanged: if (opened) Qt.callLater(reposition)
    onContentHeightChanged: if (opened) Qt.callLater(reposition)
    onHostScreenChanged: if (opened) Qt.callLater(reposition)

    PanelWindow {
        screen: root.hostScreen
        visible: root.opened
        color: "transparent"
        implicitWidth: root.contentWidth
        implicitHeight: root.contentHeight + root.caretHeight
        anchors.bottom: root.barOnBottom
        anchors.top: !root.barOnBottom
        anchors.left: true
        margins.bottom: root.barOnBottom ? Theme.barHeight : 0
        margins.top: root.barOnBottom ? 0 : Theme.barHeight
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
            border.width: 1
            radius: Theme.panelCornerRadius
        }

        Canvas {
            id: caret
            width: root.caretWidth
            height: root.caretHeight + 1
            x: root.caretX - width / 2
            y: root.barOnBottom ? box.height - 1 : 0
            z: 1

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var w = width
                var h = height
                var mid = w / 2
                var tipY = root.barOnBottom ? h - 0.5 : 0.5
                var baseY = root.barOnBottom ? 0 : h

                ctx.beginPath()
                ctx.moveTo(0, baseY)
                ctx.lineTo(w, baseY)
                ctx.lineTo(mid, tipY)
                ctx.closePath()
                ctx.fillStyle = Theme.mantle
                ctx.fill()

                ctx.beginPath()
                ctx.moveTo(0.5, baseY)
                ctx.lineTo(mid, tipY)
                ctx.lineTo(w - 0.5, baseY)
                ctx.strokeStyle = Theme.accent
                ctx.lineWidth = 1
                ctx.stroke()
            }

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onXChanged: requestPaint()
            Component.onCompleted: requestPaint()
        }

        Connections {
            target: Theme
            function onMantleChanged() { caret.requestPaint() }
            function onAccentChanged() { caret.requestPaint() }
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
            anchors.margins: root.contentMargin
        }
    }
}
