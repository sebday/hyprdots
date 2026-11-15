import QtQuick
import qs.commons
import "../Model.js" as Model

Item {
  id: root

  property string title: ""
  property int headerRight: 0
  property var payload: null
  property string metric: "revenue"
  property color storeColor: Theme.accent
  property color surfaceColor: Theme.mantle
  property color lineColor: Theme.foregroundDivider
  property color mutedColor: Theme.muted
  property color textColor: Theme.foreground
  property color upColor: Theme.ansiFallback("green")
  property color downColor: Theme.urgent
  property color infoColor: Theme.accent
  property color currentColor: Theme.accent
  property string fontFamily: "monospace"

  signal metricChosen(string id)

  readonly property var safePayload: Model.asPayload(payload)
  readonly property bool payloadOk: safePayload.ok === true
  readonly property var cells: Model.kpiCells(safePayload, metric)
  readonly property var channels: Model.channelCards(safePayload)
  readonly property var rows: {
    var out = []
    if (cells.length) out.push(cells.slice(0, 4), cells.slice(4, 8))
    if (channels.total > 0) out.push(channels.cards)
    return out
  }
  readonly property var chartBars: Model.barsFor(safePayload, metric)
  readonly property var compareBars: Model.compareBarsFor(safePayload, metric)
  readonly property var chartChange: Model.chartChange(safePayload, metric)
  readonly property var ranges: Model.chartRanges(safePayload, metric)

  readonly property int gap: Theme.space(12)
  readonly property int chartMin: Theme.space(220)
  readonly property int cardMax: Theme.space(124)
  readonly property int cardMin: Theme.space(84)
  readonly property int cardHeight: {
    var n = Math.max(1, rows.length)
    var room = height - header.height - gap - chartMin - gap * n
    return Math.max(cardMin, Math.min(cardMax, Math.floor(room / n)))
  }

  function toneColor(tone) {
    if (tone === "up") return root.upColor
    if (tone === "down") return root.downColor
    return root.mutedColor
  }

  Item {
    id: header
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: Theme.space(32)

    Rectangle {
      id: storeDot
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: Theme.space(10)
      height: width
      radius: width / 2
      color: root.storeColor
    }

    Text {
      id: storeTitle
      anchors.left: storeDot.right
      anchors.leftMargin: Theme.space(8)
      anchors.right: parent.right
      anchors.rightMargin: root.headerRight
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: root.title
      elide: Text.ElideRight
      color: root.textColor
      font.family: root.fontFamily
      font.pixelSize: Theme.font.heading
      font.bold: true
    }
  }

  Text {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: header.bottom
    anchors.topMargin: root.gap
    visible: !root.payloadOk
    textFormat: Text.PlainText
    text: root.safePayload.error || "No data"
    wrapMode: Text.WordWrap
    color: root.downColor
    font.family: root.fontFamily
    font.pixelSize: Theme.font.body
  }

  Column {
    id: cardRows
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: header.bottom
    anchors.topMargin: root.gap
    spacing: root.gap
    visible: root.payloadOk

    Repeater {
      model: root.rows

      Row {
        id: cardRow
        required property var modelData

        width: cardRows.width
        height: root.cardHeight
        spacing: root.gap

        Repeater {
          model: cardRow.modelData

          StatCard {
            required property var modelData

            width: Math.floor((cardRow.width - cardRow.spacing * 3) / 4)
            height: cardRow.height
            card: modelData
            surfaceColor: root.surfaceColor
            textColor: root.textColor
            mutedColor: root.mutedColor
            upColor: root.upColor
            downColor: root.downColor
            flatColor: root.infoColor
            priorColor: root.infoColor
            fontFamily: root.fontFamily
            onChosen: function(id) { root.metricChosen(id) }
          }
        }
      }
    }
  }

  Rectangle {
    id: chartPanel
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: cardRows.bottom
    anchors.topMargin: root.gap
    anchors.bottom: parent.bottom
    visible: root.payloadOk
    radius: Theme.space(8)
    color: root.surfaceColor
    border.width: 1
    border.color: root.lineColor

    readonly property int pad: Theme.space(16)

    Text {
      id: chartTitle
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.margins: chartPanel.pad
      textFormat: Text.PlainText
      text: Model.chartTitle(root.safePayload, root.metric)
      color: root.textColor
      font.family: root.fontFamily
      font.pixelSize: Theme.font.body
      font.bold: true
    }

    Row {
      id: legend
      anchors.right: parent.right
      anchors.rightMargin: chartPanel.pad
      anchors.verticalCenter: chartTitle.verticalCenter
      spacing: Theme.space(14)

      Repeater {
        model: [
          { color: root.currentColor, text: root.ranges.current },
          { color: root.infoColor, text: root.ranges.previous }
        ]

        Row {
          required property var modelData
          visible: modelData.text !== ""
          spacing: Theme.space(6)

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.space(8)
            height: width
            radius: 2
            color: modelData.color
          }

          Text {
            textFormat: Text.PlainText
            text: modelData.text
            color: root.mutedColor
            font.family: root.fontFamily
            font.pixelSize: Theme.font.caption
          }
        }
      }
    }

    Row {
      id: chartKpi
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: chartTitle.bottom
      anchors.leftMargin: chartPanel.pad
      anchors.rightMargin: chartPanel.pad
      anchors.topMargin: Theme.space(6)
      spacing: Theme.space(8)

      Text {
        id: chartValue
        textFormat: Text.PlainText
        text: Model.chartFigure(root.safePayload, root.metric)
        color: root.textColor
        font.family: root.fontFamily
        font.pixelSize: Math.round(Theme.font.heading * 1.5)
        font.bold: true
        font.letterSpacing: -0.5
      }

      Text {
        anchors.baseline: chartValue.baseline
        textFormat: Text.PlainText
        text: Model.chartCompare(root.safePayload, root.metric)
        color: root.mutedColor
        font.family: root.fontFamily
        font.pixelSize: Theme.font.caption
      }

      Text {
        anchors.baseline: chartValue.baseline
        visible: text !== ""
        textFormat: Text.PlainText
        text: root.chartChange.text || ""
        color: root.toneColor(root.chartChange.tone)
        font.family: root.fontFamily
        font.pixelSize: Theme.font.caption
        font.bold: true
      }
    }

    Text {
      anchors.centerIn: chart
      visible: !root.chartBars || root.chartBars.length === 0
      textFormat: Text.PlainText
      text: "no data"
      color: root.mutedColor
      font.family: root.fontFamily
      font.pixelSize: Theme.font.body
    }

    ComboChart {
      id: chart
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: chartKpi.bottom
      anchors.bottom: parent.bottom
      anchors.leftMargin: chartPanel.pad
      anchors.rightMargin: chartPanel.pad
      anchors.topMargin: Theme.space(10)
      anchors.bottomMargin: Theme.space(10)
      visible: root.chartBars && root.chartBars.length > 0
      bars: root.chartBars
      compareBars: root.compareBars
      metric: root.metric
      symbol: Model.currency(root.safePayload)
      fontFamily: root.fontFamily
      currentColor: root.currentColor
      priorColor: root.infoColor
      textColor: root.textColor
      mutedColor: root.mutedColor
      gridColor: root.lineColor
      surfaceColor: Theme.background
    }
  }
}
