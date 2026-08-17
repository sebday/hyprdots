import QtQuick
import "../../../Commons"

Item {
    id: root

    property int size: 18
    property real percent: 0
    property color color: Theme.accent
    property color trackColor: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.16)
    property real lineWidth: 1.75
    property bool loading: false
    property bool showDot: false
    property real dotRadius: 2.1
    property string centerIcon: ""
    property real centerIconSize: Theme.fontSizeS
    property real centerIconOpacity: 0.92

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    readonly property real progress: Math.max(0, Math.min(1, Number(percent) / 100))

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()

            var cx = width / 2
            var cy = height / 2
            var lw = root.lineWidth
            var r = Math.min(width, height) / 2 - lw - 0.5
            var start = -Math.PI / 2
            var sweep = root.loading
                ? Math.PI * 0.55
                : (root.progress * Math.PI * 2)

            ctx.lineWidth = lw
            ctx.lineCap = "round"

            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
            ctx.strokeStyle = root.trackColor
            ctx.stroke()

            if (root.loading || root.progress > 0.001) {
                ctx.beginPath()
                ctx.arc(cx, cy, r, start, start + sweep)
                ctx.strokeStyle = root.color
                ctx.stroke()

                if (root.showDot && !root.loading && root.progress > 0.001) {
                    var angle = start + sweep
                    var dotX = cx + r * Math.cos(angle)
                    var dotY = cy + r * Math.sin(angle)
                    ctx.beginPath()
                    ctx.arc(dotX, dotY, root.dotRadius, 0, Math.PI * 2)
                    ctx.fillStyle = root.color
                    ctx.fill()
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.centerIcon !== ""
        text: root.centerIcon
        color: root.color
        font.family: Theme.fontFamily
        font.pixelSize: root.centerIconSize
        font.bold: Theme.fontBold
        opacity: root.centerIconOpacity
    }

    onPercentChanged: canvas.requestPaint()
    onProgressChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onTrackColorChanged: canvas.requestPaint()
    onLoadingChanged: canvas.requestPaint()
    onSizeChanged: canvas.requestPaint()
    onLineWidthChanged: canvas.requestPaint()
    onShowDotChanged: canvas.requestPaint()
    Component.onCompleted: canvas.requestPaint()
}
