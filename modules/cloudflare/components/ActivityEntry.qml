import QtQuick
import QtQuick.Layouts
import qs.commons
import qs.ui

Item {
  id: root

  required property var row
  property var host: null
  property bool showDivider: true

  readonly property color foreground: host ? host.foreground : Theme.foreground
  readonly property color urgent: host ? host.urgent : Theme.urgent
  readonly property color accent: host ? host.accent : Theme.accent
  readonly property string fontFamily: host ? host.fontFamily : Theme.font.family
  readonly property string glyph: host ? host.rowGlyph(row) : ""
  readonly property string titleText: host ? host.rowTitle(row) : ""
  readonly property string statusText: host ? host.activityStatusLabel(row) : ""
  readonly property string timeText: host ? host.activityTimeLabel(row) : ""
  readonly property color statusColor: host ? host.activityStatusColor(row) : accent
  readonly property bool clickable: host ? host.rowClickable(row) : false

  implicitWidth: parent ? parent.width : 0
  implicitHeight: entryRow.implicitHeight + Theme.spacing.lg + (showDivider ? 1 : 0)

  RowLayout {
    id: entryRow
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: Theme.spacing.sm
    spacing: Theme.spacing.md

    Item {
      Layout.preferredWidth: 34
      Layout.preferredHeight: 34
      Layout.alignment: Qt.AlignVCenter
      visible: root.glyph !== ""

      Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Qt.rgba(
          root.statusColor.r,
          root.statusColor.g,
          root.statusColor.b,
          0.14
        )
      }

      Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent
        text: root.glyph
        color: root.statusColor
        font.family: root.fontFamily
        font.pixelSize: Theme.font.title
        font.bold: true
      }
    }

    Text {
      textFormat: Text.PlainText
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      text: root.titleText
      color: row && row.alarming ? root.urgent : root.foreground
      font.family: root.fontFamily
      font.pixelSize: Theme.font.body
      font.bold: true
      elide: Text.ElideRight
      maximumLineCount: 1
    }

    MetaPill {
      Layout.alignment: Qt.AlignVCenter
      visible: root.statusText !== ""
      text: root.statusText
      active: true
      fillColor: Qt.rgba(
        root.statusColor.r,
        root.statusColor.g,
        root.statusColor.b,
        0.16
      )
      textColor: root.statusColor
    }

    MetaPill {
      Layout.alignment: Qt.AlignVCenter
      visible: root.timeText !== ""
      text: root.timeText
      active: false
      fillColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
      textColor: root.foreground
      textOpacity: 0.65
    }
  }

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    visible: showDivider
    height: 1
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.clickable
    hoverEnabled: enabled
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: {
      if (host)
        host.openRow(row)
    }
  }

  component MetaPill: BorderSurface {
    property string text: ""
    property bool active: false
    property color fillColor: Theme.popups.background
    property color textColor: Theme.foreground
    property real textOpacity: 1

    implicitWidth: pillText.implicitWidth + Theme.spacing.md * 2
    implicitHeight: pillText.implicitHeight + Theme.spacing.sm * 2
    color: fillColor
    borderSpec: Border.surfaceSpec("popups", "border", Theme.popups.border, active ? 1 : 0)
    radius: Theme.cornerRadius

    Text {
      textFormat: Text.PlainText
      id: pillText
      anchors.centerIn: parent
      text: parent.text
      color: parent.textColor
      opacity: parent.textOpacity
      font.family: root.fontFamily
      font.pixelSize: Theme.font.caption
      font.bold: true
    }
  }
}
