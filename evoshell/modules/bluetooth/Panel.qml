import QtQuick
import QtQuick.Controls
import Quickshell.Bluetooth
import Quickshell.Io
import qs.commons
import qs.ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "evo.bluetooth"
  ipcTarget: "evo.bluetooth"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: bar ? bar.barForeground : Theme.foreground
  readonly property color accent: Theme.accent
  readonly property string fontFamily: bar ? bar.fontFamily : Theme.font.family
  readonly property color hoverFill: Theme.hoverFillFor(foreground, accent)
  readonly property color selectedFill: Theme.selectedFillFor(foreground, accent)

  readonly property var adapter: Bluetooth.defaultAdapter
  // Set once this instance has asked BlueZ to scan, or opened onto a scan
  // already running. Quickshell only forwards a discovering write that differs
  // from the last state BlueZ reported, so the stop has to wait until that
  // confirmation lands — a write in the close handler is swallowed if
  // StartDiscovery is still in flight, and the radio stays in inquiry.
  property bool owesDiscoveryStop: false
  property bool wantDiscovery: false
  property var pendingActions: ({})

  readonly property var deviceGroups: Model.deviceLists(Bluetooth.devices ? Bluetooth.devices.values : [], adapter)
  readonly property var connectedDevices: deviceGroups.connected || []
  readonly property var knownDevices: deviceGroups.known || []
  readonly property var discoveredDevices: deviceGroups.discovered || []
  readonly property bool scanning: !!(adapter && adapter.enabled && adapter.discovering)
  readonly property var sections: Model.visibleSections(deviceGroups, scanning)

  readonly property string iconGlyph: {
    if (!adapter || !adapter.enabled) return "󰂲"
    if (connectedDevices.length > 0) return "󰂱"
    return "󰂯"
  }
  readonly property bool iconMuted: !adapter || !adapter.enabled
  readonly property bool iconBusy: scanning && opened
  readonly property string barTooltip: {
    if (!adapter) return "No Bluetooth adapter"
    if (!adapter.enabled) return "Bluetooth off"
    if (connectedDevices.length === 1) return "Bluetooth, 1 connected"
    if (connectedDevices.length > 1) return "Bluetooth, " + connectedDevices.length + " connected"
    return "Bluetooth on"
  }
  readonly property string heroStatus: {
    if (!adapter) return "No adapter"
    if (!adapter.enabled) return "Off"
    return "On"
  }
  readonly property bool powerBusy: adapter && (adapter.state === BluetoothAdapterState.Enabling || adapter.state === BluetoothAdapterState.Disabling)
  readonly property string toggleHint: adapter && adapter.enabled ? "Turn off" : "Turn on"

  property string focusSection: "header"
  property int selectedIndex: 0
  property bool actionFocused: false
  property bool cursorActive: false
  readonly property bool headerHasCursor: cursorActive && focusSection === "header"

  function liveDevice(address) {
    var all = Bluetooth.devices ? Bluetooth.devices.values : []
    var i
    for (i = 0; i < all.length; i++) {
      if (all[i] && String(all[i].address || "") === address)
        return all[i]
    }
    return null
  }

  function setPending(address, action) {
    pendingActions = Model.withPendingAction(pendingActions, address, action)
    if (action)
      pendingTimeout.restart()
  }

  function connectAddress(address) {
    var device = liveDevice(address)
    if (!device || device.connected)
      return
    setPending(address, "connecting")
    if (device.paired || device.bonded || device.trusted)
      device.connected = true
    else
      device.pair()
  }

  function disconnectAddress(address) {
    var device = liveDevice(address)
    if (!device || !device.connected)
      return
    setPending(address, "disconnecting")
    device.connected = false
  }

  function forgetAddress(address) {
    var device = liveDevice(address)
    if (!device)
      return
    setPending(address, "forgetting")
    device.forget()
  }

  function deviceRows() {
    function list(value) {
      return value && value.length !== undefined ? value : []
    }
    return list(connectedDevices).concat(list(knownDevices)).concat(list(discoveredDevices))
  }

  function syncPending() {
    var next = Model.cloneMap(pendingActions)
    var all = deviceRows()
    var changed = false
    var address, action, found, i, done
    for (address in next) {
      action = next[address]
      found = null
      for (i = 0; i < all.length; i++) {
        if (all[i].address === address) {
          found = all[i]
          break
        }
      }
      done = (action === "connecting" && found && found.connected)
        || (action === "disconnecting" && found && !found.connected)
        || (action === "forgetting" && (!found || !found.paired))
      if (done) {
        delete next[address]
        changed = true
      }
    }
    if (changed)
      pendingActions = next
  }

  function sectionCount(section) {
    if (section === "connected") return connectedDevices.length
    if (section === "known") return knownDevices.length
    if (section === "discovered") return discoveredDevices.length
    return 0
  }

  function rowAt(section, index) {
    var list = section === "connected" ? connectedDevices : section === "known" ? knownDevices : discoveredDevices
    if (index < 0 || index >= list.length)
      return null
    return list[index]
  }

  function clampCursor() {
    var list = sections
    if (focusSection === "header")
      return
    if (!list || list.length === 0) {
      focusSection = "header"
      selectedIndex = 0
      actionFocused = false
      return
    }
    if (list.indexOf(focusSection) < 0) {
      focusSection = list[0]
      selectedIndex = 0
      actionFocused = false
      return
    }
    var count = sectionCount(focusSection)
    if (count <= 0) {
      focusSection = "header"
      selectedIndex = 0
      actionFocused = false
      return
    }
    if (selectedIndex > count - 1)
      selectedIndex = count - 1
    if (selectedIndex < 0)
      selectedIndex = 0
  }

  function moveCursor(delta) {
    cursorActive = true
    var list = sections
    if (focusSection === "header") {
      if (delta > 0 && list && list.length > 0) {
        focusSection = list[0]
        selectedIndex = 0
        actionFocused = false
      }
      return
    }
    if (!list || list.length === 0) {
      focusSection = "header"
      actionFocused = false
      return
    }
    var sIdx = list.indexOf(focusSection)
    if (sIdx < 0) {
      focusSection = list[0]
      selectedIndex = 0
      actionFocused = false
      return
    }
    if (delta > 0) {
      if (selectedIndex < sectionCount(focusSection) - 1) {
        selectedIndex += 1
        actionFocused = false
        return
      }
      if (sIdx < list.length - 1) {
        focusSection = list[sIdx + 1]
        selectedIndex = 0
        actionFocused = false
      }
      return
    }
    if (selectedIndex > 0) {
      selectedIndex -= 1
      actionFocused = false
      return
    }
    if (sIdx > 0) {
      focusSection = list[sIdx - 1]
      selectedIndex = Math.max(0, sectionCount(focusSection) - 1)
      actionFocused = false
      return
    }
    focusSection = "header"
    actionFocused = false
  }

  function moveCursorH(delta) {
    cursorActive = true
    if (focusSection !== "known" && focusSection !== "connected")
      return
    if (delta > 0)
      actionFocused = true
    else if (delta < 0)
      actionFocused = false
  }

  function activateCursor() {
    if (focusSection === "header") {
      toggleBluetooth()
      return
    }
    var row = rowAt(focusSection, selectedIndex)
    if (!row)
      return
    if (actionFocused) {
      forgetAddress(row.address)
      return
    }
    if (row.connected)
      disconnectAddress(row.address)
    else
      connectAddress(row.address)
  }

  function deleteSelected() {
    if (focusSection !== "known" && focusSection !== "connected")
      return
    var row = rowAt(focusSection, selectedIndex)
    if (row)
      forgetAddress(row.address)
  }

  function toggleBluetooth() {
    if (!adapter)
      return
    adapter.enabled = !adapter.enabled
  }

  function placeCursor() {
    if (connectedDevices.length > 0) {
      focusSection = "connected"
      selectedIndex = 0
    } else if (knownDevices.length > 0) {
      focusSection = "known"
      selectedIndex = 0
    } else if (scanning && discoveredDevices.length > 0) {
      focusSection = "discovered"
      selectedIndex = 0
    } else {
      focusSection = "header"
      selectedIndex = 0
    }
    actionFocused = false
    cursorActive = false
  }

  function siblingPanel(openOnly) {
    if (!bar || typeof bar.moduleWidgets !== "function")
      return null
    var items = bar.moduleWidgets(moduleName)
    var i, panel
    for (i = 0; i < items.length; i++) {
      panel = items[i] && items[i].panelItem
      if (!panel || panel === root)
        continue
      if (openOnly && panel.opened !== true)
        continue
      return panel
    }
    return null
  }

  function handDiscoveryTo(panel) {
    if (!panel)
      return false
    panel.owesDiscoveryStop = true
    panel.wantDiscovery = true
    owesDiscoveryStop = false
    wantDiscovery = false
    return true
  }

  function openFromHotkey() {
    root.controller.show()
  }

  function toggle() {
    if (root.opened)
      root.close()
    else
      root.openFromHotkey()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  onDeviceGroupsChanged: {
    syncPending()
    if (opened)
      clampCursor()
  }

  onOpenedChanged: {
    if (opened) {
      if (adapter && adapter.discovering) {
        owesDiscoveryStop = true
        wantDiscovery = true
      }
      placeCursor()
    }
  }

  Component.onDestruction: {
    if (!owesDiscoveryStop && !wantDiscovery)
      return
    if (handDiscoveryTo(siblingPanel(false)))
      return
    if (adapter && adapter.discovering)
      adapter.discovering = false
  }

  Timer {
    id: discoveryRetry
    interval: 1000
    repeat: true
    triggeredOnStart: true
    running: root.opened && root.adapter !== null && root.adapter.enabled && !root.adapter.discovering
    onTriggered: {
      root.wantDiscovery = true
      root.adapter.discovering = true
    }
  }

  Timer {
    id: discoveryStop
    interval: 1000
    repeat: true
    property int attempts: 0
    running: !root.opened && root.owesDiscoveryStop && root.adapter !== null && root.adapter.discovering === true
    onRunningChanged: if (running) attempts = 0
    onTriggered: {
      if (root.handDiscoveryTo(root.siblingPanel(true)))
        return
      attempts += 1
      if (attempts > 3) {
        root.owesDiscoveryStop = false
        root.wantDiscovery = false
        return
      }
      root.adapter.discovering = false
    }
  }

  Connections {
    target: root.adapter
    function onDiscoveringChanged() {
      if (!root.adapter)
        return
      if (root.adapter.discovering && (root.opened || root.wantDiscovery))
        root.owesDiscoveryStop = true
      if (!root.adapter.discovering) {
        root.owesDiscoveryStop = false
        if (!root.opened)
          root.wantDiscovery = false
      }
    }
    function onEnabledChanged() {
      if (root.adapter && !root.adapter.enabled && root.adapter.discovering)
        root.adapter.discovering = false
    }
  }

  Timer {
    id: pendingTimeout
    interval: 20000
    repeat: false
    onTriggered: root.pendingActions = ({})
  }

  IpcHandler {
    enabled: !!root.hostWidget && root.hostWidget.ownsIpc
    target: root.ipcTarget

    function open(): void { root.openFromHotkey() }
    function close(): void { root.close() }
    function show(): void { root.openFromHotkey() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Theme.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Theme.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        if (dy !== 0)
          root.moveCursor(dy)
        else if (dx !== 0)
          root.moveCursorH(dx)
      }
      onActivateRequested: root.activateCursor()
      onDeleteRequested: root.deleteSelected()

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

          PanelHero {
            id: hero
            width: parent.width
            title: "Bluetooth"
            meta: root.heroStatus
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: root.adapter && root.adapter.enabled ? 1 : 0.5

            iconComponent: Component {
              Text {
                textFormat: Text.PlainText
                text: root.iconGlyph
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Theme.font.display
              }
            }

            trailingControl: Component {
              ToggleSwitch {
                id: powerSwitch
                visible: !!root.adapter
                checked: !!root.adapter && root.adapter.enabled
                busy: root.powerBusy
                hasCursor: root.headerHasCursor
                foreground: root.foreground
                onColor: Theme.green
                onHovered: function(on) { if (on) { root.cursorActive = true; root.focusSection = "header"; root.actionFocused = false } }
                onToggled: root.toggleBluetooth()

                PanelToolTip {
                  visible: powerSwitch.containsMouse
                  text: root.toggleHint
                  fontFamily: root.fontFamily
                }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          SectionFieldset {
            width: parent.width
            visible: root.connectedDevices.length > 0
            legend: "Connected"

            Repeater {
              model: root.connectedDevices
              DeviceRow {
                required property var modelData
                required property int index
                width: parent.width
                dev: modelData
                rowIndex: index
                sectionName: "connected"
                isDiscovered: false
              }
            }
          }

          SectionFieldset {
            width: parent.width
            visible: root.knownDevices.length > 0
            legend: "Paired"

            ListView {
              id: pairedList
              width: parent.width
              implicitHeight: Math.min(contentHeight, Theme.space(400))
              height: implicitHeight
              spacing: Theme.space(8)
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              interactive: contentHeight > height
              model: root.knownDevices
              currentIndex: root.focusSection === "known" ? root.selectedIndex : -1
              onCurrentIndexChanged: if (currentIndex >= 0) Qt.callLater(function() {
                pairedList.positionViewAtIndex(pairedList.currentIndex, ListView.Contain)
              })
              ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

              delegate: DeviceRow {
                required property var modelData
                required property int index
                width: pairedList.width
                dev: modelData
                rowIndex: index
                sectionName: "known"
                isDiscovered: false
              }
            }
          }

          SectionFieldset {
            width: parent.width
            visible: root.scanning && root.discoveredDevices.length > 0
            legend: "Available"

            ListView {
              id: availableList
              width: parent.width
              implicitHeight: Math.min(contentHeight, Theme.space(400))
              height: implicitHeight
              spacing: Theme.space(8)
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              interactive: contentHeight > height
              model: root.discoveredDevices
              currentIndex: root.focusSection === "discovered" ? root.selectedIndex : -1
              onCurrentIndexChanged: if (currentIndex >= 0) Qt.callLater(function() {
                availableList.positionViewAtIndex(availableList.currentIndex, ListView.Contain)
              })
              ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

              delegate: DeviceRow {
                required property var modelData
                required property int index
                width: availableList.width
                dev: modelData
                rowIndex: index
                sectionName: "discovered"
                isDiscovered: true
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            visible: root.connectedDevices.length === 0 && root.knownDevices.length === 0 && !(root.scanning && root.discoveredDevices.length > 0)
            text: "No devices"
            color: Qt.darker(root.foreground, 1.5)
            font.family: root.fontFamily
            font.pixelSize: Theme.font.bodySmall
            wrapMode: Text.WordWrap
            width: parent.width
          }
        }
      }
    }
  }

  component DeviceRow: CursorSurface {
    id: row
    required property var dev
    required property int rowIndex
    required property string sectionName
    required property bool isDiscovered

    readonly property string action: Model.pendingAction(root.pendingActions, dev ? dev.address : "")
    readonly property bool isConnected: !!(dev && dev.connected)
    readonly property bool rowSelected: root.cursorActive && root.focusSection === sectionName && root.selectedIndex === rowIndex
    readonly property bool forgetAvailable: sectionName === "known" || sectionName === "connected"
    readonly property bool showForgetButton: forgetAvailable && (rowMouse.containsMouse || rowSelected)
    readonly property string actionTooltip: {
      if (!dev) return ""
      if (isConnected) return "Disconnect"
      if (isDiscovered) return "Pair"
      return "Connect"
    }
    readonly property string statusText: {
      if (!dev) return ""
      if (action === "forgetting") return "Forgetting"
      if (action === "disconnecting" || dev.state === BluetoothDeviceState.Disconnecting) return "Disconnecting"
      if (isConnected) {
        if (dev.batteryAvailable) return Math.round(dev.battery * 100) + "%"
        return "Connected"
      }
      if (action === "connecting" || dev.state === BluetoothDeviceState.Connecting || dev.pairing) return "Connecting"
      return ""
    }
    readonly property color statusColor: isConnected || action !== "" ? root.foreground : Qt.darker(root.foreground, 1.5)

    hasCursor: rowSelected && !root.actionFocused
    current: isConnected
    foreground: root.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill
    implicitHeight: rowContent.implicitHeight + Theme.space(16)

    function focusRow() {
      root.cursorActive = true
      root.focusSection = row.sectionName
      root.selectedIndex = row.rowIndex
      root.actionFocused = false
    }

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: row.dev ? Qt.PointingHandCursor : Qt.ArrowCursor
      onContainsMouseChanged: if (containsMouse) row.focusRow()
      onClicked: function(mouse) {
        if (!row.dev) return
        row.focusRow()
        if (mouse.button === Qt.RightButton) {
          if (row.forgetAvailable)
            root.forgetAddress(row.dev.address)
          return
        }
        if (row.isConnected)
          root.disconnectAddress(row.dev.address)
        else
          root.connectAddress(row.dev.address)
      }
    }

    PanelToolTip {
      visible: row.actionTooltip !== "" && rowMouse.containsMouse && !root.actionFocused
      text: row.actionTooltip
      fontFamily: root.fontFamily
    }

    Item {
      id: rowContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Theme.space(10)
      anchors.rightMargin: Theme.space(10)
      implicitHeight: Math.max(deviceIcon.implicitHeight, info.implicitHeight, forgetBtn.implicitHeight)

      Text {
        id: deviceIcon
        textFormat: Text.PlainText
        text: row.isConnected ? "󰂱" : "󰂯"
        color: row.statusColor
        font.family: root.fontFamily
        font.pixelSize: Theme.font.heading
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
      }

      Column {
        id: info
        spacing: Theme.space(1)
        anchors.left: deviceIcon.right
        anchors.leftMargin: Theme.space(10)
        anchors.right: forgetBtn.visible ? forgetBtn.left : parent.right
        anchors.rightMargin: forgetBtn.visible ? Theme.space(8) : 0
        anchors.verticalCenter: parent.verticalCenter

        Text {
          textFormat: Text.PlainText
          text: row.dev ? row.dev.name : "Device"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Theme.font.body
          elide: Text.ElideRight
          width: parent.width
        }

        Text {
          textFormat: Text.PlainText
          visible: row.statusText !== ""
          text: row.statusText
          color: row.statusColor
          font.family: root.fontFamily
          font.pixelSize: Theme.font.caption
          elide: Text.ElideRight
          width: parent.width
        }
      }

      PanelActionButton {
        id: forgetBtn
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: row.showForgetButton
        iconText: "󰅙"
        tooltipText: "Forget"
        foreground: root.foreground
        hoverColor: root.bar ? root.bar.urgent : Theme.urgent
        fontFamily: root.fontFamily
        hasCursor: row.rowSelected && root.actionFocused
        onHovered: function(isHovered) {
          if (!isHovered) {
            if (rowMouse.containsMouse)
              root.actionFocused = false
            return
          }
          root.cursorActive = true
          root.focusSection = row.sectionName
          root.selectedIndex = row.rowIndex
          root.actionFocused = true
        }
        onClicked: {
          if (!row.dev) return
          root.forgetAddress(row.dev.address)
        }
      }
    }
  }

  component SectionFieldset: Item {
    id: fieldset
    property string legend: ""
    default property alias contentData: fieldColumn.data

    readonly property int legendBand: legendChip.height / 2
    implicitHeight: fieldColumn.implicitHeight + legendBand + Theme.space(26)
    height: implicitHeight

    Rectangle {
      anchors.fill: parent
      anchors.topMargin: fieldset.legendBand
      color: "transparent"
      radius: Theme.space(8)
      border.width: 1
      border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.28)
      antialiasing: true
    }

    Item {
      id: legendChip
      x: Theme.space(14)
      y: 0
      width: legendText.implicitWidth + Theme.space(8)
      height: Math.max(1, legendText.implicitHeight)

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
        color: Qt.darker(root.foreground, 1.4)
        font.family: root.fontFamily
        font.pixelSize: Theme.font.caption
        font.bold: true
      }
    }

    Column {
      id: fieldColumn
      x: Theme.space(12)
      y: fieldset.legendBand + Theme.space(14)
      width: parent.width - Theme.space(24)
      spacing: Theme.space(8)
    }
  }
}
