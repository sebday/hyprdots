import QtQuick
import qs.commons

// Dashboard stat card: the border takes the trend colour.
Rectangle {
  id: root

  property var card: ({})
  property color surfaceColor: Theme.mantle
  property color textColor: Theme.foreground
  property color mutedColor: Theme.muted
  property color upColor: Theme.ansiFallback("green")
  property color downColor: Theme.urgent
  property color flatColor: Theme.accent
  property color priorColor: Theme.accent
  property string fontFamily: "monospace"

  signal chosen(string id)

  readonly property string tone: card.tone || "flat"
  readonly property color toneColor: tone === "up" ? upColor : (tone === "down" ? downColor : flatColor)
  readonly property bool selected: card.selected === true
  readonly property bool clickable: card.clickable === true
  readonly property int padX: Theme.space(14)

  radius: Theme.space(8)
  color: selected
    ? Theme.mixColors(surfaceColor, toneColor, 0.1)
    : (hover.hovered && clickable ? Theme.mixColors(surfaceColor, textColor, 0.04) : surfaceColor)
  border.width: selected ? 2 : 1
  border.color: toneColor

  Behavior on color { ColorAnimation { duration: Theme.motionFast } }

  Text {
    id: titleText
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.leftMargin: root.padX
    anchors.rightMargin: root.padX
    anchors.topMargin: Theme.space(10)
    textFormat: Text.PlainText
    text: root.card.label || ""
    elide: Text.ElideRight
    color: root.selected ? root.textColor : Theme.mixColors(root.mutedColor, root.textColor, 0.55)
    font.family: root.fontFamily
    font.pixelSize: Theme.font.bodySmall
    font.bold: true
  }

  Text {
    id: valueText
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: titleText.bottom
    anchors.leftMargin: root.padX
    anchors.rightMargin: root.padX
    anchors.topMargin: Theme.space(2)
    textFormat: Text.PlainText
    text: root.card.value || "—"
    fontSizeMode: Text.HorizontalFit
    minimumPixelSize: Theme.font.body
    color: root.textColor
    font.family: root.fontFamily
    font.pixelSize: Math.round(Theme.font.heading * 1.35)
    font.bold: true
    font.letterSpacing: -0.5
  }

  Row {
    id: figures
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: valueText.bottom
    anchors.leftMargin: root.padX
    anchors.rightMargin: root.padX
    anchors.topMargin: Theme.space(2)
    spacing: Theme.space(6)
    clip: true

    Text {
      id: deltaText
      visible: text !== ""
      textFormat: Text.PlainText
      text: root.card.delta || ""
      color: root.tone === "flat" ? root.mutedColor : root.toneColor
      font.family: root.fontFamily
      font.pixelSize: Theme.font.caption
      font.bold: true
    }

    Text {
      width: Math.max(0, figures.width - (deltaText.visible ? deltaText.width + figures.spacing : 0))
      textFormat: Text.PlainText
      text: root.card.compare || ""
      elide: Text.ElideRight
      color: root.mutedColor
      font.family: root.fontFamily
      font.pixelSize: Theme.font.caption
    }
  }

  Sparkline {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: figures.bottom
    anchors.bottom: parent.bottom
    anchors.leftMargin: root.padX
    anchors.rightMargin: root.padX
    anchors.topMargin: Theme.space(8)
    anchors.bottomMargin: Theme.space(10)
    visible: height > 6
    points: root.card.spark || []
    priorPoints: root.card.priorSpark || []
    strokeColor: root.toneColor
    priorColor: root.priorColor
  }

  HoverHandler {
    id: hover
    cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
  }

  TapHandler {
    enabled: root.clickable
    onTapped: root.chosen(root.card.id)
  }
}
