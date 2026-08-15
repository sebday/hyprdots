import QtQuick
import "."

Item {
    id: root

    property var bars: []
    property var secondaryBars: []
    property string style: "bars" // "bars" | "line"
    property int chartHeight: Theme.sparklineExpandedHeight
    property int barWidth: Theme.sparklineExpandedBarWidth
    property int barSpacing: Theme.sparklineExpandedBarSpacing
    property bool fillWidth: true
    property color lineColor: Theme.accent
    property color secondaryLineColor: "#a6e3a1"
    property int lineWidth: 2

    readonly property bool isLine: style === "line"
    readonly property bool hasSecondary: secondaryBars.length > 0

    implicitHeight: chartHeight
    implicitWidth: fillWidth ? 200 : (bars.length * (barWidth + barSpacing) + 4)

    function repaintLine() {
        if (isLine)
            lineCanvas.requestPaint()
    }

    onBarsChanged: repaintLine()
    onSecondaryBarsChanged: repaintLine()
    onWidthChanged: repaintLine()
    onHeightChanged: repaintLine()
    onChartHeightChanged: repaintLine()
    onLineColorChanged: repaintLine()
    onSecondaryLineColorChanged: repaintLine()
    onStyleChanged: repaintLine()

    readonly property int scaledBarWidth: barWidth
    readonly property int scaledBarSpacing: barSpacing

    readonly property real effectiveBarWidth: {
        if (!fillWidth || bars.length === 0) return scaledBarWidth
        var gaps = Math.max(0, bars.length - 1) * scaledBarSpacing
        return Math.max(4, (width - gaps) / bars.length)
    }

    function valueRangeFor(series) {
        var pts = series || []
        var minV = Number.POSITIVE_INFINITY
        var maxV = Number.NEGATIVE_INFINITY
        for (var i = 0; i < pts.length; i++) {
            var v = parseFloat(pts[i] && pts[i].value)
            if (isNaN(v)) continue
            if (v < minV) minV = v
            if (v > maxV) maxV = v
        }
        if (!isFinite(minV) || !isFinite(maxV))
            return { min: 0, max: 1 }
        if (minV >= 0 && maxV >= 0) {
            if (maxV === 0)
                return { min: 0, max: 1 }
            var topPad = (maxV - minV) * 0.08
            if (topPad === 0)
                topPad = maxV * 0.08 || 1
            return { min: 0, max: maxV + topPad }
        }
        if (minV === maxV) {
            var pad = Math.abs(minV) * 0.02 || 1
            return { min: minV - pad, max: maxV + pad }
        }
        var span = maxV - minV
        return { min: minV - span * 0.08, max: maxV + span * 0.08 }
    }

    function valueRange() {
        return valueRangeFor(bars)
    }

    Row {
        id: chartRow
        visible: !root.isLine
        anchors.fill: parent
        spacing: root.scaledBarSpacing

        Repeater {
            model: root.bars

            Item {
                required property int index
                required property var modelData
                width: root.effectiveBarWidth
                height: chartRow.height

                Rectangle {
                    width: parent.width
                    height: modelData.level > 0
                        ? Math.max(2, chartRow.height * modelData.level / 7)
                        : 0
                    anchors.bottom: parent.bottom
                    radius: 2
                    color: modelData.color || Theme.accent
                    opacity: 0.85
                }
            }
        }
    }

    Canvas {
        id: lineCanvas
        visible: root.isLine
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var pts = root.bars || []
            if (pts.length === 0) return

            var w = width
            var h = height
            var padX = 2
            var padY = 3
            var usableW = Math.max(1, w - padX * 2)
            var usableH = Math.max(1, h - padY * 2)
            var step = pts.length > 1 ? usableW / (pts.length - 1) : 0

            function drawSeries(series, color, fill) {
                if (!series || series.length === 0)
                    return
                var range = root.valueRangeFor(series)
                var minV = range.min
                var maxV = range.max
                var span = maxV - minV || 1

                function yAt(v) {
                    var n = parseFloat(v)
                    if (isNaN(n)) n = minV
                    return padY + usableH - ((n - minV) / span) * usableH
                }

                if (fill) {
                    ctx.beginPath()
                    for (var i = 0; i < series.length; i++) {
                        var x = padX + i * step
                        var y = yAt(series[i].value)
                        if (i === 0) ctx.moveTo(x, y)
                        else ctx.lineTo(x, y)
                    }
                    ctx.lineTo(padX + (series.length - 1) * step, h)
                    ctx.lineTo(padX, h)
                    ctx.closePath()
                    ctx.globalAlpha = 0.14
                    ctx.fillStyle = color
                    ctx.fill()
                    ctx.globalAlpha = 1
                }

                ctx.beginPath()
                for (var j = 0; j < series.length; j++) {
                    var x2 = padX + j * step
                    var y2 = yAt(series[j].value)
                    if (j === 0) ctx.moveTo(x2, y2)
                    else ctx.lineTo(x2, y2)
                }
                ctx.strokeStyle = color
                ctx.lineWidth = root.lineWidth
                ctx.lineJoin = "round"
                ctx.lineCap = "round"
                ctx.stroke()

                var lastX = padX + (series.length - 1) * step
                var lastY = yAt(series[series.length - 1].value)
                ctx.beginPath()
                ctx.arc(lastX, lastY, 3, 0, Math.PI * 2)
                ctx.fillStyle = color
                ctx.fill()
            }

            if (root.hasSecondary)
                drawSeries(root.secondaryBars, root.secondaryLineColor, false)
            drawSeries(pts, root.lineColor, true)
        }

        Component.onCompleted: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    Text {
        anchors.centerIn: parent
        visible: root.bars.length === 0
        text: "No chart data"
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.panelHintFontPixelSize
        opacity: 0.45
    }
}
