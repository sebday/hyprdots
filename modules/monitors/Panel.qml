import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.ui
import qs.commons
import "LayoutModel.js" as LayoutModel
import "."

Panel {
  id: root
  moduleName: "evo.monitors"
  implicitWidth: Theme.bar.iconSlot
  implicitHeight: Theme.barHeight
  width: implicitWidth
  height: implicitHeight
  ipcTarget: "evo.monitors"
  manageIpc: false
  property var barPanel: null
  readonly property bool ownsIpc: bar && barPanel && barPanel.screen && typeof bar.screenOwnsIpc === "function"
      ? bar.screenOwnsIpc(String(barPanel.screen.name || ""))
      : false

  readonly property string focusedMonitor: Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name || "") : ""
  // The output last clicked in the layout picker; the hero label names it.
  property string selectedMonitor: ""
  property bool cursorActive: false
  property var layoutBarPlacements: []
  property var layoutNotificationsPlacements: []

  // Text size slider — curated notches (px). The panel snaps to these stops.
  // evo-layout writes uiBaseSize into $EVOSHELL_CONFIG/ui.json.
  readonly property var textSizeStops: [9, 10, 11, 12, 14, 16, 20]
  // While a change is in flight, the chosen stop index overrides the live
  // base-size so the knob doesn't snap back during the file round-trip. -1 =
  // no pending change; follow Theme.font.baseSize.
  property int textSizePreviewIndex: -1

  // A text-size change reflows the whole panel (both font and spacing scale),
  // which slides rows under a stationary pointer and fires synthetic hover.
  // While true, hover does not re-arm the keyboard cursor.
  property bool reflowingText: false
  function markReflowing() {
    root.reflowingText = true
    reflowSettle.restart()
  }

  IpcHandler {
    enabled: root.ownsIpc
    target: "evo.monitors"

    function open() { root.open() }
    function close() { root.close() }
    function toggle() { root.toggle() }
    function show() { root.open() }
    function hide() { root.close() }
  }

  readonly property var monitorService: bar && bar.shell ? bar.shell.serviceFor("evo.monitors") : null

  function liveBarConfig() {
    if (bar && bar.barConfig) return bar.barConfig
    if (bar && bar.shell && bar.shell.barConfig) return bar.shell.barConfig
    return {}
  }

  // The bar config is the live copy for both lists; the service's read of
  // shell.json covers notification placements written before they moved
  // under bar.
  function refreshLayoutState() {
    var barConfig = liveBarConfig()
    root.layoutBarPlacements = LayoutModel.readBarPlacements(barConfig)
    if (!Array.isArray(barConfig.notificationPlacements) && monitorService
        && Array.isArray(monitorService.notificationPlacements))
      root.layoutNotificationsPlacements = monitorService.notificationPlacements
    else
      root.layoutNotificationsPlacements = LayoutModel.readNotificationPlacements({ bar: barConfig })
  }

  Connections {
    target: bar
    function onBarConfigChanged() { root.refreshLayoutState() }
  }

  Connections {
    target: root.monitorService
    ignoreUnknownSignals: true
    function onNotificationPlacementsChanged() { root.refreshLayoutState() }
    function onUserShellConfigLoadedChanged() { root.refreshLayoutState() }
  }

  function mutateShellConfig(mutator) {
    if (!bar || !bar.shell || typeof bar.shell.mutateShellConfig !== "function") return
    bar.shell.mutateShellConfig(mutator)
  }

  function toggleBarLayout(output, position) {
    var next = LayoutModel.toggleBarPlacementForOutput(
      root.layoutBarPlacements, output, position)
    LayoutModel.applyBarPlacements(
      function(mutator) { root.mutateShellConfig(mutator) },
      next
    )
    root.layoutBarPlacements = next
  }

  function toggleNotificationsLayout(output, position, align) {
    var wasActive = LayoutModel.hasNotificationAlign(
      root.layoutNotificationsPlacements, output, position, align)
    var next = LayoutModel.toggleNotificationPlacement(
      root.layoutNotificationsPlacements, output, position, align)
    LayoutModel.applyNotificationsPlacements(
      function(mutator) { root.mutateShellConfig(mutator) },
      next
    )
    root.layoutNotificationsPlacements = next
    if (!wasActive)
      showNotificationsPlacementPreview(output, position, align)
  }

  // Clicking the monitor itself moves the one bar there and keeps
  // notifications on that same screen.
  function chooseMonitor(output) {
    var name = String(output || "")
    if (!name) return
    root.selectedMonitor = name

    var edge = "top"
    var bars = root.layoutBarPlacements
    if (bars && bars.length > 0 && bars[bars.length - 1] && bars[bars.length - 1].position)
      edge = bars[bars.length - 1].position

    var vertical = "top"
    var align = "right"
    var notes = root.layoutNotificationsPlacements
    if (notes && notes.length > 0 && notes[notes.length - 1]) {
      vertical = notes[notes.length - 1].position || vertical
      align = notes[notes.length - 1].align || align
    }

    var barNext = LayoutModel.toggleBarPlacementForOutput(bars, name, edge)
    var noteNext = LayoutModel.toggleNotificationPlacement(notes, name, vertical, align)
    root.mutateShellConfig(function(config) {
      LayoutModel.writeBarPlacements(config, barNext)
      LayoutModel.writeNotificationPlacements(config, noteNext)
    })
    root.layoutBarPlacements = barNext
    root.layoutNotificationsPlacements = noteNext
  }

  function resetLayoutDefaults() {
    var name = root.selectedMonitor || root.focusedMonitor
    var screens = Quickshell.screens || []
    var chosen = []
    for (var i = 0; i < screens.length; i++) {
      if (screens[i] && String(screens[i].name) === name) {
        chosen = [screens[i]]
        break
      }
    }
    if (chosen.length === 0 && screens.length > 0 && screens[0])
      chosen = [screens[0]]
    var layout = LayoutModel.resetDefaultLayout(
      function(mutator) { root.mutateShellConfig(mutator) },
      chosen
    )
    root.layoutBarPlacements = layout.barPlacements
    root.layoutNotificationsPlacements = layout.notificationsPlacements
  }

  function showNotificationsPlacementPreview(output, position, align) {
    var svc = root.monitorService
    if (!svc || typeof svc.showPlacementPreview !== "function") return
    var detail = String(output) + " · " + LayoutModel.normalizeVertical(position)
      + " · " + LayoutModel.normalizeAlign(align)
    Qt.callLater(function() { svc.showPlacementPreview("Notifications here", detail) })
  }

  // ---- Text size (shell base font + GTK text-scaling, via one CLI) ----
  function nearestTextStop(px) {
    var best = 0
    var bestDist = 1e9
    for (var i = 0; i < textSizeStops.length; i++) {
      var d = Math.abs(textSizeStops[i] - px)
      if (d < bestDist) { bestDist = d; best = i }
    }
    return best
  }

  // Effective stop index: the pending choice while a change is in flight,
  // otherwise whatever Style's live base-size rounds to.
  function currentTextIndex() {
    return textSizePreviewIndex >= 0 ? textSizePreviewIndex : nearestTextStop(Theme.font.baseSize)
  }

  // px shown in the header: the pending stop if any, else the true base-size
  // (which may be an off-notch value set from the CLI).
  function displayedTextPx() {
    return textSizePreviewIndex >= 0 ? textSizeStops[textSizePreviewIndex] : Theme.font.baseSize
  }

  function setTextSize(px) {
    textScaleProc.command = [
      "bash",
      Util.evoshellScript(Quickshell.env("HOME"), null, "evo-layout"),
      "ui", "set", "baseSize", String(px)
    ]
    if (!textScaleProc.running) textScaleProc.running = true
  }

  function adjustTextSize(deltaSteps) {
    var idx = currentTextIndex() + deltaSteps
    if (idx < 0) idx = 0
    if (idx > textSizeStops.length - 1) idx = textSizeStops.length - 1
    markReflowing()
    textSizePreviewIndex = idx
    setTextSize(textSizeStops[idx])
  }

  // KeyboardPanel primes focus at open-time, so SUPER-bound IPC summons land
  // with h/l ready on the slider. Don't paint the cursor until hover or the
  // first navigation key.
  onOpenedChanged: {
    if (opened) {
      refreshLayoutState()
      cursorActive = false
      selectedMonitor = ""
    }
  }

  // Writes uiBaseSize. Theme watches ui.json and picks up the new base size.
  Process { id: textScaleProc }

  // Clears the hover-suppression flag once the reflow triggered by a text-size
  // change has settled.
  Timer {
    id: reflowSettle
    interval: 300
    repeat: false
    onTriggered: root.reflowingText = false
  }

  // Once Style's base-size catches up to the pending choice, drop the preview
  // so the slider tracks the live value again. The change itself reflows the
  // panel, so suppress hover for a beat while it lands.
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Quickshell.screens.length > 1 ? "󰍺" : "󰍹"
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Theme.space(380))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Theme.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dx !== 0) root.adjustTextSize(dx)
      }
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        Binding {
          target: scrollArea.contentItem
          property: "interactive"
          value: panelColumn.implicitHeight > scrollArea.height
        }

        Column {
          id: panelColumn
          width: scrollArea.availableWidth
          spacing: Theme.space(14)

          // ---------- Hero: display icon · title/status ----------
          Item {
            width: parent.width
            implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

            Text {
              textFormat: Text.PlainText
              id: heroIcon
              text: Quickshell.screens.length > 1 ? "󰍺" : "󰍹"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Theme.font.display
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              id: heroLabels
              anchors.left: heroIcon.right
              anchors.leftMargin: Theme.space(14)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Theme.space(2)

              Text {
                textFormat: Text.PlainText
                text: "Display"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Theme.font.title
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                textFormat: Text.PlainText
                id: heroLabel
                text: {
                  var monitor = root.selectedMonitor || root.focusedMonitor
                  if (monitor) return monitor.toUpperCase()
                  return "DISPLAY"
                }
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Theme.font.caption
                font.bold: true
                font.letterSpacing: 1.2
                elide: Text.ElideRight
                width: parent.width
              }
            }
          }

          // ---------- Text size ----------
          PanelSeparator {
            foreground: root.bar.foreground
          }

          Column {
            width: parent.width
            spacing: Theme.space(6)

            Item {
              width: parent.width
              implicitHeight: Math.max(textSizeHeader.implicitHeight, textSizePx.implicitHeight)

              PanelSectionHeader {
                id: textSizeHeader
                text: "TEXT SIZE"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                textFormat: Text.PlainText
                id: textSizePx
                text: (textSizeSlider.dragging
                       ? root.textSizeStops[Math.round(textSizeSlider.liveValue)]
                       : root.displayedTextPx()) + "px"
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Theme.font.caption
                font.bold: true
                anchors.right: parent.right
                anchors.rightMargin: Theme.space(6)
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            CursorSurface {
              id: textSizeRow
              width: parent.width
              height: textSizeSlider.implicitHeight + Theme.spacing.controlGap
              hasCursor: root.cursorActive
              foreground: root.bar.foreground
              outline: true

              PanelSlider {
                id: textSizeSlider
                bar: root.bar
                anchors.fill: parent
                anchors.leftMargin: Theme.space(6)
                anchors.rightMargin: Theme.space(6)
                minimum: 0
                maximum: root.textSizeStops.length - 1
                step: 1
                integer: true
                tickCount: root.textSizeStops.length
                value: root.currentTextIndex()
                onReleased: function(v) { root.setTextSize(root.textSizeStops[Math.round(v)]) }
              }

              HoverHandler {
                onHoveredChanged: if (hovered && !root.reflowingText) root.cursorActive = true
              }
            }
          }

          // ---------- Layout ----------
          PanelSeparator {
            visible: Quickshell.screens.length > 1
            foreground: root.bar.foreground
          }

          Column {
            width: parent.width
            spacing: 0
            visible: Quickshell.screens.length > 1

            Item {
              width: parent.width
              implicitHeight: layoutHeaderRow.implicitHeight

              PanelSectionHeader {
                id: layoutHeaderRow
                text: "LAYOUT"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacing.xs

                Button {
                  iconText: "󰑐"
                  tooltipText: "Reset defaults (bar on top, notifications top-right on this screen)"
                  fontSize: Theme.font.caption
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  horizontalPadding: Theme.spacing.sm
                  verticalPadding: Theme.spacing.controlPaddingY
                  onClicked: root.resetLayoutDefaults()
                }
              }
            }

            MonitorLayoutPicker {
              width: parent.width
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              barPlacements: root.layoutBarPlacements
              notificationsPlacements: root.layoutNotificationsPlacements
              selectedMonitor: root.selectedMonitor
              enabled: root.opened
              showWorkspaces: true
              onBarChosen: function(output, position) { root.toggleBarLayout(output, position) }
              onNotificationsChosen: function(output, position, align) {
                root.toggleNotificationsLayout(output, position, align)
              }
              onMonitorChosen: function(output) { root.chooseMonitor(output) }
            }
          }

          Item {
            width: parent.width
            height: Theme.space(4)
          }
        }
      }
    }
  }
}
