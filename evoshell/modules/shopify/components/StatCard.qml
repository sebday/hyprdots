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
  // The column sets one track for every card, so the lines share a width
  // and a left edge down the grid. Zero leaves the line under the text.
  property int sparkTrack: 0
  property bool alignSpark: false

  readonly property int padX: Theme.space(14)
  readonly property int padY: Theme.space(10)
  readonly property int sparkGap: Theme.space(16)
  readonly property int sparkMin: Theme.space(72)
  readonly property int sparkHeightBeside: Theme.space(44)
  readonly property bool sparkBeside: alignSpark
    && sparkTrack >= sparkMin
    && width >= padX * 2 + sparkGap + sparkTrack + Theme.space(88)

  radius: Theme.space(8)
  color: selected
    ? Theme.mixColors(surfaceColor, toneColor, 0.1)
    : (hover.hovered && clickable ? Theme.mixColors(surfaceColor, textColor, 0.04) : surfaceColor)
  border.width: selected ? 2 : 1
  border.color: toneColor

  Behavior on color { ColorAnimation { duration: Theme.motionFast } }

  // Text keeps the left of the card. The spark is a shared slot on the right,
  // shorter than the card, or the full width underneath when the card is narrow.
  Column {
    id: textCol
    x: root.padX
    y: root.sparkBeside
      ? Math.max(root.padY, Math.round((root.height - height) / 2))
      : root.padY
    width: root.sparkBeside
      ? Math.max(0, root.width - root.padX * 2 - root.sparkGap - root.sparkTrack)
      : Math.max(0, root.width - root.padX * 2)
    spacing: Theme.space(2)

    Text {
      id: titleText
      width: textCol.width
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
      width: textCol.width
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
      width: textCol.width
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
        id: compareText
        width: Math.max(0, figures.width - (deltaText.visible ? deltaText.implicitWidth + figures.spacing : 0))
        textFormat: Text.PlainText
        text: root.card.compare || ""
        elide: Text.ElideRight
        color: root.mutedColor
        font.family: root.fontFamily
        font.pixelSize: Theme.font.caption
      }
    }
  }

  Sparkline {
    x: root.sparkBeside ? root.width - root.padX - width : root.padX
    y: root.sparkBeside
      ? Math.max(root.padY, Math.round((root.height - height) / 2))
      : textCol.y + textCol.height + Theme.space(8)
    width: root.sparkBeside ? root.sparkTrack : Math.max(0, root.width - root.padX * 2)
    height: root.sparkBeside
      ? Math.min(root.sparkHeightBeside, Math.max(0, root.height - root.padY * 2))
      : Math.max(0, root.height - root.padY - y)
    visible: width > 8 && height > 6
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
