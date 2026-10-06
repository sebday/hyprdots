import QtQuick
import qs.commons

Item {
  id: root

  property var cards: []
  property color borderColor: Theme.foregroundBorder
  property color backgroundColor: Theme.background
  property color mutedColor: Theme.muted
  property color textColor: Theme.foreground
  property color upColor: Theme.ansiFallback("green")
  property color downColor: Theme.urgent
  property string fontFamily: "monospace"

  function toneColor(tone) {
    if (tone === "up") return root.upColor
    if (tone === "down") return root.downColor
    return root.mutedColor
  }

  Row {
    id: row
    anchors.fill: parent
    spacing: Theme.space(16)

    Repeater {
      model: root.cards

      Item {
        required property var modelData
        required property int index

        width: Math.max(1, (row.width - row.spacing * 3) / 4)
        height: row.height

        Fieldset {
          anchors.fill: parent
          legend: modelData.label
          number: 0
          borderColor: root.borderColor
          legendColor: root.mutedColor
          backgroundColor: root.backgroundColor
          mutedColor: root.mutedColor
          fontFamily: root.fontFamily

          Text {
            id: valueText
            anchors.left: parent.left
            anchors.top: parent.top
            width: Math.max(1, parent.width - deltaText.implicitWidth - Theme.space(4))
            textFormat: Text.PlainText
            text: modelData.value
            color: root.textColor
            font.family: root.fontFamily
            font.pixelSize: Theme.font.heading
            font.bold: true
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: Theme.font.body
            elide: Text.ElideRight
          }

          Text {
            id: deltaText
            anchors.right: parent.right
            anchors.verticalCenter: valueText.verticalCenter
            visible: modelData.delta !== ""
            textFormat: Text.PlainText
            text: modelData.delta
            color: root.toneColor(modelData.tone)
            font.family: root.fontFamily
            font.pixelSize: Theme.font.caption
            font.bold: true
          }

          Sparkline {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: valueText.bottom
            anchors.bottom: parent.bottom
            anchors.topMargin: Theme.space(4)
            points: modelData.spark || []
            strokeColor: root.upColor
          }
        }
      }
    }
  }
}
