import QtQuick
import qs.commons

Item {
  id: root

  property var cells: []
  property color accent: Theme.accent
  property color backgroundColor: Theme.background
  property color mutedColor: Theme.muted
  property color textColor: Theme.foreground
  property color downColor: Theme.urgent
  property string fontFamily: "monospace"

  signal chosen(string id)

  function toneColor(tone) {
    if (tone === "down") return root.downColor
    return root.accent
  }

  function cellsForRow(row) {
    var all = root.cells || []
    var top = 4
    var start = row === 0 ? 0 : top
    var end = row === 0 ? Math.min(top, all.length) : all.length
    var out = []
    for (var i = start; i < end; i++) out.push(all[i])
    return out
  }

  Column {
    id: stack
    anchors.fill: parent
    spacing: Theme.space(16)

    Repeater {
      model: 2

      Row {
        required property int index

        readonly property var rowCells: root.cellsForRow(index)

        width: stack.width
        height: Math.max(1, (stack.height - stack.spacing) / 2)
        spacing: Theme.space(16)

        Repeater {
          model: parent.rowCells

          Item {
            required property var modelData

            width: {
              var count = parent.rowCells ? parent.rowCells.length : 1
              var gaps = parent.spacing * Math.max(0, count - 1)
              return Math.max(1, Math.floor((parent.width - gaps) / Math.max(1, count)))
            }
            height: parent.height

            Fieldset {
              anchors.fill: parent
              legend: modelData.label
              number: 0
              borderColor: modelData.selected ? root.accent : root.mutedColor
              backgroundColor: root.backgroundColor
              mutedColor: root.mutedColor
              fontFamily: root.fontFamily

              Text {
                id: valueText
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.right: deltaText.left
                anchors.rightMargin: Theme.space(2)
                textFormat: Text.PlainText
                text: modelData.value
                color: root.textColor
                font.family: root.fontFamily
                font.pixelSize: Theme.font.heading
                font.bold: true
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
                anchors.topMargin: Theme.space(2)
                visible: modelData.spark && modelData.spark.length > 1
                points: modelData.spark || []
                strokeColor: root.accent
              }
            }

            MouseArea {
              anchors.fill: parent
              enabled: modelData.clickable === true
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: root.chosen(modelData.id)
            }
          }
        }
      }
    }
  }
}
