import QtQuick
import qs.commons
import "../Model.js" as Model

Canvas {
  id: root

  property var bars: []
  property var compareBars: []
  property string chartStyle: "bar"
  property string metric: "revenue"
  property string symbol: "£"
  property string fontFamily: "monospace"
  property color accent: Theme.accent
  property color bright: Theme.foreground
  property color muted: Theme.muted
  property color backgroundColor: Theme.background

  readonly property real dpr: Math.max(1, Screen.devicePixelRatio)

  property bool pointerInside: false
  property real pointerX: 0
  property int hoverIndex: -1
  property real markerX: 0
  property real markerY: 0
  property real compareY: 0
  property bool compareVisible: false
  property string hoverDate: ""
  property string hoverValue: ""
  property string hoverCompare: ""

  function resample(series, width) {
    if (width < 1 || !series || series.length === 0) return []
    if (series.length === 1) {
      var flat = []
      for (var i = 0; i < width; i++) flat.push(series[0])
      return flat
    }
    var out = []
    var denom = width - 1
    for (var j = 0; j < width; j++) {
      var src = Math.round(j * (series.length - 1) / denom)
      if (src >= series.length) src = series.length - 1
      out.push(series[src])
    }
    return out
  }

  function maxValue(series) {
    var maxV = 0
    if (!series) return maxV
    for (var i = 0; i < series.length; i++) {
      var v = series[i] && series[i].value
      if (typeof v === "number" && v > maxV) maxV = v
    }
    return maxV
  }

  function resampleAligned(series, count) {
    if (!series || count < 1) return []
    if (series.length === count) return series
    if (series.length === 0) return []
    var out = []
    var denom = count - 1
    for (var j = 0; j < count; j++) {
      var src = series.length === 1 ? 0 : Math.round(j * (series.length - 1) / denom)
      if (src >= series.length) src = series.length - 1
      out.push(series[src])
    }
    return out
  }

  function plotted(w) {
    var series = root.bars || []
    var compare = root.compareBars || []
    var maxPts = Math.max(2, Math.floor(w / 6))
    if (series.length > maxPts) {
      compare = root.resampleAligned(compare, maxPts)
      series = root.resample(series, maxPts)
    } else if (compare.length !== series.length) {
      compare = root.resampleAligned(compare, series.length)
    }
    return {
      series: series,
      compare: compare,
      maxV: Math.max(root.maxValue(series), root.maxValue(compare))
    }
  }

  function lineX(i, n, w) {
    return n === 1 ? w / 2 : (i / (n - 1)) * (w - 4) + 2
  }

  function lineY(value, h, maxV) {
    var plotH = Math.max(4, h - 6)
    var v = typeof value === "number" && isFinite(value) ? value : 0
    if (!(maxV > 0)) return plotH - 2
    return (plotH - 2) - (v / maxV) * (plotH - 4)
  }

  function barX(i, n, w) {
    return (i + 0.5) * (w / n)
  }

  function barTop(value, h, maxV) {
    if (typeof value !== "number" || !isFinite(value) || value <= 0 || !(maxV > 0))
      return h - 2
    var step = Math.max(3, Math.min(5, Math.floor(h / 48)))
    var bh = Math.max(step, (value / maxV) * h)
    return h - bh
  }

  function indexAt(x, n, w) {
    if (n < 1 || w < 4) return -1
    var i
    if (root.chartStyle === "line") {
      if (n === 1) return 0
      var span = w - 4
      if (span <= 0) return 0
      i = Math.round(((x - 2) / span) * (n - 1))
    } else {
      i = Math.floor(x / (w / n))
    }
    if (i < 0) return 0
    if (i >= n) return n - 1
    return i
  }

  function seriesPoint(series, i, w, h, maxV) {
    var n = series.length
    var value = series[i] && series[i].value
    if (root.chartStyle === "line")
      return { x: root.lineX(i, n, w), y: root.lineY(value, h, maxV) }
    return { x: root.barX(i, n, w), y: root.barTop(value, h, maxV) }
  }

  function clearHover() {
    root.hoverIndex = -1
    root.hoverDate = ""
    root.hoverValue = ""
    root.hoverCompare = ""
    root.compareVisible = false
  }

  function updateHover(x) {
    root.pointerX = x
    if (root.width < 4 || root.height < 4) {
      root.clearHover()
      return
    }
    var plot = root.plotted(root.width)
    var n = plot.series.length
    var i = root.indexAt(x, n, root.width)
    if (i < 0) {
      root.clearHover()
      return
    }
    var bar = plot.series[i]
    var value = bar && bar.value
    var pt = root.seriesPoint(plot.series, i, root.width, root.height, plot.maxV)
    root.hoverIndex = i
    root.markerX = pt.x
    root.markerY = pt.y
    root.hoverDate = Model.formatDay(bar && bar.date)
    root.hoverValue = Model.formatSeriesValue(root.metric, typeof value === "number" ? value : NaN, root.symbol)
    var cmp = plot.compare && plot.compare[i]
    var cmpVal = cmp && typeof cmp.value === "number" ? cmp.value : NaN
    if (isFinite(cmpVal) && plot.maxV > 0) {
      root.compareVisible = true
      root.compareY = root.lineY(cmpVal, root.height, plot.maxV)
      root.hoverCompare = Model.versusText(Model.formatSeriesValue(root.metric, cmpVal, root.symbol))
    } else {
      root.compareVisible = false
      root.compareY = 0
      root.hoverCompare = ""
    }
  }

  function refreshHover() {
    if (root.pointerInside) root.updateHover(root.pointerX)
  }

  function paintCompare(ctx, series, w, h, maxV) {
    if (!series || series.length < 2 || maxV <= 0) return
    var n = series.length
    var pts = []
    for (var i = 0; i < n; i++) {
      var value = series[i] && series[i].value
      if (typeof value !== "number") {
        pts.push(null)
        continue
      }
      pts.push({ x: root.lineX(i, n, w), y: root.lineY(value, h, maxV) })
    }
    ctx.fillStyle = root.muted
    for (var p = 1; p < pts.length; p++) {
      var a = pts[p - 1]
      var b = pts[p]
      if (!a || !b) continue
      var dist = Math.hypot(b.x - a.x, b.y - a.y)
      var steps = Math.max(1, Math.floor(dist / 5))
      for (var s = 0; s <= steps; s++) {
        var t = s / steps
        ctx.globalAlpha = 0.55
        ctx.beginPath()
        ctx.arc(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, 1.05, 0, Math.PI * 2)
        ctx.fill()
      }
    }
    ctx.globalAlpha = 1
  }

  function paintBar(ctx, series, w, h, maxV) {
    if (!series || series.length < 1 || w < 4 || h < 4) return
    var n = series.length
    var slot = w / n
    var plotH = h
    var step = Math.max(3, Math.min(5, Math.floor(h / 48)))

    if (n > 1 && slot > 6) {
      ctx.fillStyle = root.muted
      ctx.globalAlpha = 0.28
      for (var g = 0; g < n - 1; g++) {
        var gx = (g + 1) * slot
        for (var gy = plotH - 2; gy >= 0; gy -= step) {
          ctx.beginPath()
          ctx.arc(gx, gy, 0.8, 0, Math.PI * 2)
          ctx.fill()
        }
      }
      ctx.globalAlpha = 1
    }

    if (maxV <= 0) return
    var dot = Math.max(1.3, Math.min(2.2, slot * 0.18))
    for (var i = 0; i < n; i++) {
      var value = series[i] && series[i].value
      if (typeof value !== "number" || value <= 0) continue
      var bh = Math.max(step, (value / maxV) * plotH)
      var x = root.barX(i, n, w)
      var top = plotH - bh
      for (var y = plotH - 2; y >= top; y -= step) {
        var t = bh <= 1 ? 0 : (y - top) / bh
        ctx.fillStyle = t < 0.35 ? root.bright : root.accent
        ctx.globalAlpha = t < 0.7 ? 1 : 0.75
        ctx.beginPath()
        ctx.arc(x, y, dot, 0, Math.PI * 2)
        ctx.fill()
      }
    }
    ctx.globalAlpha = 1
  }

  function paintLine(ctx, series, w, h, maxV) {
    var n = series.length
    ctx.globalAlpha = 0.55
    ctx.fillStyle = root.muted
    ctx.fillRect(0, h - 3, w, 2)
    ctx.globalAlpha = 1
    if (maxV <= 0 || n < 1) return
    var pts = []
    for (var i = 0; i < n; i++) {
      var value = series[i] && typeof series[i].value === "number" ? series[i].value : 0
      pts.push({ x: root.lineX(i, n, w), y: root.lineY(value, h, maxV) })
    }
    ctx.fillStyle = root.accent
    for (var p = 1; p < pts.length; p++) {
      var a = pts[p - 1]
      var b = pts[p]
      var dist = Math.hypot(b.x - a.x, b.y - a.y)
      var steps = Math.max(1, Math.floor(dist / 4))
      for (var s = 0; s <= steps; s++) {
        var t = s / steps
        ctx.globalAlpha = 0.9
        ctx.beginPath()
        ctx.arc(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, 1.1, 0, Math.PI * 2)
        ctx.fill()
      }
    }
    ctx.globalAlpha = 1
    for (var d = 0; d < pts.length; d++) {
      ctx.beginPath()
      ctx.arc(pts[d].x, pts[d].y, 2.4, 0, Math.PI * 2)
      ctx.fill()
    }
  }

  canvasSize: Qt.size(Math.max(1, width * dpr), Math.max(1, height * dpr))
  antialiasing: true

  onBarsChanged: { requestPaint(); refreshHover() }
  onCompareBarsChanged: { requestPaint(); refreshHover() }
  onChartStyleChanged: { requestPaint(); refreshHover() }
  onAccentChanged: requestPaint()
  onBrightChanged: requestPaint()
  onMutedChanged: requestPaint()
  onWidthChanged: { requestPaint(); refreshHover() }
  onHeightChanged: { requestPaint(); refreshHover() }
  onDprChanged: requestPaint()
  onVisibleChanged: if (visible) requestPaint()
  onMetricChanged: refreshHover()
  onSymbolChanged: refreshHover()

  onPaint: {
    var ctx = getContext("2d")
    if (ctx.reset) ctx.reset()
    ctx.setTransform(root.dpr, 0, 0, root.dpr, 0, 0)
    ctx.clearRect(0, 0, width, height)
    if (width < 4 || height < 4) return
    var plot = root.plotted(width)
    if (root.chartStyle === "line") root.paintLine(ctx, plot.series, width, height, plot.maxV)
    else root.paintBar(ctx, plot.series, width, height, plot.maxV)
    root.paintCompare(ctx, plot.compare, width, height, plot.maxV)
  }

  Rectangle {
    visible: root.hoverIndex >= 0
    x: Math.round(root.markerX)
    y: 0
    width: 1
    height: parent.height
    color: root.accent
    opacity: 0.4
  }

  Rectangle {
    visible: root.hoverIndex >= 0 && root.compareVisible
    width: 6
    height: 6
    radius: 3
    color: root.muted
    x: root.markerX - width / 2
    y: root.compareY - height / 2
  }

  Rectangle {
    visible: root.hoverIndex >= 0
    width: 8
    height: 8
    radius: 4
    color: root.bright
    border.width: 1
    border.color: root.accent
    x: root.markerX - width / 2
    y: root.markerY - height / 2
  }

  Rectangle {
    id: chip
    visible: root.hoverIndex >= 0 && (root.hoverValue !== "" || root.hoverDate !== "")
    radius: Theme.space(4)
    color: root.backgroundColor
    border.width: 1
    border.color: root.accent
    width: chipRow.implicitWidth + Theme.space(8) * 2
    height: chipRow.implicitHeight + Theme.space(3) * 2
    x: Math.max(0, Math.min(root.width - width, root.markerX - width / 2))
    y: {
      var gap = Theme.space(8)
      var above = root.markerY - height - gap
      if (above >= 0) return above
      return Math.max(0, Math.min(root.height - height, root.markerY + gap))
    }

    Row {
      id: chipRow
      x: Theme.space(8)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Theme.space(6)

      Text {
        visible: root.hoverDate !== ""
        textFormat: Text.PlainText
        text: root.hoverDate
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Theme.font.caption
      }

      Text {
        visible: root.hoverValue !== ""
        textFormat: Text.PlainText
        text: root.hoverValue
        color: root.bright
        font.family: root.fontFamily
        font.pixelSize: Theme.font.body
        font.bold: true
      }

      Text {
        visible: root.hoverCompare !== ""
        textFormat: Text.PlainText
        text: root.hoverCompare
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Theme.font.caption
      }
    }
  }

  HoverHandler {
    cursorShape: Qt.CrossCursor
    onPointChanged: if (hovered) root.updateHover(point.position.x)
    onHoveredChanged: {
      if (hovered) {
        root.pointerInside = true
        root.updateHover(point.position.x)
      } else {
        root.pointerInside = false
        root.clearHover()
      }
    }
  }
}
