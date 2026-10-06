import QtQuick
import qs.commons

Canvas {
  id: root

  property var bars: []
  property var compareBars: []
  property string chartStyle: "bar"
  property color accent: Theme.accent
  property color bright: Theme.foreground
  property color muted: Theme.muted

  readonly property real dpr: Math.max(1, Screen.devicePixelRatio)

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

  function paintCompare(ctx, series, w, h, maxV) {
    if (!series || series.length < 2 || maxV <= 0) return
    var n = series.length
    var plotH = Math.max(4, h - 6)
    var pts = []
    for (var i = 0; i < n; i++) {
      var value = series[i] && series[i].value
      if (typeof value !== "number") {
        pts.push(null)
        continue
      }
      var x = n === 1 ? w / 2 : (i / (n - 1)) * (w - 4) + 2
      var y = (plotH - 2) - (value / maxV) * (plotH - 4)
      pts.push({ x: x, y: y })
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
      var x = (i + 0.5) * slot
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
    var plotH = Math.max(4, h - 6)
    var pts = []
    for (var i = 0; i < n; i++) {
      var value = series[i] && typeof series[i].value === "number" ? series[i].value : 0
      var x = n === 1 ? w / 2 : (i / (n - 1)) * (w - 4) + 2
      var y = (plotH - 2) - (value / maxV) * (plotH - 4)
      pts.push({ x: x, y: y })
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

  onBarsChanged: requestPaint()
  onCompareBarsChanged: requestPaint()
  onChartStyleChanged: requestPaint()
  onAccentChanged: requestPaint()
  onBrightChanged: requestPaint()
  onMutedChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  onDprChanged: requestPaint()
  onVisibleChanged: if (visible) requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    if (ctx.reset) ctx.reset()
    ctx.setTransform(root.dpr, 0, 0, root.dpr, 0, 0)
    ctx.clearRect(0, 0, width, height)
    if (width < 4 || height < 4) return
    var series = root.bars || []
    var compare = root.compareBars || []
    var maxPts = Math.max(2, Math.floor(width / 6))
    if (series.length > maxPts) {
      compare = root.resampleAligned(compare, maxPts)
      series = root.resample(series, maxPts)
    } else if (compare.length !== series.length) {
      compare = root.resampleAligned(compare, series.length)
    }
    var maxV = Math.max(root.maxValue(series), root.maxValue(compare))
    if (root.chartStyle === "line") root.paintLine(ctx, series, width, height, maxV)
    else root.paintBar(ctx, series, width, height, maxV)
    root.paintCompare(ctx, compare, width, height, maxV)
  }
}
