import QtQuick
import qs.commons
import "../Model.js" as Model

// Current period as columns, prior period as a line, on a shared y axis.
Canvas {
  id: root

  property var bars: []
  property var compareBars: []
  property string metric: "revenue"
  property string symbol: "£"
  property string fontFamily: "monospace"
  property color currentColor: Theme.accent
  property color priorColor: Theme.accent
  property color textColor: Theme.foreground
  property color mutedColor: Theme.muted
  property color gridColor: Theme.foregroundDivider
  property color surfaceColor: Theme.mantle

  readonly property int ticks: 4
  readonly property int labelPx: Theme.font.caption
  readonly property int padTop: Math.ceil(labelPx / 2) + 2
  readonly property int padBottom: labelPx + Theme.space(10)

  readonly property var axis: {
    var maxV = 0
    var all = (root.bars || []).concat(root.compareBars || [])
    for (var i = 0; i < all.length; i++) {
      var v = all[i] && all[i].value
      if (typeof v === "number" && isFinite(v) && v > maxV) maxV = v
    }
    var top = Model.niceCeil(maxV, root.ticks)
    var labels = []
    var widest = 0
    for (var t = 0; t <= root.ticks; t++) {
      var text = Model.axisValue(root.metric, (top / root.ticks) * t, root.symbol)
      labels.push(text)
      widest = Math.max(widest, axisMetrics.advanceWidth(text))
    }
    return { top: top, labels: labels, padLeft: Math.ceil(widest) + Theme.space(10) }
  }

  readonly property real plotX: axis.padLeft
  readonly property real plotW: Math.max(1, width - plotX - 2)
  readonly property real plotH: Math.max(1, height - padTop - padBottom)
  readonly property int count: (bars || []).length
  readonly property real slot: count > 0 ? plotW / count : plotW

  property int hoverIndex: -1

  function yFor(value) {
    var v = typeof value === "number" && isFinite(value) ? value : 0
    return padTop + plotH - (axis.top > 0 ? (v / axis.top) * plotH : 0)
  }

  function xCenter(i) {
    return plotX + (i + 0.5) * slot
  }

  function roundedTop(ctx, x, y, w, h, r) {
    var rr = Math.min(r, w / 2, h)
    ctx.beginPath()
    ctx.moveTo(x, y + h)
    ctx.lineTo(x, y + rr)
    ctx.arcTo(x, y, x + rr, y, rr)
    ctx.lineTo(x + w - rr, y)
    ctx.arcTo(x + w, y, x + w, y + rr, rr)
    ctx.lineTo(x + w, y + h)
    ctx.closePath()
  }

  FontMetrics {
    id: axisMetrics
    font.family: root.fontFamily
    font.pixelSize: root.labelPx
  }

  antialiasing: true

  onBarsChanged: requestPaint()
  onCompareBarsChanged: requestPaint()
  onAxisChanged: requestPaint()
  onHoverIndexChanged: requestPaint()
  onCurrentColorChanged: requestPaint()
  onPriorColorChanged: requestPaint()
  onGridColorChanged: requestPaint()
  onMutedColorChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  onVisibleChanged: if (visible) requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    if (ctx.reset) ctx.reset()
    ctx.clearRect(0, 0, width, height)
    if (width < 40 || height < 40) return

    ctx.font = root.labelPx + "px \"" + root.fontFamily + "\""
    ctx.textBaseline = "middle"

    for (var t = 0; t <= root.ticks; t++) {
      var gy = Math.round(root.padTop + root.plotH - (t / root.ticks) * root.plotH) + 0.5
      ctx.strokeStyle = root.gridColor
      ctx.lineWidth = 1
      ctx.globalAlpha = 1
      ctx.beginPath()
      ctx.moveTo(root.plotX, gy)
      ctx.lineTo(root.plotX + root.plotW, gy)
      ctx.stroke()
      ctx.fillStyle = root.mutedColor
      ctx.textAlign = "right"
      ctx.fillText(root.axis.labels[t] || "", root.plotX - Theme.space(8), gy)
    }

    var series = root.bars || []
    var n = series.length
    if (n === 0) return

    var colW = Math.max(1, root.slot * 0.6)
    for (var i = 0; i < n; i++) {
      var v = series[i] && series[i].value
      if (typeof v !== "number" || !(v > 0)) continue
      var top = root.yFor(v)
      var h = root.padTop + root.plotH - top
      ctx.fillStyle = root.currentColor
      ctx.globalAlpha = root.hoverIndex < 0 || root.hoverIndex === i ? 1 : 0.55
      root.roundedTop(ctx, root.xCenter(i) - colW / 2, top, colW, h, 2)
      ctx.fill()
    }
    ctx.globalAlpha = 1

    var prior = root.compareBars || []
    ctx.strokeStyle = root.priorColor
    ctx.fillStyle = root.priorColor
    ctx.lineWidth = 2
    ctx.lineJoin = "round"
    ctx.lineCap = "round"
    ctx.beginPath()
    var open = false
    var priorCount = 0
    var lone = null
    for (var p = 0; p < Math.min(n, prior.length); p++) {
      var pv = prior[p] && prior[p].value
      if (typeof pv !== "number" || !isFinite(pv)) {
        open = false
        continue
      }
      priorCount++
      var px = root.xCenter(p)
      var py = root.yFor(pv)
      lone = { x: px, y: py }
      if (open) ctx.lineTo(px, py)
      else ctx.moveTo(px, py)
      open = true
    }
    if (priorCount >= 2) {
      ctx.stroke()
    } else if (lone) {
      ctx.setLineDash([4, 4])
      ctx.beginPath()
      ctx.moveTo(root.plotX, lone.y)
      ctx.lineTo(root.plotX + root.plotW, lone.y)
      ctx.stroke()
      ctx.setLineDash([])
      ctx.beginPath()
      ctx.arc(lone.x, lone.y, 4, 0, Math.PI * 2)
      ctx.fill()
    }

    ctx.fillStyle = root.mutedColor
    ctx.textAlign = "center"
    ctx.textBaseline = "alphabetic"
    var labelW = axisMetrics.advanceWidth("Nov 30") + Theme.space(12)
    var every = Math.max(1, Math.ceil(labelW / root.slot))
    var baseY = root.padTop + root.plotH + Theme.space(6) + root.labelPx
    for (var d = n - 1; d >= 0; d -= every) {
      var label = Model.formatDay(series[d] && series[d].date)
      if (!label) continue
      var lx = Math.max(root.plotX + labelW / 2 - Theme.space(6), Math.min(root.xCenter(d), root.plotX + root.plotW - labelW / 2 + Theme.space(6)))
      ctx.fillText(label, lx, baseY)
    }
  }

  readonly property var hoverBar: hoverIndex >= 0 && hoverIndex < count ? bars[hoverIndex] : null
  readonly property var hoverPrior: hoverIndex >= 0 && compareBars && hoverIndex < compareBars.length
    ? compareBars[hoverIndex] : null

  Rectangle {
    id: tip
    visible: root.hoverBar !== null
    radius: Theme.space(6)
    color: root.surfaceColor
    border.width: 1
    border.color: root.gridColor
    width: tipCol.implicitWidth + Theme.space(10) * 2
    height: tipCol.implicitHeight + Theme.space(6) * 2
    x: {
      var cx = root.xCenter(root.hoverIndex)
      var right = cx + root.slot / 2 + Theme.space(8)
      return right + width <= root.width ? right : Math.max(0, cx - root.slot / 2 - Theme.space(8) - width)
    }
    y: root.padTop

    Column {
      id: tipCol
      x: Theme.space(10)
      y: Theme.space(6)
      spacing: Theme.space(2)

      Text {
        textFormat: Text.PlainText
        text: Model.formatDay(root.hoverBar && root.hoverBar.date)
        color: root.mutedColor
        font.family: root.fontFamily
        font.pixelSize: Theme.font.caption
      }

      Row {
        spacing: Theme.space(6)

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: Theme.space(8)
          height: width
          radius: 2
          color: root.currentColor
        }

        Text {
          textFormat: Text.PlainText
          text: Model.formatSeriesValue(root.metric, root.hoverBar ? root.hoverBar.value : NaN, root.symbol) || "—"
          color: root.textColor
          font.family: root.fontFamily
          font.pixelSize: Theme.font.body
          font.bold: true
        }
      }

      Row {
        visible: priorText.text !== ""
        spacing: Theme.space(6)

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: Theme.space(8)
          height: width
          radius: 2
          color: root.priorColor
        }

        Text {
          id: priorText
          textFormat: Text.PlainText
          text: {
            var v = root.hoverPrior && root.hoverPrior.value
            return typeof v === "number" ? Model.formatSeriesValue(root.metric, v, root.symbol) : ""
          }
          color: root.mutedColor
          font.family: root.fontFamily
          font.pixelSize: Theme.font.body
        }
      }
    }
  }

  HoverHandler {
    onPointChanged: {
      if (!hovered || root.count < 1) {
        root.hoverIndex = -1
        return
      }
      var i = Math.floor((point.position.x - root.plotX) / root.slot)
      root.hoverIndex = i >= 0 && i < root.count ? i : -1
    }
    onHoveredChanged: if (!hovered) root.hoverIndex = -1
  }
}
