import QtQuick
import "../../../Commons"

Item {
    id: root

    property int size: 18
    property real percent: 0
    property color color: Theme.accent
    property color trackColor: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.18)
    property real lineWidth: 2
    property bool loading: false

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()

            var cx = width / 2
            var cy = height / 2
            var r = Math.min(width, height) / 2 - root.lineWidth / 2 - 0.5
            var start = -Math.PI / 2
            var clamped = Math.max(0, Math.min(100, root.percent))
            var sweep = root.loading
                ? Math.PI * 0.55
                : (Math.PI * 2 * clamped / 100)

            ctx.lineWidth = root.lineWidth
            ctx.lineCap = "round"

            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
            ctx.strokeStyle = root.trackColor
            ctx.stroke()

            if (root.loading || clamped > 0) {
                ctx.beginPath()
                ctx.arc(cx, cy, r, start, start + sweep)
                ctx.strokeStyle = root.color
                ctx.stroke()
            }
        }
    }

    onPercentChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onTrackColorChanged: canvas.requestPaint()
    onLoadingChanged: canvas.requestPaint()
    onSizeChanged: canvas.requestPaint()
    onLineWidthChanged: canvas.requestPaint()
    Component.onCompleted: canvas.requestPaint()
}
