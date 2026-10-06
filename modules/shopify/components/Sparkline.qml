import QtQuick

Canvas {
  id: root

  property var points: []
  property color strokeColor: "#b9f27c"

  readonly property real dpr: Math.max(1, Screen.devicePixelRatio)

  canvasSize: Qt.size(Math.max(1, width * dpr), Math.max(1, height * dpr))
  antialiasing: true

  onPointsChanged: requestPaint()
  onStrokeColorChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  onDprChanged: requestPaint()
  onVisibleChanged: if (visible) requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    if (ctx.reset) ctx.reset()
    ctx.setTransform(root.dpr, 0, 0, root.dpr, 0, 0)
    ctx.clearRect(0, 0, width, height)
    var series = root.points || []
    var n = series.length
    if (n < 2 || width < 4 || height < 4) return

    var minV = series[0]
    var maxV = series[0]
    for (var i = 1; i < n; i++) {
      var v = typeof series[i] === "number" ? series[i] : 0
      if (v < minV) minV = v
      if (v > maxV) maxV = v
    }
    var span = maxV - minV
    var pad = 1.5
    var plotW = width - pad * 2
    var plotH = height - pad * 2
    var pts = []
    for (var p = 0; p < n; p++) {
      var value = typeof series[p] === "number" ? series[p] : 0
      var x = pad + (n === 1 ? plotW / 2 : (p / (n - 1)) * plotW)
      var y = span < 1e-9 ? pad + plotH / 2 : pad + plotH - ((value - minV) / span) * plotH
      pts.push({ x: x, y: y })
    }

    ctx.beginPath()
    ctx.moveTo(pts[0].x, height - pad)
    for (var a = 0; a < pts.length; a++) ctx.lineTo(pts[a].x, pts[a].y)
    ctx.lineTo(pts[pts.length - 1].x, height - pad)
    ctx.closePath()
    ctx.fillStyle = root.strokeColor
    ctx.globalAlpha = 0.16
    ctx.fill()

    ctx.beginPath()
    ctx.moveTo(pts[0].x, pts[0].y)
    for (var b = 1; b < pts.length; b++) ctx.lineTo(pts[b].x, pts[b].y)
    ctx.strokeStyle = root.strokeColor
    ctx.globalAlpha = 1
    ctx.lineWidth = 1.6
    ctx.lineJoin = "round"
    ctx.lineCap = "round"
    ctx.stroke()
  }
}
