import QtQuick
import qs.commons

// Current series as a filled line over the prior series as a plain line,
// both on one scale.
Canvas {
  id: root

  property var points: []
  property var priorPoints: []
  property color strokeColor: Theme.ansiFallback("green")
  property color priorColor: Theme.accent


  antialiasing: true

  onPointsChanged: requestPaint()
  onPriorPointsChanged: requestPaint()
  onStrokeColorChanged: requestPaint()
  onPriorColorChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  onVisibleChanged: if (visible) requestPaint()

  function trace(ctx, pts) {
    var open = false
    for (var i = 0; i < pts.length; i++) {
      if (!pts[i]) {
        open = false
        continue
      }
      if (open) ctx.lineTo(pts[i].x, pts[i].y)
      else ctx.moveTo(pts[i].x, pts[i].y)
      open = true
    }
  }

  onPaint: {
    var ctx = getContext("2d")
    if (ctx.reset) ctx.reset()
    ctx.clearRect(0, 0, width, height)
    var current = root.points || []
    var prior = root.priorPoints || []
    if (width < 4 || height < 4 || (current.length < 2 && prior.length < 2)) return

    var minV = Infinity
    var maxV = -Infinity
    var all = current.concat(prior)
    for (var i = 0; i < all.length; i++) {
      var v = all[i]
      if (typeof v !== "number" || !isFinite(v)) continue
      if (v < minV) minV = v
      if (v > maxV) maxV = v
    }
    if (!isFinite(minV)) return
    var span = maxV - minV || 1
    var pad = 1.5
    var plotW = width - pad * 2
    var plotH = height - pad * 2

    function project(series) {
      var out = []
      var n = series.length
      for (var p = 0; p < n; p++) {
        var value = series[p]
        if (typeof value !== "number" || !isFinite(value)) {
          out.push(null)
          continue
        }
        out.push({
          x: pad + (n === 1 ? plotW / 2 : (p / (n - 1)) * plotW),
          y: height - pad - ((value - minV) / span) * plotH
        })
      }
      return out
    }

    ctx.lineJoin = "round"
    ctx.lineCap = "round"

    if (prior.length > 1) {
      ctx.beginPath()
      root.trace(ctx, project(prior))
      ctx.strokeStyle = root.priorColor
      ctx.globalAlpha = 0.85
      ctx.lineWidth = 1.4
      ctx.stroke()
    }

    if (current.length < 2) return
    var pts = project(current)
    ctx.beginPath()
    ctx.moveTo(pts[0].x, height - pad)
    for (var a = 0; a < pts.length; a++) ctx.lineTo(pts[a].x, pts[a].y)
    ctx.lineTo(pts[pts.length - 1].x, height - pad)
    ctx.closePath()
    ctx.fillStyle = root.strokeColor
    ctx.globalAlpha = 0.16
    ctx.fill()

    ctx.beginPath()
    root.trace(ctx, pts)
    ctx.strokeStyle = root.strokeColor
    ctx.globalAlpha = 1
    ctx.lineWidth = 1.6
    ctx.stroke()
  }
}
