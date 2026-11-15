import QtQuick
import qs.commons
import "../Model.js" as Model

// Same control as the dashboard: a preset list and a calendar.
// The first day click starts a range, the second completes it.
Item {
  id: root

  property string preset: "last30Days"
  property string from: ""
  property string to: ""
  property bool open: false
  property color surfaceColor: Theme.mantle
  property color fillColor: Theme.background
  property color lineColor: Theme.foregroundDivider
  property color textColor: Theme.foreground
  property color mutedColor: Theme.muted
  property color accentColor: Theme.accent
  property string fontFamily: "monospace"

  signal chosen(string preset, string from, string to)

  readonly property string today: Model.isoToday()
  readonly property int presetWidth: presetMetrics.advanceWidth("Last 30 days") + Theme.space(22)

  FontMetrics {
    id: presetMetrics
    font.family: root.fontFamily
    font.pixelSize: Theme.font.body
    font.bold: true
  }
  readonly property var shown: preset ? Model.rangeForPreset(preset, today) : ({ from: from, to: to })
  readonly property string label: Model.rangeButtonLabel(preset, shown.from, shown.to)
  property string pending: ""
  property string calMonth: ""

  implicitWidth: trigger.implicitWidth
  implicitHeight: trigger.implicitHeight

  function toggle() {
    if (root.open) {
      root.open = false
      return
    }
    root.pending = ""
    root.calMonth = Model.startOfMonth(root.shown.to || root.today)
    root.open = true
  }

  function shiftMonth(delta) {
    var next = Model.addMonths(Model.startOfMonth(root.calMonth), delta)
    if (!next || next > Model.startOfMonth(root.today)) return
    root.calMonth = next
  }

  function pickPreset(kind) {
    var range = Model.rangeForPreset(kind, root.today)
    root.pending = ""
    root.open = false
    root.chosen(kind, range.from, range.to)
  }

  function pickDay(date) {
    var a = root.pending
    var b = date
    var swap = ""
    if (!a) {
      root.pending = date
      return
    }
    if (a > b) {
      swap = a
      a = b
      b = swap
    }
    root.pending = ""
    root.open = false
    root.chosen("", a, b)
  }

  Rectangle {
    id: trigger
    radius: Theme.space(8)
    color: triggerHover.hovered ? Theme.mixColors(root.fillColor, root.textColor, 0.06) : root.fillColor
    border.width: 1
    border.color: root.open ? root.accentColor : root.lineColor

    Row {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Theme.space(12)
      anchors.rightMargin: Theme.space(12)
      spacing: Theme.space(8)

      Text {
        textFormat: Text.PlainText
        text: root.label
        color: root.textColor
        font.family: root.fontFamily
        font.pixelSize: Theme.font.body
        font.bold: true
      }

      Text {
        textFormat: Text.PlainText
        text: "▾"
        color: root.mutedColor
        font.family: root.fontFamily
        font.pixelSize: Theme.font.body
      }
    }

    implicitWidth: triggerLabel.implicitWidth
    implicitHeight: Theme.space(32)

    Text {
      id: triggerLabel
      visible: false
      textFormat: Text.PlainText
      text: root.label + "  ▾"
      font.family: root.fontFamily
      font.pixelSize: Theme.font.body
      font.bold: true
      leftPadding: Theme.space(12)
      rightPadding: Theme.space(12)
    }

    HoverHandler { id: triggerHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: root.toggle() }
  }

  Rectangle {
    id: popup
    visible: root.open
    z: 2
    anchors.right: parent.right
    y: trigger.height + Theme.space(6)
    radius: Theme.space(8)
    color: root.surfaceColor
    border.width: 1
    border.color: root.lineColor
    width: presetWell.width + Theme.space(12) + calendar.width + Theme.space(12) * 2
    height: Math.max(presetWell.height, calendar.height) + Theme.space(12) * 2

    Rectangle {
      id: presetWell
      x: Theme.space(12)
      y: Theme.space(12)
      width: presetCol.implicitWidth + Theme.space(6)
      height: presetCol.implicitHeight + Theme.space(6)
      radius: Theme.space(8)
      color: root.fillColor
      border.width: 1
      border.color: root.lineColor

      Column {
        id: presetCol
        x: Theme.space(3)
        y: Theme.space(3)
        spacing: Theme.space(2)

        Repeater {
          model: Model.RANGE_PRESETS

          Rectangle {
            required property var modelData
            readonly property bool active: modelData.kind === root.preset && root.pending === ""
            width: root.presetWidth
            height: presetText.implicitHeight + Theme.space(9)
            radius: Theme.space(6)
            color: active ? root.surfaceColor : (presetHover.hovered ? Theme.mixColors(root.fillColor, root.textColor, 0.05) : "transparent")

            Text {
              id: presetText
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: modelData.label
              color: active || presetHover.hovered ? root.textColor : root.mutedColor
              font.family: root.fontFamily
              font.pixelSize: Theme.font.body
              font.bold: active
            }

            HoverHandler { id: presetHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.pickPreset(modelData.kind) }
          }
        }
      }
    }

    Column {
      id: calendar
      x: presetWell.x + presetWell.width + Theme.space(12)
      y: Theme.space(12)
      width: Theme.space(32) * 7 + Theme.space(2) * 6
      spacing: Theme.space(4)

      Row {
        width: parent.width
        height: navTitle.implicitHeight

        Text {
          id: prevMonth
          width: Theme.space(28)
          height: parent.height
          textFormat: Text.PlainText
          text: "‹"
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          color: prevHover.hovered ? root.textColor : root.mutedColor
          font.family: root.fontFamily
          font.pixelSize: Theme.font.heading
          font.bold: true

          HoverHandler { id: prevHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: root.shiftMonth(-1) }
        }

        Column {
          id: navTitle
          width: parent.width - Theme.space(56)
          spacing: 1

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: Model.monthTitle(root.calMonth)
            horizontalAlignment: Text.AlignHCenter
            color: root.textColor
            font.family: root.fontFamily
            font.pixelSize: Theme.font.body
            font.bold: true
          }

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: root.pending ? Model.formatDayLong(root.pending) + " –" : Model.rangeButtonLabel("", root.shown.from, root.shown.to)
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            color: root.mutedColor
            font.family: root.fontFamily
            font.pixelSize: Theme.font.caption
          }
        }

        Text {
          id: nextMonth
          readonly property bool blocked: {
            var next = Model.addMonths(Model.startOfMonth(root.calMonth), 1)
            return !next || next > Model.startOfMonth(root.today)
          }
          width: Theme.space(28)
          height: parent.height
          opacity: nextMonth.blocked ? 0.35 : 1
          textFormat: Text.PlainText
          text: "›"
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          color: !nextMonth.blocked && nextHover.hovered ? root.textColor : root.mutedColor
          font.family: root.fontFamily
          font.pixelSize: Theme.font.heading
          font.bold: true

          HoverHandler { id: nextHover; cursorShape: nextMonth.blocked ? Qt.ArrowCursor : Qt.PointingHandCursor }
          TapHandler { enabled: !nextMonth.blocked; onTapped: root.shiftMonth(1) }
        }
      }

      Row {
        width: parent.width
        spacing: Theme.space(2)

        Repeater {
          model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

          Text {
            required property string modelData
            width: Theme.space(32)
            textFormat: Text.PlainText
            text: modelData
            horizontalAlignment: Text.AlignHCenter
            color: root.mutedColor
            font.family: root.fontFamily
            font.pixelSize: Theme.font.caption
          }
        }
      }

      Grid {
        width: parent.width
        columns: 7
        columnSpacing: Theme.space(2)
        rowSpacing: Theme.space(2)

        Repeater {
          model: Model.calendarDays(root.calMonth, root.shown.from, root.shown.to, root.pending, root.today)

          Rectangle {
            required property var modelData
            width: Theme.space(32)
            height: Theme.space(32)
            radius: Theme.space(6)
            opacity: modelData.future ? 0.35 : 1
            color: {
              if (modelData.edge) return root.accentColor
              if (modelData.inRange) return Theme.withOpacity(root.accentColor, 0.28)
              if (dayHover.hovered && !modelData.future) return Theme.mixColors(root.surfaceColor, root.textColor, 0.06)
              return "transparent"
            }
            border.width: modelData.today && !modelData.edge ? 1 : 0
            border.color: root.accentColor

            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: modelData.label
              color: modelData.edge ? root.fillColor : (modelData.outside ? root.mutedColor : root.textColor)
              font.family: root.fontFamily
              font.pixelSize: Theme.font.bodySmall
              font.bold: modelData.edge || modelData.today
            }

            HoverHandler { id: dayHover; cursorShape: modelData.future ? Qt.ArrowCursor : Qt.PointingHandCursor }
            TapHandler {
              enabled: !modelData.future
              onTapped: root.pickDay(modelData.date)
            }
          }
        }
      }
    }
  }
}
