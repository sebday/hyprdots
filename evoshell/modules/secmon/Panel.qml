import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.commons
import qs.ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "evo.secmon"
  ipcTarget: "evo.secmon"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: bar && bar.barForeground ? bar.barForeground : Theme.foreground
  readonly property color urgent: bar ? bar.urgent : Theme.urgent
  readonly property color accent: Theme.accent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Theme.font.family

  readonly property string statusScript: Qt.resolvedUrl("bin/secmon-status").toString().replace("file://", "")
  readonly property string host: String(setting("host", "zotac"))
  readonly property int backgroundPollMs: Math.max(60, parseInt(setting("refreshIntervalSec", 300), 10) || 300) * 1000
  readonly property int openPollMs: 60000
  readonly property int maxRows: 12

  readonly property string glyphOk: String.fromCodePoint(0xF0565)
  readonly property string glyphAlert: String.fromCodePoint(0xF0ECC)
  readonly property string glyphUnknown: String.fromCodePoint(0xF0499)

  property bool loading: true
  property var data: Model.emptyData()

  readonly property bool hasData: !!(data && data.generatedAt)
  readonly property bool stale: Model.isStale(data)
  readonly property bool iconError: hasData && (Model.alarming(data) || Model.unhealthyTargets(data).length > 0)
  readonly property bool iconMuted: !hasData || stale
  readonly property string iconGlyph: !hasData || stale ? glyphUnknown : (Model.issueCount(data) > 0 && Model.rank(Model.worst(data)) >= Model.rank("medium") ? glyphAlert : glyphOk)
  readonly property string barTooltip: Model.barTooltip(data, loading)
  readonly property var displayFindings: Model.openFindings(data).slice(0, maxRows)
  readonly property string findingsFooter: Model.findingsFooter(data, displayFindings.length)
  readonly property int openCount: Model.openCount(data)
  readonly property var displayTargets: Array.isArray(data.targets) ? data.targets : []
  readonly property var appsTarget: Model.appsBox(data)
  readonly property int statCount: displayTargets.length + (appsTarget ? 1 : 0)
  readonly property var changedTargets: Model.changedTargets(data)
  readonly property int changeCount: Model.changeCount(data)
  readonly property string glyphAccept: String.fromCodePoint(0xF012C)
  property bool acceptArmed: false
  property string acceptError: ""

  function severityColor(sev) {
    switch (String(sev || "")) {
    case "critical":
    case "high":
      return root.urgent
    case "medium":
      return Theme.mixColors(root.urgent, root.foreground, 0.45)
    case "low":
      return root.foreground
    default:
      return root.dim
    }
  }

  function applyPayload(raw) {
    data = Model.merge(data, Model.parsePayload(raw))
    loading = false
  }

  function refresh() {
    if (!statusScript || statusProc.running) return
    statusProc.command = ["bash", statusScript, "status", root.host]
    statusProc.running = true
  }

  // First click arms, second click accepts, so a stray click can't bless a real change.
  function acceptChanges() {
    if (acceptProc.running || !root.changedTargets.length) return
    if (!root.acceptArmed) {
      root.acceptArmed = true
      acceptDisarm.restart()
      return
    }
    root.acceptArmed = false
    root.acceptError = ""
    acceptProc.command = ["bash", statusScript, "accept", root.host].concat(root.changedTargets)
    acceptProc.running = true
  }

  function openReport(target) {
    Quickshell.execDetached(["xdg-open", Model.targetAnchor(root.data.reportUrl, target)])
    root.close()
  }

  function openFromHotkey() {
    root.controller.show()
    root.refresh()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  Component.onCompleted: {
    cacheProc.command = ["bash", statusScript, "cache"]
    cacheProc.running = true
    refresh()
  }

  onOpenedChanged: {
    if (opened) {
      refresh()
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    } else {
      acceptArmed = false
    }
  }

  Process {
    id: cacheProc
    property string stdoutBuf: ""
    onStarted: stdoutBuf = ""
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) { cacheProc.stdoutBuf += chunk }
    }
    onExited: {
      var raw = String(stdoutBuf || "").trim()
      if (raw && !root.hasData) root.applyPayload(raw)
    }
  }

  Process {
    id: statusProc
    property string stdoutBuf: ""
    onStarted: stdoutBuf = ""
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        statusProc.stdoutBuf += chunk
        if (statusProc.stdoutBuf.length > 262144) {
          statusProc.signal(15)
          statusProc.stdoutBuf = ""
        }
      }
    }
    onExited: {
      var raw = String(stdoutBuf || "").trim()
      if (raw) root.applyPayload(raw)
      else root.loading = false
    }
  }

  Process {
    id: acceptProc
    property string stdoutBuf: ""
    onStarted: stdoutBuf = ""
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) { acceptProc.stdoutBuf += chunk }
    }
    onExited: {
      var res = Model.parsePayload(stdoutBuf)
      root.acceptError = res.ok ? "" : res.error
      root.refresh()
    }
  }

  Timer {
    id: acceptDisarm
    interval: 4000
    onTriggered: root.acceptArmed = false
  }
  Timer {
    interval: root.opened ? root.openPollMs : root.backgroundPollMs
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Theme.space(420))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Theme.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Theme.space(12)

          MouseArea {
            width: parent.width
            height: hero.implicitHeight
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openReport("")

            PanelHero {
              id: hero
              width: parent.width
              title: "Security"
              meta: Model.heroMeta(root.data, root.loading)
              foreground: root.foreground
              fontFamily: root.fontFamily
              iconOpacity: root.iconMuted ? 0.5 : 1

              iconComponent: Component {
                Text {
                  textFormat: Text.PlainText
                  text: root.iconGlyph
                  color: root.iconError ? root.urgent : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Theme.font.display
                  opacity: 0.92
                }
              }

              trailingControl: Component {
                Row {
                  spacing: Theme.space(8)

                  Item {
                    visible: root.hasData && (root.changeCount > 0 || acceptProc.running)
                    width: visible ? acceptButton.width : 0
                    height: countBadge.height

                    HeaderIconButton {
                      id: acceptButton
                      anchors.verticalCenter: parent.verticalCenter
                      icon: root.glyphAccept
                      tooltip: acceptProc.running
                        ? "Accepting changes…"
                        : (root.acceptArmed
                          ? "Click again to accept " + root.changeCount + " change" + (root.changeCount === 1 ? "" : "s") + " on " + root.changedTargets.join(", ")
                          : "Accept baseline changes (" + root.changeCount + ")")
                      iconColor: root.acceptArmed ? root.urgent : root.dim
                      hoverColor: root.acceptArmed ? root.urgent : root.accent
                      onClicked: root.acceptChanges()
                    }
                  }

                  CountBadge {
                    id: countBadge
                    visible: root.hasData
                    value: root.openCount
                    fillColor: root.openCount > 0 ? root.severityColor(Model.worst(root.data)) : root.accent
                  }
                }
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            visible: text !== ""
            text: root.acceptError
              ? root.acceptError
              : (root.data.error ? root.data.error + (root.hasData ? " · showing the last result" : "") : "")
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Theme.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Row {
            visible: root.displayTargets.length > 0
            width: parent.width
            spacing: Theme.space(12)

            Repeater {
              model: root.displayTargets

              TargetTile {
                required property var modelData
                width: (column.width - Theme.space(12) * (root.statCount - 1)) / Math.max(1, root.statCount)
                target: modelData
              }
            }

            TargetTile {
              visible: !!root.appsTarget
              width: visible ? (column.width - Theme.space(12) * (root.statCount - 1)) / Math.max(1, root.statCount) : 0
              target: root.appsTarget
            }
          }

          Fieldset {
            visible: root.hasData
            width: parent.width
            legend: root.displayFindings.length ? "open" : ""
            contentHeight: findingsColumn.implicitHeight

            Column {
              id: findingsColumn
              width: parent.width
              spacing: Theme.space(8)

              Text {
                textFormat: Text.PlainText
                visible: root.displayFindings.length === 0
                width: parent.width
                text: Model.issueCount(root.data) > 0
                  ? "Nothing above low severity."
                  : "Nothing open. Checks run every 15 minutes on " + root.host + "."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Theme.font.body
                wrapMode: Text.WordWrap
              }

              Repeater {
                model: root.displayFindings

                FindingRow {
                  required property var modelData
                  width: findingsColumn.width
                  finding: modelData
                }
              }

              Text {
                textFormat: Text.PlainText
                visible: text !== ""
                width: parent.width
                text: root.findingsFooter
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Theme.font.caption
                font.bold: true
              }
            }
          }
        }
      }
    }
  }

  component Fieldset: Item {
    id: fieldset
    property string legend: ""
    property real contentHeight: 0
    default property alias contentData: body.data

    implicitHeight: contentHeight + Theme.space(32) + (legendChip.visible ? legendChip.height / 2 : 0)

    Rectangle {
      id: frame
      anchors.fill: parent
      anchors.topMargin: legendChip.visible ? legendChip.height / 2 : 0
      color: "transparent"
      radius: Theme.space(8)
      border.width: 1
      border.color: Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.9)
      antialiasing: true
    }

    Item {
      id: legendChip
      x: Theme.space(14)
      width: legendText.implicitWidth + Theme.space(8)
      height: Math.max(1, legendText.implicitHeight)
      visible: fieldset.legend !== ""

      Rectangle {
        anchors.fill: parent
        color: Theme.popups.background
      }

      Text {
        id: legendText
        x: Theme.space(4)
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: fieldset.legend
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Theme.font.caption
        font.bold: true
      }
    }

    Item {
      id: body
      anchors.left: frame.left
      anchors.right: frame.right
      anchors.top: frame.top
      anchors.leftMargin: Theme.space(12)
      anchors.rightMargin: Theme.space(12)
      anchors.topMargin: Theme.space(16)
      height: fieldset.contentHeight
    }
  }

  component HeaderIconButton: MouseArea {
    property string icon: ""
    property string tooltip: ""
    property color iconColor: root.dim
    property color hoverColor: root.accent

    width: iconText.implicitWidth + Theme.space(10)
    height: iconText.implicitHeight + Theme.space(6)
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    Text {
      id: iconText
      textFormat: Text.PlainText
      anchors.centerIn: parent
      text: parent.icon
      color: parent.containsMouse ? parent.hoverColor : parent.iconColor
      font.family: root.fontFamily
      font.pixelSize: Theme.font.body
    }

    PanelToolTip {
      visible: parent.containsMouse
      text: parent.tooltip
      fontFamily: root.fontFamily
    }
  }

  component CountBadge: Rectangle {
    property int value: 0
    property color fillColor: root.accent

    implicitWidth: countText.implicitWidth + Theme.spacing.lg * 2
    implicitHeight: countText.implicitHeight + Theme.spacing.sm * 2
    radius: implicitHeight / 2
    color: Qt.rgba(fillColor.r, fillColor.g, fillColor.b, 0.14)

    Text {
      id: countText
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: String(parent.value)
      color: parent.fillColor
      font.family: root.fontFamily
      font.pixelSize: Theme.font.displayLarge
      font.bold: true
    }
  }

  component FindingRow: Item {
    id: findingRow
    property var finding: null
    readonly property color sevColor: root.severityColor(finding ? finding.severity : "")

    implicitHeight: findingDetails.implicitHeight

    Rectangle {
      id: sevBar
      width: Theme.space(3)
      height: parent.height
      radius: width / 2
      color: findingRow.sevColor
    }

    Column {
      id: findingDetails
      anchors.left: sevBar.right
      anchors.leftMargin: Theme.spacing.sm
      anchors.right: parent.right
      spacing: Theme.spacing.labelGap

      Text {
        textFormat: Text.PlainText
        width: parent.width
        text: Model.plain(findingRow.finding && findingRow.finding.title, 200)
        color: findingMouse.containsMouse ? root.accent : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Theme.font.body
        elide: Text.ElideRight
      }

      Text {
        textFormat: Text.PlainText
        width: parent.width
        text: String(findingRow.finding ? findingRow.finding.severity : "").toUpperCase() + " · " + Model.findingMeta(findingRow.finding)
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Theme.font.caption
        elide: Text.ElideRight
      }
    }

    MouseArea {
      id: findingMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.openReport(findingRow.finding ? findingRow.finding.target : "")
    }
  }

  component TargetTile: Item {
    id: tile
    property var target: null
    readonly property bool down: Model.targetUnhealthy(target)
    readonly property int openCount: Number(target && target.open) || 0
    readonly property color valueColor: down ? root.urgent : (openCount > 0 ? root.severityColor(target.worst) : root.accent)

    implicitHeight: Theme.font.heading + Theme.space(56)

    Rectangle {
      id: tileFrame
      anchors.fill: parent
      anchors.topMargin: tileLegend.height / 2
      color: tileMouse.containsMouse ? Theme.withOpacity(root.foreground, 0.06) : "transparent"
      radius: Theme.space(8)
      border.width: 1
      border.color: Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.9)
      antialiasing: true
    }

    Item {
      id: tileLegend
      x: Theme.space(10)
      width: tileLegendText.implicitWidth + Theme.space(8)
      height: Math.max(1, tileLegendText.implicitHeight)

      Rectangle {
        anchors.fill: parent
        color: Theme.popups.background
      }

      Text {
        id: tileLegendText
        x: Theme.space(4)
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: Model.targetLabel(tile.target && tile.target.name)
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Theme.font.caption
        font.bold: true
      }
    }

    Text {
      anchors.fill: tileFrame
      anchors.leftMargin: Theme.space(6)
      anchors.rightMargin: Theme.space(6)
      textFormat: Text.PlainText
      text: tile.down ? "!" : String(tile.openCount)
      color: tile.valueColor
      font.family: root.fontFamily
      font.pixelSize: Theme.font.display
      font.bold: true
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
      fontSizeMode: Text.HorizontalFit
      minimumPixelSize: Theme.font.body
    }

    MouseArea {
      id: tileMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.openReport(tile.target && tile.target.report ? tile.target.report : (tile.target ? tile.target.name : ""))
    }

    PanelToolTip {
      visible: tileMouse.containsMouse
      text: tile.target && tile.target.hint
        ? String(tile.target.hint)
        : (tile.down
          ? "Can't collect: " + Model.plain(tile.target && tile.target.error, 160)
          : (tile.target && tile.target.lastSuccess ? "Last collected " + Model.formatAgo(tile.target.lastSuccess) : "Never collected"))
      fontFamily: root.fontFamily
    }
  }
}
