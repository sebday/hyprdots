import QtQuick

Item {
  id: root

  property var bars: []
  property var secondaryBars: []
  property string style: "bars"
  property int chartHeight: 96
  property int barWidth: 6
  property int barSpacing: 2
  property bool fillWidth: true
  property bool showEmptyLabel: true
  property color lineColor: "#89b4fa"
  property color secondaryLineColor: "#a6e3a1"
  property color bullishColor: "#89b4fa"
  property color bearishColor: "#f38ba8"
  property int lineWidth: 2
  property string fontFamily: "sans-serif"
  property real revealProgress: 1
  property bool active: false
  property bool pendingOpenReveal: false

  readonly property bool isLine: style === "line"
  readonly property bool isCandlestick: style === "candlestick"
  readonly property bool hasSecondary: secondaryBars.length > 0

  implicitHeight: chartHeight
  implicitWidth: fillWidth ? 200 : (bars.length * (barWidth + barSpacing) + 4)

  function repaintLine() {
    if (isLine) lineCanvas.requestPaint()
  }

  function repaintCandles() {
    if (isCandlestick) candleCanvas.requestPaint()
  }

  function candleReveal(index, count) {
    if (count <= 0)
      return 1
    var edge = revealProgress * count - index
    return Math.min(1, Math.max(0, edge / Math.max(1, count * 0.12)))
  }

  function startReveal() {
    revealProgress = 0
    revealAnim.restart()
  }

  function scheduleReveal() {
    if (!active || bars.length === 0)
      return
    Qt.callLater(startReveal)
  }

  onActiveChanged: {
    if (active) {
      if (bars.length > 0)
        scheduleReveal()
      else
        pendingOpenReveal = true
    } else {
      pendingOpenReveal = false
      revealAnim.stop()
      revealProgress = 1
    }
  }

  onBarsChanged: {
    if (pendingOpenReveal && active && bars.length > 0) {
      pendingOpenReveal = false
      scheduleReveal()
    }
    repaintLine()
    repaintCandles()
  }
  onRevealProgressChanged: {
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

  Component.onCompleted: {
    if (active && bars.length > 0)
      scheduleReveal()
  }

  NumberAnimation {
    id: revealAnim
    target: root
    property: "revealProgress"
    from: 0
    to: 1
    duration: 800
    easing.type: Easing.OutCubic
  }

  FrameAnimation {
    running: revealAnim.running
    onTriggered: {
      repaintLine()
      repaintCandles()
    }
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
        required property int index
        width: root.effectiveBarWidth
        height: chartRow.height

        Rectangle {
          width: parent.width
          height: modelData.level > 0
            ? Math.max(2, chartRow.height * modelData.level / 7 * (0.35 + 0.65 * root.candleReveal(index, root.bars.length)))
            : 0
          anchors.bottom: parent.bottom
          radius: 2
          color: modelData.color || root.bullishColor
          opacity: 0.85 * root.candleReveal(index, root.bars.length)
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
      var revealEnd = root.revealProgress * Math.max(0, pts.length - 1)

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

        function pointAt(idx) {
          var clamped = Math.min(revealEnd, Math.max(0, idx))
          var base = Math.floor(clamped)
          var frac = clamped - base
          var x = padX + clamped * step
          var y0 = yAt(series[base].value)
          if (frac <= 0 || base >= series.length - 1)
            return { x: x, y: y0 }
          var y1 = yAt(series[base + 1].value)
          return { x: x, y: y0 + (y1 - y0) * frac }
        }

        var visibleEnd = Math.min(series.length - 1, Math.ceil(revealEnd))
        if (visibleEnd < 0)
          return

        if (fill) {
          ctx.beginPath()
          for (var i = 0; i <= visibleEnd; i++) {
            var pt = pointAt(i)
            if (i === 0) ctx.moveTo(pt.x, pt.y)
            else ctx.lineTo(pt.x, pt.y)
          }
          var tail = pointAt(revealEnd)
          ctx.lineTo(tail.x, h)
          ctx.lineTo(padX, h)
          ctx.closePath()
          ctx.globalAlpha = 0.14 * root.revealProgress
          ctx.fillStyle = color
          ctx.fill()
          ctx.globalAlpha = 1
        }

        ctx.beginPath()
        for (var j = 0; j <= visibleEnd; j++) {
          var pt2 = pointAt(j)
          if (j === 0) ctx.moveTo(pt2.x, pt2.y)
          else ctx.lineTo(pt2.x, pt2.y)
        }
        var tailPt = pointAt(revealEnd)
        ctx.lineTo(tailPt.x, tailPt.y)
        ctx.strokeStyle = color
        ctx.lineWidth = root.lineWidth
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        ctx.globalAlpha = 0.35 + 0.65 * root.revealProgress
        ctx.stroke()
        ctx.globalAlpha = 1

        ctx.beginPath()
        ctx.arc(tailPt.x, tailPt.y, 3, 0, Math.PI * 2)
        ctx.fillStyle = color
        ctx.globalAlpha = 0.35 + 0.65 * root.revealProgress
        ctx.fill()
        ctx.globalAlpha = 1
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
        var reveal = root.candleReveal(i, pts.length)
        if (reveal <= 0)
          continue

        var ohlc = root.ohlcForBar(pts[i], i, pts)
        var x = padX + i * slotW + slotW / 2
        var yHigh = yAt(ohlc.high)
        var yLow = yAt(ohlc.low)
        var yOpen = yAt(ohlc.open)
        var yClose = yAt(ohlc.close)
        var bullish = ohlc.close >= ohlc.open
        var color = bullish ? root.bullishColor : root.bearishColor
        var grow = 0.15 + 0.85 * reveal

        yHigh = yClose + (yHigh - yClose) * grow
        yLow = yClose + (yLow - yClose) * grow
        yOpen = yClose + (yOpen - yClose) * grow

        ctx.beginPath()
        ctx.moveTo(x, yHigh)
        ctx.lineTo(x, yLow)
        ctx.strokeStyle = color
        ctx.lineWidth = 1
        ctx.globalAlpha = reveal
        ctx.stroke()

        var top = Math.min(yOpen, yClose)
        var bodyH = Math.max(1, Math.abs(yClose - yOpen) * grow)
        ctx.fillStyle = color
        ctx.globalAlpha = (bullish ? 0.92 : 0.88) * reveal
        ctx.fillRect(x - bodyW / 2, top, bodyW, bodyH)
        ctx.globalAlpha = 1
      }
    }

    Component.onCompleted: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
  }

  Text {
    textFormat: Text.PlainText
    anchors.centerIn: parent
    visible: root.showEmptyLabel && root.bars.length === 0
    text: "No chart data"
    color: "#cdd6f4"
    font.family: root.fontFamily
    font.pixelSize: 11
    opacity: 0.35
  }
}
