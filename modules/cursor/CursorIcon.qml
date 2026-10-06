import QtQuick
import qs.commons

// Official Cursor mark: the cursor silhouette split into the two product faces.
Item {
  id: root

  property real iconSize: Theme.font.icon
  property color color: Theme.foreground

  readonly property real markHeight: 25.25
  readonly property real markCenterX: 13.535
  readonly property real markCenterY: 13.63

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  Canvas {
    id: canvas
    anchors.fill: parent
    antialiasing: true

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var s = root.width / root.markHeight
      ctx.translate(root.width / 2, root.height / 2)
      ctx.scale(s, s)
      ctx.translate(-root.markCenterX, -root.markCenterY)

      ctx.beginPath()
      ctx.moveTo(22.8416, 1.387)
      ctx.bezierCurveTo(23.4132, 1.0062, 24.1735, 1.44515, 24.1295, 2.13055)
      ctx.lineTo(22.6326, 25.4656)
      ctx.bezierCurveTo(22.5957, 26.0405, 21.8646, 26.2609, 21.5162, 25.8022)
      ctx.lineTo(15.0114, 17.2395)
      ctx.bezierCurveTo(14.8429, 17.0177, 14.5923, 16.873, 14.316, 16.838)
      ctx.lineTo(3.6481, 15.486)
      ctx.bezierCurveTo(3.07656, 15.4136, 2.9019, 14.6703, 3.38136, 14.3509)
      ctx.closePath()
      ctx.clip()

      ctx.fillStyle = root.color
      ctx.beginPath()
      ctx.moveTo(1.79102, 15.2782)
      ctx.lineTo(24.2386, 0.457031)
      ctx.lineTo(14.6808, 17.0116)
      ctx.closePath()
      ctx.fill()

      ctx.globalAlpha = 0.45
      ctx.beginPath()
      ctx.moveTo(22.6278, 27.3078)
      ctx.lineTo(24.2394, 0.457031)
      ctx.lineTo(14.6816, 17.0116)
      ctx.closePath()
      ctx.fill()
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()
  }

  Connections {
    target: root
    function onColorChanged() { canvas.requestPaint() }
    function onIconSizeChanged() { canvas.requestPaint() }
  }
}
