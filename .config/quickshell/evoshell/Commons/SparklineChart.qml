import QtQuick
import "."

Item {
    id: root

    property var bars: []
    property var secondaryBars: []
    property string style: "bars" // "bars" | "line" | "candlestick"
    property int chartHeight: Theme.sparklineExpandedHeight
    property int barWidth: Theme.sparklineExpandedBarWidth
    property int barSpacing: Theme.sparklineExpandedBarSpacing
    property bool fillWidth: true
    property bool showEmptyLabel: true
    property color lineColor: Theme.accent
    property color secondaryLineColor: "#a6e3a1"
    property color bullishColor: Theme.accent
    property color bearishColor: Theme.urgent
    property int lineWidth: 2

    readonly property bool isLine: style === "line"
    readonly property bool isCandlestick: style === "candlestick"
    readonly property bool hasSecondary: secondaryBars.length > 0

    implicitHeight: chartHeight
    implicitWidth: fillWidth ? 200 : (bars.length * (barWidth + barSpacing) + 4)

    function repaintLine() {
        if (isLine)
            lineCanvas.requestPaint()
    }

    function repaintCandles() {
        if (isCandlestick)
            candleCanvas.requestPaint()
    }

    onBarsChanged: {
        repaintLine()
        repaintCandles()
    }
    onSecondaryBarsChanged: repaintLine()
    onWidthChanged: {
        repaintLine()
        repaintCandles()
    }
    onHeightChanged: {
        repaintLine()
        repaintCandles()
    }
    onChartHeightChanged: {
        repaintLine()
        repaintCandles()
    }
    onLineColorChanged: repaintLine()
    onSecondaryLineColorChanged: repaintLine()
    onBullishColorChanged: repaintCandles()
    onBearishColorChanged: repaintCandles()
    onStyleChanged: {
        repaintLine()
        repaintCandles()
    }

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

    function ohlcForBar(bar, index, series) {
        var pts = series || []
        var close = parseFloat(bar && (bar.close !== undefined ? bar.close : bar.value))
        if (isNaN(close))
            close = 0
        var open = parseFloat(bar && bar.open)
        var high = parseFloat(bar && bar.high)
        var low = parseFloat(bar && bar.low)
        if (!isNaN(open) && !isNaN(high) && !isNaN(low))
            return { open: open, high: high, low: low, close: close }
        var prev = close
        if (index > 0) {
            var p = pts[index - 1]
            prev = parseFloat(p && (p.close !== undefined ? p.close : p.value))
            if (isNaN(prev))
                prev = close
        }
        return {
            open: prev,
            high: Math.max(prev, close),
            low: Math.min(prev, close),
            close: close
        }
    }

    function ohlcValueRange() {
        var pts = bars || []
        var minV = Number.POSITIVE_INFINITY
        var maxV = Number.NEGATIVE_INFINITY
        for (var i = 0; i < pts.length; i++) {
            var ohlc = ohlcForBar(pts[i], i, pts)
            if (ohlc.low < minV) minV = ohlc.low
            if (ohlc.high > maxV) maxV = ohlc.high
        }
        if (!isFinite(minV) || !isFinite(maxV))
            return { min: 0, max: 1 }
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

    function combinedValueRange() {
        if (!hasSecondary)
            return valueRangeFor(bars)
        var combined = []
        var i
        for (i = 0; i < bars.length; i++)
            combined.push(bars[i])
        for (i = 0; i < secondaryBars.length; i++)
            combined.push(secondaryBars[i])
        return valueRangeFor(combined)
    }

    Row {
        id: chartRow
        visible: !root.isLine && !root.isCandlestick
        anchors.fill: parent
        spacing: root.scaledBarSpacing

        Repeater {
            model: root.bars

            Item {
                required property var modelData
                width: root.effectiveBarWidth
                height: chartRow.height

                Rectangle {
                    width: parent.width
                    height: modelData.level > 0
                        ? Math.max(2, chartRow.height * modelData.level / 7)
                        : 0
                    anchors.bottom: parent.bottom
                    radius: Theme.radiusS
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
            var sharedRange = root.hasSecondary ? root.combinedValueRange() : null

            function drawSeries(series, color, fill, range) {
                if (!series || series.length === 0)
                    return
                var resolved = range || root.valueRangeFor(series)
                var minV = resolved.min
                var maxV = resolved.max
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
                drawSeries(root.secondaryBars, root.secondaryLineColor, false, sharedRange)
            drawSeries(pts, root.lineColor, !root.hasSecondary, sharedRange)
        }

        Component.onCompleted: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    Canvas {
        id: candleCanvas
        visible: root.isCandlestick
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var pts = root.bars || []
            if (pts.length === 0)
                return

            var w = width
            var h = height
            var padX = 2
            var padY = 3
            var usableW = Math.max(1, w - padX * 2)
            var usableH = Math.max(1, h - padY * 2)
            var slotW = pts.length > 0 ? usableW / pts.length : usableW
            var bodyW = Math.max(2, Math.min(10, slotW * 0.62))
            var range = root.ohlcValueRange()
            var minV = range.min
            var maxV = range.max
            var span = maxV - minV || 1

            function yAt(v) {
                var n = parseFloat(v)
                if (isNaN(n))
                    n = minV
                return padY + usableH - ((n - minV) / span) * usableH
            }

            for (var i = 0; i < pts.length; i++) {
                var ohlc = root.ohlcForBar(pts[i], i, pts)
                var x = padX + i * slotW + slotW / 2
                var yHigh = yAt(ohlc.high)
                var yLow = yAt(ohlc.low)
                var yOpen = yAt(ohlc.open)
                var yClose = yAt(ohlc.close)
                var bullish = ohlc.close >= ohlc.open
                var color = bullish ? root.bullishColor : root.bearishColor

                ctx.beginPath()
                ctx.moveTo(x, yHigh)
                ctx.lineTo(x, yLow)
                ctx.strokeStyle = color
                ctx.lineWidth = 1
                ctx.stroke()

                var top = Math.min(yOpen, yClose)
                var bodyH = Math.max(1, Math.abs(yClose - yOpen))
                ctx.fillStyle = color
                ctx.globalAlpha = bullish ? 0.92 : 0.88
                ctx.fillRect(x - bodyW / 2, top, bodyW, bodyH)
                ctx.globalAlpha = 1
            }
        }

        Component.onCompleted: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    Text {
        anchors.centerIn: parent
        visible: root.showEmptyLabel && root.bars.length === 0
        text: "No chart data"
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeS
        opacity: Theme.opacityDisabled
    }
}
