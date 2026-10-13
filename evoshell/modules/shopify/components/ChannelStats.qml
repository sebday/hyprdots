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

          Item {
            id: figureRow
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.right: parent.right
            height: valueText.implicitHeight
            readonly property int gap: Theme.space(4)
            readonly property bool showCompare: compareText.text !== ""
                && valueText.implicitWidth + gap + compareText.implicitWidth
                   + (deltaText.text !== "" ? gap + deltaText.implicitWidth : 0) <= width

            Text {
              id: valueText
              anchors.left: parent.left
              anchors.top: parent.top
              textFormat: Text.PlainText
              text: modelData.value
              color: root.textColor
              font.family: root.fontFamily
              font.pixelSize: Theme.font.heading
              font.bold: true
            }

            Text {
              id: compareText
              anchors.left: valueText.right
              anchors.leftMargin: figureRow.gap
              anchors.baseline: valueText.baseline
              visible: figureRow.showCompare
              textFormat: Text.PlainText
              text: modelData.compare || ""
              color: root.mutedColor
              font.family: root.fontFamily
              font.pixelSize: Theme.font.caption
            }

            Text {
              id: deltaText
              anchors.right: parent.right
              anchors.verticalCenter: valueText.verticalCenter
              visible: text !== ""
              textFormat: Text.PlainText
              text: modelData.delta
              color: root.toneColor(modelData.tone)
              font.family: root.fontFamily
              font.pixelSize: Theme.font.caption
              font.bold: true
            }
          }

          Sparkline {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: figureRow.bottom
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
