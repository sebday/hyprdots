import QtQuick
import qs.commons
import "../Model.js" as Model

Item {
  id: root

  property var payload: null
  property string metric: "revenue"
  property color borderColor: Theme.accent
  property color backgroundColor: Theme.background
  property color mutedColor: Theme.muted
  property color textColor: Theme.foreground
  property color brightColor: Theme.foreground
  property color warnColor: Theme.urgent
  property string fontFamily: "monospace"

  signal metricChosen(string id)

  readonly property var safePayload: Model.asPayload(payload)
  readonly property bool payloadOk: safePayload.ok === true
  readonly property var cells: Model.kpiCells(safePayload, metric)
  readonly property var chartBars: Model.barsFor(safePayload, metric)
  readonly property var compareBars: Model.compareBarsFor(safePayload, metric)
  readonly property string chartFigure: Model.chartFigure(safePayload, metric)
  readonly property string chartCompare: Model.chartCompare(safePayload, metric)
  readonly property var chartChange: Model.chartChange(safePayload, metric)
  readonly property string chartStyle: Model.metricById(metric).chartStyle
  readonly property var channels: Model.channelCards(safePayload)
  readonly property real channelTotal: channels.total
  readonly property int kpiHeight: root.channelHeight * 2 + Theme.space(16)
  readonly property int channelHeight: Theme.font.heading + Theme.space(56)

  Item {
    id: kpiBox
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: root.kpiHeight

    Text {
      anchors.fill: parent
      visible: !root.payloadOk
      textFormat: Text.PlainText
      text: root.safePayload.error || "No data"
      wrapMode: Text.WordWrap
      color: root.warnColor
      font.family: root.fontFamily
      font.pixelSize: Theme.font.body
    }

    KpiGrid {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.top: parent.top
      visible: root.payloadOk
      cells: root.cells
      accent: root.borderColor
      backgroundColor: root.backgroundColor
      mutedColor: root.mutedColor
      textColor: root.textColor
      downColor: root.warnColor
      fontFamily: root.fontFamily
      onChosen: function(id) { root.metricChosen(id) }
    }
  }

  ChannelStats {
    id: channelBox
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: root.channelTotal > 0 ? root.channelHeight : 0
    visible: root.channelTotal > 0
    cards: root.channels.cards
    borderColor: root.borderColor
    backgroundColor: root.backgroundColor
    mutedColor: root.mutedColor
    textColor: root.textColor
    upColor: root.borderColor
    downColor: root.warnColor
    fontFamily: root.fontFamily
  }

  Fieldset {
    anchors.top: kpiBox.bottom
    anchors.topMargin: Theme.space(16)
    anchors.bottom: parent.bottom
    anchors.bottomMargin: channelBox.visible ? channelBox.height + Theme.space(16) : 0
    anchors.left: parent.left
    anchors.right: parent.right
    number: 2
    legend: Model.chartTitle(root.safePayload, root.metric)
    borderColor: root.borderColor
    backgroundColor: root.backgroundColor
    mutedColor: root.mutedColor
    fontFamily: root.fontFamily

    Item {
      id: chartHead
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: chartValue.implicitHeight
      visible: root.chartFigure !== ""
      readonly property int gap: Theme.space(6)
      readonly property bool showCompare: root.chartCompare !== ""
          && chartValue.implicitWidth + gap + chartCompare.implicitWidth
             + (chartDelta.text !== "" ? gap + chartDelta.implicitWidth : 0) <= width

      Text {
        id: chartValue
        anchors.left: parent.left
        anchors.top: parent.top
        textFormat: Text.PlainText
        text: root.chartFigure
        color: root.textColor
        font.family: root.fontFamily
        font.pixelSize: Theme.font.display
        font.bold: true
      }

      Text {
        id: chartCompare
        anchors.left: chartValue.right
        anchors.leftMargin: chartHead.gap
        anchors.baseline: chartValue.baseline
        visible: chartHead.showCompare
        textFormat: Text.PlainText
        text: root.chartCompare
        color: root.mutedColor
        font.family: root.fontFamily
        font.pixelSize: Theme.font.body
      }

      Text {
        id: chartDelta
        anchors.left: chartHead.showCompare ? chartCompare.right : chartValue.right
        anchors.leftMargin: chartHead.gap
        anchors.baseline: chartHead.showCompare ? chartCompare.baseline : chartValue.baseline
        visible: text !== ""
        textFormat: Text.PlainText
        text: root.chartChange.text || ""
        color: root.chartChange.tone === "down" ? root.warnColor : root.borderColor
        font.family: root.fontFamily
        font.pixelSize: Theme.font.caption
        font.bold: true
      }
    }

    Text {
      anchors.centerIn: parent
      visible: !root.chartBars || root.chartBars.length === 0
      textFormat: Text.PlainText
      text: "no data"
      color: root.mutedColor
      font.family: root.fontFamily
      font.pixelSize: Theme.font.body
    }

    DotChart {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.top: chartHead.visible ? chartHead.bottom : parent.top
      anchors.topMargin: chartHead.visible ? Theme.space(6) : 0
      visible: root.chartBars && root.chartBars.length > 0
      bars: root.chartBars
      compareBars: root.compareBars
      chartStyle: root.chartStyle
      accent: root.borderColor
      bright: root.brightColor
      muted: root.mutedColor
    }
  }
}
