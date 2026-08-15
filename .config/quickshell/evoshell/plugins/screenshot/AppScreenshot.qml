import Quickshell
import Quickshell.Io
import QtQuick
import "../../Commons"

Item {
    id: root

    property var host: null
    property string tool: "arrow"
    property color strokeColor: Theme.urgent
    property var shapes: []
    property var draft: null
    property bool editing: false
    property bool busy: false
    property string sourceUrl: ""
    property string pendingAction: ""
    property string pendingStamp: ""
    property string textDraft: ""
    property real textImageX: 0
    property real textImageY: 0
    property int imageNativeW: 0
    property int imageNativeH: 0
    property bool zoomActualSize: false

    readonly property var palette: [Theme.urgent, Theme.accent, Theme.foreground, "#ffffff", "#111111"]
    readonly property int toolbarHeight: 44
    readonly property int padding: 12
    readonly property int pixelW: imageNativeW
    readonly property int pixelH: imageNativeH
    readonly property var hostScreen: {
        var screens = Quickshell.screens
        if (!screens || screens.length === 0)
            return null
        for (var i = 0; i < screens.length; i++) {
            if (screens[i] && String(screens[i].name) === "DP-1")
                return screens[i]
        }
        return screens[0]
    }
    readonly property real dpr: {
        if (!hostScreen || !hostScreen.devicePixelRatio || hostScreen.devicePixelRatio <= 0)
            return 1
        return hostScreen.devicePixelRatio
    }
    readonly property real logicalW: pixelW > 0 ? pixelW / dpr : 0
    readonly property real logicalH: pixelH > 0 ? pixelH / dpr : 0
    readonly property real fitScale: {
        if (logicalW <= 0 || logicalH <= 0)
            return 1
        var screenW = hostScreen && hostScreen.width ? hostScreen.width : 1920
        var screenH = hostScreen && hostScreen.height ? hostScreen.height : 1080
        var maxW = screenW - padding * 2 - 24
        var maxH = screenH - padding * 2 - toolbarHeight - 24
        return Math.min(1, maxW / logicalW, maxH / logicalH)
    }
    readonly property real viewScale: root.zoomActualSize ? 1 : fitScale
    readonly property int displayW: logicalW > 0 ? Math.round(logicalW * viewScale) : 1
    readonly property int displayH: logicalH > 0 ? Math.round(logicalH * fitScale) : 1
    readonly property real imgScale: pixelW > 0 ? displayW / pixelW : 1
    readonly property real paintedW: displayW
    readonly property real paintedH: displayH
    readonly property int toolbarMinWidth: toolbarRow.implicitWidth
    readonly property int contentWidth: Math.max(displayW, toolbarMinWidth)
    readonly property real paintedX: (contentWidth - paintedW) / 2
    readonly property real paintedY: 0
    readonly property int windowWidth: contentWidth + padding * 2
    readonly property int windowHeight: displayH + toolbarHeight + padding * 2 + 8
    readonly property int windowX: {
        var screenW = hostScreen && hostScreen.width ? hostScreen.width : windowWidth
        return Math.max(8, Math.round((screenW - windowWidth) / 2))
    }
    readonly property int windowY: {
        var screenH = hostScreen && hostScreen.height ? hostScreen.height : windowHeight
        return Math.max(8, Math.round((screenH - windowHeight) / 2))
    }
    readonly property real strokeWidth: Math.max(3, Math.round(pixelW / 480))
    readonly property real fontSize: Math.max(18, Math.round(pixelH / 28))
    readonly property string tmpExport: "/tmp/evo-annotate.png"
    readonly property string saveDir: (Quickshell.env("HOME") || "") + "/onedrive/pictures/Screenshots"

    focus: true

    function reset() {
        shapes = []
        draft = null
        editing = false
        busy = false
        textDraft = ""
        sourceUrl = ""
        pendingAction = ""
        imageNativeW = 0
        imageNativeH = 0
        zoomActualSize = false
        tool = "arrow"
        strokeColor = Theme.urgent
        overlayCanvas.requestPaint()
        exportCanvas.requestPaint()
    }

    function loadImage(path) {
        reset()
        sourceUrl = Util.fileUrl(path) + "?" + Date.now()
        dimProbe.source = sourceUrl
    }

    function applyNativeSize(w, h) {
        if (w <= 0 || h <= 0)
            return
        if (imageNativeW === w && imageNativeH === h)
            return
        imageNativeW = w
        imageNativeH = h
        overlayCanvas.requestPaint()
    }

    function onActivated() {
        forceActiveFocus()
        overlayCanvas.requestPaint()
    }

    function notify(body) {
        if (host && typeof host.notify === "function")
            host.notify("screenshot", body)
    }

    function dismiss() {
        if (host && typeof host.dismiss === "function")
            host.dismiss()
    }

    function toImage(px, py) {
        var s = imgScale || 1
        return {
            x: (px - paintedX) / s,
            y: (py - paintedY) / s
        }
    }

    function inImage(px, py) {
        return px >= paintedX && py >= paintedY
            && px <= paintedX + paintedW && py <= paintedY + paintedH
    }

    function commitDraft() {
        if (!draft)
            return
        var dx = draft.x2 - draft.x1
        var dy = draft.y2 - draft.y1
        if (Math.hypot(dx, dy) < 4) {
            draft = null
            overlayCanvas.requestPaint()
            return
        }
        shapes = shapes.concat([draft])
        draft = null
        overlayCanvas.requestPaint()
        exportCanvas.requestPaint()
    }

    function undo() {
        if (editing) {
            cancelText()
            return
        }
        if (shapes.length === 0)
            return
        shapes = shapes.slice(0, shapes.length - 1)
        overlayCanvas.requestPaint()
        exportCanvas.requestPaint()
    }

    function beginText(px, py) {
        var pt = toImage(px, py)
        textImageX = pt.x
        textImageY = pt.y
        textDraft = ""
        editing = true
        textInput.forceActiveFocus()
    }

    function commitText() {
        var value = String(textDraft || "").trim()
        editing = false
        textInput.focus = false
        root.forceActiveFocus()
        if (value) {
            shapes = shapes.concat([{
                type: "text",
                x: textImageX,
                y: textImageY,
                text: value,
                color: String(strokeColor),
                size: fontSize
            }])
            overlayCanvas.requestPaint()
            exportCanvas.requestPaint()
        }
        textDraft = ""
    }

    function cancelText() {
        editing = false
        textDraft = ""
        textInput.focus = false
        root.forceActiveFocus()
    }

    function drawArrow(ctx, x1, y1, x2, y2, color, width) {
        var angle = Math.atan2(y2 - y1, x2 - x1)
        var head = Math.max(12, width * 4)
        ctx.strokeStyle = color
        ctx.fillStyle = color
        ctx.lineWidth = width
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        ctx.beginPath()
        ctx.moveTo(x1, y1)
        ctx.lineTo(x2, y2)
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(x2, y2)
        ctx.lineTo(x2 - head * Math.cos(angle - 0.45), y2 - head * Math.sin(angle - 0.45))
        ctx.lineTo(x2 - head * Math.cos(angle + 0.45), y2 - head * Math.sin(angle + 0.45))
        ctx.closePath()
        ctx.fill()
    }

    function drawShape(ctx, shape) {
        if (!shape)
            return
        var color = shape.color || strokeColor
        var width = strokeWidth
        if (shape.type === "arrow") {
            drawArrow(ctx, shape.x1, shape.y1, shape.x2, shape.y2, color, width)
        } else if (shape.type === "rect") {
            ctx.strokeStyle = color
            ctx.lineWidth = width
            ctx.strokeRect(
                Math.min(shape.x1, shape.x2),
                Math.min(shape.y1, shape.y2),
                Math.abs(shape.x2 - shape.x1),
                Math.abs(shape.y2 - shape.y1)
            )
        } else if (shape.type === "text") {
            var size = shape.size || fontSize
            ctx.fillStyle = color
            ctx.font = size + 'px "' + Theme.fontFamily + '"'
            ctx.textBaseline = "top"
            ctx.fillText(shape.text, shape.x, shape.y)
        }
    }

    function paintAll(ctx, scale, ox, oy) {
        ctx.reset()
        ctx.save()
        ctx.translate(ox, oy)
        ctx.scale(scale, scale)
        var list = shapes
        for (var i = 0; i < list.length; i++)
            drawShape(ctx, list[i])
        if (draft)
            drawShape(ctx, draft)
        ctx.restore()
    }

    function exportNow(action) {
        if (busy || pixelW <= 0 || shot.status !== Image.Ready)
            return
        if (editing)
            commitText()
        busy = true
        pendingAction = action
        pendingStamp = Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss")
        exportCanvas.requestPaint()
        Qt.callLater(function() {
            exportRoot.grabToImage(function(result) {
                if (!result || !result.saveToFile(root.tmpExport)) {
                    root.busy = false
                    root.notify("export failed")
                    return
                }
                if (root.pendingAction === "copy") {
                    if (copyProc.running)
                        copyProc.running = false
                    copyProc.running = true
                } else {
                    if (saveProc.running)
                        saveProc.running = false
                    saveProc.running = true
                }
            }, Qt.size(root.pixelW, root.pixelH))
        })
    }

    Keys.onPressed: function(event) {
        if (editing)
            return
        var ctrl = event.modifiers & Qt.ControlModifier
        if (ctrl && event.key === Qt.Key_Z) {
            undo()
            event.accepted = true
        } else if (ctrl && event.key === Qt.Key_C) {
            exportNow("copy")
            event.accepted = true
        } else if (ctrl && event.key === Qt.Key_S) {
            exportNow("save")
            event.accepted = true
        } else if (event.key === Qt.Key_A) {
            tool = "arrow"
            event.accepted = true
        } else if (event.key === Qt.Key_R) {
            tool = "rect"
            event.accepted = true
        } else if (event.key === Qt.Key_T) {
            tool = "text"
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            exportNow("copy")
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            dismiss()
            event.accepted = true
        }
    }

    Process {
        id: copyProc
        command: ["bash", "-c", "wl-copy -t image/png < " + Util.shellQuote(root.tmpExport)]
        onExited: function(exitCode) {
            root.busy = false
            if (exitCode === 0) {
                root.notify("copied")
                root.dismiss()
            } else {
                root.notify("copy failed")
            }
        }
    }

    Process {
        id: saveProc
        command: [
            "bash",
            "-c",
            "dir=" + Util.shellQuote(root.saveDir)
                + "; mkdir -p \"$dir\"; cp "
                + Util.shellQuote(root.tmpExport)
                + " \"$dir/evo-" + root.pendingStamp + ".png\""
        ]
        onExited: function(exitCode) {
            root.busy = false
            if (exitCode === 0) {
                root.notify("saved")
                root.dismiss()
            } else {
                root.notify("save failed")
            }
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: 8

        Item {
            id: view
            width: root.contentWidth
            height: root.displayH
            anchors.horizontalCenter: parent.horizontalCenter
            clip: false

            Item {
                id: imageFrame
                x: root.paintedX
                y: 0
                width: root.displayW
                height: root.displayH
                clip: true

                Image {
                    id: shot
                    width: root.pixelW
                    height: root.pixelH
                    source: root.sourceUrl
                    fillMode: Image.Pad
                    asynchronous: false
                    cache: false
                    smooth: root.viewScale < 1
                    mipmap: false
                    scale: root.imgScale
                    transformOrigin: Item.TopLeft
                    onStatusChanged: {
                        if (status === Image.Ready) {
                            var w = sourceSize.width > 0 ? sourceSize.width : implicitWidth
                            var h = sourceSize.height > 0 ? sourceSize.height : implicitHeight
                            root.applyNativeSize(w, h)
                        } else if (status === Image.Error) {
                            root.notify("could not load capture")
                            root.dismiss()
                        }
                    }
                }
            }

            Canvas {
                id: overlayCanvas
                x: root.paintedX
                y: 0
                width: root.paintedW
                height: root.paintedH
                onPaint: root.paintAll(getContext("2d"), root.imgScale || 1, 0, 0)
            }

            MouseArea {
                x: root.paintedX
                y: 0
                width: root.paintedW
                height: root.paintedH
                enabled: !root.busy && shot.status === Image.Ready
                hoverEnabled: true
                cursorShape: root.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor
                onPressed: function(mouse) {
                    if (mouse.x < 0 || mouse.y < 0 || mouse.x > root.paintedW || mouse.y > root.paintedH)
                        return
                    if (root.editing)
                        root.commitText()
                    if (root.tool === "text") {
                        root.beginText(root.paintedX + mouse.x, mouse.y)
                        return
                    }
                    var pt = {
                        x: mouse.x / root.imgScale,
                        y: mouse.y / root.imgScale
                    }
                    root.draft = {
                        type: root.tool,
                        x1: pt.x,
                        y1: pt.y,
                        x2: pt.x,
                        y2: pt.y,
                        color: String(root.strokeColor)
                    }
                    overlayCanvas.requestPaint()
                }
                onPositionChanged: function(mouse) {
                    if (!root.draft)
                        return
                    var pt = {
                        x: mouse.x / root.imgScale,
                        y: mouse.y / root.imgScale
                    }
                    root.draft = {
                        type: root.draft.type,
                        x1: root.draft.x1,
                        y1: root.draft.y1,
                        x2: pt.x,
                        y2: pt.y,
                        color: root.draft.color
                    }
                    overlayCanvas.requestPaint()
                }
                onReleased: root.commitDraft()
            }

            TextInput {
                id: textInput
                visible: root.editing
                x: root.paintedX + root.textImageX * root.imgScale
                y: root.textImageY * root.imgScale
                width: Math.max(80, view.width - x - 8)
                color: root.strokeColor
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(12, Math.round(root.fontSize * root.imgScale))
                font.bold: Theme.fontBold
                text: root.textDraft
                onTextEdited: root.textDraft = text
                onAccepted: root.commitText()
                Keys.onEscapePressed: function(event) {
                    root.cancelText()
                    event.accepted = true
                }
            }
        }

        Item {
            id: toolbar
            width: parent.width
            height: toolbarHeight

            Row {
                id: toolbarRow
                anchors.centerIn: parent
                spacing: 8
                height: 28

                Repeater {
                    model: [
                        { name: "arrow", icon: "󰁝" },
                        { name: "rect", icon: "󰹞" },
                        { name: "text", icon: "󰉼" }
                    ]

                    Rectangle {
                        required property var modelData
                        width: 28
                        height: 28
                        radius: 3
                        color: root.tool === modelData.name ? Theme.accent : Theme.panelMantle

                        Text {
                            id: toolLabel
                            anchors.centerIn: parent
                            text: modelData.icon
                            color: root.tool === modelData.name ? Theme.mantle : Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                            font.bold: Theme.fontBold
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.tool = modelData.name
                        }
                    }
                }

                Item { width: 8; height: 28 }

                Repeater {
                    model: root.palette

                    Item {
                        required property var modelData
                        width: 20
                        height: 28

                        Rectangle {
                            anchors.centerIn: parent
                            width: 20
                            height: 20
                            radius: 10
                            color: parent.modelData
                            border.color: Qt.colorEqual(root.strokeColor, parent.modelData) ? Theme.foreground : "transparent"
                            border.width: Qt.colorEqual(root.strokeColor, parent.modelData) ? 2 : 0

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.strokeColor = parent.parent.modelData
                            }
                        }
                    }
                }

                Item { width: 8; height: 28 }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 3
                    color: root.zoomActualSize ? Theme.accent : Theme.panelMantle
                    opacity: root.busy ? 0.5 : 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰋩"
                        color: root.zoomActualSize ? Theme.mantle : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        font.bold: Theme.fontBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.busy
                        onClicked: root.zoomActualSize = !root.zoomActualSize
                    }
                }

                Item { width: 8; height: 28 }

                Repeater {
                    model: [
                        { name: "undo", label: "Undo" },
                        { name: "copy", label: "Copy" },
                        { name: "save", label: "Save" },
                        { name: "close", label: "Close" }
                    ]

                    Rectangle {
                        required property var modelData
                        width: actionLabel.implicitWidth + 16
                        height: 28
                        radius: 3
                        color: Theme.panelMantle
                        opacity: root.busy ? 0.5 : 1

                        Text {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: modelData.label
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPixelSize
                            font.bold: Theme.fontBold
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !root.busy
                            onClicked: {
                                if (modelData.name === "undo")
                                    root.undo()
                                else if (modelData.name === "copy")
                                    root.exportNow("copy")
                                else if (modelData.name === "save")
                                    root.exportNow("save")
                                else
                                    root.dismiss()
                            }
                        }
                    }
                }
            }
        }
    }

    Image {
        id: dimProbe
        visible: false
        x: -200000
        y: 0
        source: root.sourceUrl
        asynchronous: false
        cache: false
        onStatusChanged: {
            if (status === Image.Ready) {
                var w = sourceSize.width > 0 ? sourceSize.width : implicitWidth
                var h = sourceSize.height > 0 ? sourceSize.height : implicitHeight
                root.applyNativeSize(w, h)
            }
        }
    }

    Item {
        id: exportRoot
        width: Math.max(1, root.pixelW)
        height: Math.max(1, root.pixelH)
        x: -100000
        y: 0
        visible: true
        layer.enabled: true

        Image {
            width: root.pixelW
            height: root.pixelH
            source: root.sourceUrl
            fillMode: Image.Pad
            asynchronous: false
            cache: false
            smooth: false
        }

        Canvas {
            id: exportCanvas
            anchors.fill: parent
            onPaint: root.paintAll(getContext("2d"), 1, 0, 0)
        }
    }

    onPaintedWChanged: overlayCanvas.requestPaint()
    onDisplayWChanged: overlayCanvas.requestPaint()
    onDisplayHChanged: overlayCanvas.requestPaint()
    onImageNativeWChanged: overlayCanvas.requestPaint()
    onImageNativeHChanged: overlayCanvas.requestPaint()
    onStrokeColorChanged: overlayCanvas.requestPaint()
}
