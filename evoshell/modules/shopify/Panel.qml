import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.commons
import qs.ui
import "Model.js" as Model
import "components"

// Standalone panel. The shell mounts this while it is open and calls open/close.
// evo-theme swaps ~/.themes/current by rename, so a watch on colors.toml dies
// with the old directory. The chrome follows Theme and the store colours are
// re-read by panel-config whenever Theme changes.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property bool closingFromHost: false

  property var stores: []
  property var payloads: ({})
  property int storeIdx: 0
  property string metric: "revenue"
  property bool loading: false
  property bool refreshing: false
  property string errorText: ""
  property int pollIntervalMinutes: 5
  property bool pollStarted: false
  property bool pendingRefresh: false
  property bool pendingConfig: false
  property int snapToken: 0
  property int configToken: 0
  property var palette: ({})

  readonly property string fontFamily: Theme.font.resolvedFamily || Theme.font.family
  readonly property color colBg: Theme.background
  readonly property color colText: Theme.foreground
  readonly property color colMuted: Theme.muted
  readonly property color colBright: Model.pickColor(palette.bright_foreground, Theme.foreground)
  readonly property color colWarn: Theme.urgent
  readonly property color fallbackAccent: Theme.accent

  readonly property string shopifyConfigJson: {
    var cfg = root.shell && root.shell.shellConfig ? root.shell.shellConfig.shopify : null
    return JSON.stringify({ shopify: cfg && typeof cfg === "object" ? cfg : {} })
  }
  onShopifyConfigJsonChanged: {
    root.loadConfig()
    if (root.opened) root.runSnapshot("refresh")
  }

  readonly property var columns: {
    var list = root.stores || []
    if (!list.length) return []
    if (list.length === 1) return [{ store: list[0], index: 0 }]
    var i = root.storeIdx % list.length
    if (i < 0) i = 0
    return [
      { store: list[i], index: i },
      { store: list[(i + 1) % list.length], index: (i + 1) % list.length }
    ]
  }

  function fromUrl(rel) {
    var u = Qt.resolvedUrl(rel).toString()
    if (u.indexOf("file://") !== 0) return ""
    return decodeURIComponent(u.slice("file://".length))
  }

  readonly property string statusScript: fromUrl("bin/shopify-status")
  readonly property string panelRun: fromUrl("bin/panel-run")
  readonly property string panelConfig: fromUrl("bin/panel-config")

  function childEnv() {
    var env = {
      HOME: Quickshell.env("HOME") || "",
      USER: Quickshell.env("USER") || "",
      LOGNAME: Quickshell.env("USER") || "",
      PATH: "/usr/bin:/bin",
      LANG: "C.UTF-8"
    }
    var runtime = Quickshell.env("XDG_RUNTIME_DIR") || ""
    if (runtime !== "") env.XDG_RUNTIME_DIR = runtime
    var bus = Quickshell.env("DBUS_SESSION_BUS_ADDRESS") || ""
    if (bus !== "") env.DBUS_SESSION_BUS_ADDRESS = bus
    var passthrough = ["EVOSHELL_ROOT", "EVOSHELL_CONFIG", "EVOSHELL_STATE", "EVOSHELL_CACHE",
      "XDG_CACHE_HOME", "XDG_STATE_HOME", "PASSWORD_STORE_DIR", "GNUPGHOME"]
    for (var i = 0; i < passthrough.length; i++) {
      var value = Quickshell.env(passthrough[i]) || ""
      if (value !== "") env[passthrough[i]] = value
    }
    env.EVO_SHOPIFY_CONFIG = root.shopifyConfigJson
    env.EVO_THEME_DIR = Theme.currentThemePath
    return env
  }

  function leftPayload() {
    if (!root.columns.length) return null
    var key = root.columns[0].store.key
    return root.payloads[key] || null
  }

  function ensureMetric() {
    var payload = root.leftPayload()
    if (!payload) return
    if (Model.metricClickable(payload, root.metric)) return
    var next = Model.nextMetric(payload, root.metric, 1)
    root.metric = Model.metricClickable(payload, next) ? next : "revenue"
  }

  function chooseMetric(id) {
    if (Model.metricById(id).id !== id) return
    root.metric = id
  }

  function stepMetric(dir) {
    var payload = root.leftPayload()
    if (!payload) return
    root.metric = Model.nextMetric(payload, root.metric, dir)
  }

  function stepStore(dir) {
    var n = root.stores.length
    if (n < 1) return
    root.storeIdx = (root.storeIdx + dir + n) % n
    root.ensureMetric()
  }

  function focusedScreen() {
    var monitor = Hyprland.focusedMonitor
    var name = monitor ? String(monitor.name || "") : ""
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) {
      if (screens[i] && String(screens[i].name) === name)
        return screens[i]
    }
    return screens.length > 0 ? screens[0] : null
  }

  function open(payloadJson) {
    var already = root.opened
    root.closingFromHost = false
    var screen = root.focusedScreen()
    if (screen)
      dashWindow.screen = screen
    root.opened = true
    Qt.callLater(function() {
      if (root.opened) keyCatcher.forceActiveFocus()
    })
    root.loadConfig()
    if (!already) {
      root.pollStarted = true
      root.loading = root.stores.length === 0
      root.runSnapshot("cache")
    }
  }

  function close() {
    root.closingFromHost = true
    root.opened = false
    root.pollStarted = false
    root.pendingRefresh = false
    root.pendingConfig = false
    root.snapToken += 1
    root.configToken += 1
    if (snapshotProc.running) {
      snapshotProc.signal(15)
      snapKillTimer.start()
    }
    if (configProc.running) {
      configProc.signal(15)
      configKillTimer.start()
    }
    root.closingFromHost = false
  }

  function dismiss() {
    if (root.shell && typeof root.shell.hide === "function") {
      var id = root.manifest && root.manifest.id ? root.manifest.id : "evo.shopify"
      root.shell.hide(id)
    } else {
      root.close()
    }
  }

  function refresh() {
    root.runSnapshot("refresh")
  }

  function runSnapshot(mode) {
    if (mode !== "cache" && mode !== "refresh") return
    if (!root.statusScript || !root.panelRun) return
    if (snapshotProc.running) {
      if (mode === "refresh") root.pendingRefresh = true
      return
    }
    root.snapToken += 1
    snapshotProc.token = root.snapToken
    snapshotProc.mode = mode
    snapshotProc.overflow = false
    snapshotProc.stdoutBuf = ""
    snapshotProc.stderrBuf = ""
    snapshotProc.environment = root.childEnv()
    snapshotProc.command = [
      "/usr/bin/python3", "-I", "-S", root.panelRun,
      "/usr/bin/bash", root.statusScript, mode
    ]
    root.refreshing = true
    snapshotProc.running = true
  }

  function applySnapshot(raw, mode) {
    var snap = Model.parseSnapshot(raw)
    if (snap.stores.length > 0) {
      root.stores = snap.stores
      root.payloads = snap.payloads
      root.errorText = ""
      root.loading = false
      if (root.storeIdx >= snap.stores.length) root.storeIdx = 0
      root.ensureMetric()
      return
    }
    if (mode === "cache") return
    root.loading = false
    if (root.stores.length === 0)
      root.errorText = "No stores. Set shopify.apiUrl in shell.json"
  }

  function loadConfig() {
    if (!root.panelRun || !root.panelConfig) return
    if (configProc.running) {
      root.pendingConfig = true
      return
    }
    root.configToken += 1
    configProc.token = root.configToken
    configProc.overflow = false
    configProc.stdoutBuf = ""
    configProc.stderrBuf = ""
    configProc.environment = root.childEnv()
    configProc.command = [
      "/usr/bin/python3", "-I", "-S", root.panelRun,
      "/usr/bin/bash", root.panelConfig
    ]
    configProc.running = true
  }

  function applyConfig(raw) {
    var json
    try { json = JSON.parse(String(raw || "")) } catch (e) { return }
    var mins = json.pollIntervalMinutes
    if (typeof mins === "number" && isFinite(mins) && mins >= 1 && mins <= 1440)
      root.pollIntervalMinutes = Math.round(mins)
    if (json.colors && typeof json.colors === "object")
      root.palette = Model.sanitizeColors(json.colors)
  }

  Component.onCompleted: root.loadConfig()
  Component.onDestruction: root.close()

  Process {
    id: snapshotProc
    clearEnvironment: true
    property string stdoutBuf: ""
    property string stderrBuf: ""
    property string mode: ""
    property int token: 0
    property bool overflow: false

    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        if (snapshotProc.token !== root.snapToken || snapshotProc.overflow) return
        var next = snapshotProc.stdoutBuf + chunk
        if (next.length > 262144) {
          snapshotProc.overflow = true
          snapshotProc.stdoutBuf = ""
          snapshotProc.signal(15)
          snapKillTimer.start()
          return
        }
        snapshotProc.stdoutBuf = next
      }
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        if (snapshotProc.token !== root.snapToken) return
        var next = snapshotProc.stderrBuf + chunk
        if (next.length > 4096) {
          snapshotProc.stderrBuf = next.slice(0, 4096)
          return
        }
        snapshotProc.stderrBuf = next
      }
    }
    onExited: function(exitCode) {
      snapKillTimer.stop()
      root.refreshing = false
      if (snapshotProc.token !== root.snapToken || !root.opened) return
      var mode = snapshotProc.mode
      if (snapshotProc.overflow) {
        root.loading = false
        if (root.stores.length === 0) root.errorText = "Output exceeded the limit"
      } else if (exitCode !== 0) {
        root.loading = false
        if (root.stores.length === 0) {
          var err = Model.plain(snapshotProc.stderrBuf, 160)
          root.errorText = err || "Could not load stores"
        }
      } else {
        root.applySnapshot(snapshotProc.stdoutBuf, mode)
      }

      var follow = ""
      if (mode === "cache" && root.opened && !snapshotProc.overflow) follow = "refresh"
      else if (root.pendingRefresh) follow = "refresh"
      root.pendingRefresh = false
      if (follow) root.runSnapshot(follow)
    }
  }

  Process {
    id: configProc
    clearEnvironment: true
    property string stdoutBuf: ""
    property string stderrBuf: ""
    property int token: 0
    property bool overflow: false

    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        if (configProc.token !== root.configToken || configProc.overflow) return
        var next = configProc.stdoutBuf + chunk
        if (next.length > 16384) {
          configProc.overflow = true
          configProc.stdoutBuf = ""
          configProc.signal(15)
          configKillTimer.start()
          return
        }
        configProc.stdoutBuf = next
      }
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        if (configProc.stderrBuf.length > 1024) return
        configProc.stderrBuf += chunk
      }
    }
    onExited: function(exitCode) {
      configKillTimer.stop()
      if (configProc.token !== root.configToken) return
      if (exitCode === 0 && !configProc.overflow)
        root.applyConfig(configProc.stdoutBuf)
      if (root.pendingConfig && root.opened) {
        root.pendingConfig = false
        root.loadConfig()
      } else {
        root.pendingConfig = false
      }
    }
  }

  Timer {
    id: snapKillTimer
    interval: 2000
    onTriggered: if (snapshotProc.running) snapshotProc.signal(9)
  }

  Timer {
    id: configKillTimer
    interval: 2000
    onTriggered: if (configProc.running) configProc.signal(9)
  }

  Timer {
    id: pollTimer
    interval: Math.max(60000, root.pollIntervalMinutes * 60 * 1000)
    repeat: true
    running: root.opened && root.pollStarted
    onTriggered: root.runSnapshot("refresh")
  }

  // Store border colours are not on the Color singleton. Re-read them when
  // the shell applies a theme, which is after colors.toml is in place.
  Connections {
    target: Theme
    function onBackgroundChanged() { root.loadConfig() }
    function onForegroundChanged() { root.loadConfig() }
    function onAccentChanged() { root.loadConfig() }
    function onMutedChanged() { root.loadConfig() }
  }

  FloatingWindow {
    id: dashWindow
    visible: root.opened
    title: "evo.shopify"
    color: root.colBg
    implicitWidth: 1280
    implicitHeight: 760
    minimumSize: Qt.size(900, 540)

    onVisibleChanged: {
      if (visible)
        Qt.callLater(function() { keyCatcher.forceActiveFocus() })
      else if (root.opened && !root.closingFromHost)
        root.dismiss()
    }

    Item {
      id: keyCatcher
      // Same outer inset as the player panel.
      readonly property int panelPad: 16
      anchors.fill: parent
      anchors.margins: panelPad
      focus: true

      MouseArea {
        anchors.fill: parent
        propagateComposedEvents: true
        onPressed: function(mouse) {
          keyCatcher.forceActiveFocus()
          mouse.accepted = false
        }
      }

      Keys.onEscapePressed: function(event) {
        root.dismiss()
        event.accepted = true
      }
      Keys.onPressed: function(event) {
        var t = event.text || ""
        if (t === "q" || t === "Q") {
          root.dismiss()
          event.accepted = true
          return
        }
        if (t === "r" || t === "R") {
          root.refresh()
          event.accepted = true
          return
        }
        if (t === "n" || t === "N") {
          root.stepStore(1)
          event.accepted = true
          return
        }
        if (t === "p" || t === "P") {
          root.stepStore(-1)
          event.accepted = true
          return
        }
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
          var back = event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier)
          root.stepMetric(back ? -1 : 1)
          event.accepted = true
        }
      }

      Text {
          anchors.centerIn: parent
          visible: root.columns.length === 0
          textFormat: Text.PlainText
          text: root.loading ? "Loading…" : (root.errorText || "No stores")
          color: root.loading ? root.colMuted : root.colWarn
          font.family: root.fontFamily
          font.pixelSize: Theme.font.subtitle
          horizontalAlignment: Text.AlignHCenter
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.verticalCenter
          anchors.topMargin: Theme.space(28)
          visible: root.columns.length === 0 && !root.loading
          width: Math.min(parent.width - Theme.space(48), Theme.space(520))
          wrapMode: Text.WordWrap
          textFormat: Text.PlainText
          text: "Set shopify.apiUrl in evoshell config and pass insert evoshell/ecommerce-data/api-token."
          color: root.colMuted
          font.family: root.fontFamily
          font.pixelSize: Theme.font.body
          horizontalAlignment: Text.AlignHCenter
        }

        Item {
          id: cols
          anchors.fill: parent
          visible: root.columns.length > 0

          readonly property int count: root.columns.length
          readonly property int gap: Theme.space(16)
          // One store needs about this much width for the four channel labels.
          // Narrower than two of those, stack the sites instead of squeezing them.
          readonly property int columnMin: Theme.space(480)
          readonly property bool stacked: count > 1 && width < columnMin * count + gap
          // Each stacked store keeps the full side-by-side column height.
          readonly property int slot: height
          // Titles are centred on the top border and paint into the window
          // padding. Extend the clip up into it so they stay whole without
          // moving the cards.
          readonly property int legendOverhang: Math.min(
            keyCatcher.panelPad,
            Math.ceil(legendMetrics.height / 2) + 1
          )

          FontMetrics {
            id: legendMetrics
            font.family: root.fontFamily
            font.pixelSize: Theme.font.bodySmall
            font.bold: true
          }

          onStackedChanged: if (!stacked) colScroll.contentY = 0

          Flickable {
            id: colScroll
            anchors.fill: parent
            anchors.topMargin: -cols.legendOverhang
            clip: true
            contentWidth: width
            contentHeight: cols.stacked
              ? cols.legendOverhang + cols.count * cols.slot + cols.gap * (cols.count - 1)
              : height
            interactive: cols.stacked
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            onContentHeightChanged: if (!cols.stacked) contentY = 0

            ScrollBar.vertical: ScrollBar {
              policy: cols.stacked ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }

            Repeater {
              model: root.columns

              StoreColumn {
                required property var modelData
                required property int index

                readonly property int span: Math.max(1, cols.count)

                x: cols.stacked ? 0 : index * (width + cols.gap)
                y: cols.legendOverhang + (cols.stacked ? index * (cols.slot + cols.gap) : 0)
                width: cols.stacked
                  ? colScroll.width
                  : Math.max(1, Math.floor((colScroll.width - cols.gap * (span - 1)) / span))
                height: cols.slot
                payload: root.payloads[modelData.store.key] || null
                metric: root.metric
                borderColor: Model.storeColor(modelData.store.key, modelData.index, root.palette, root.fallbackAccent)
                backgroundColor: root.colBg
                mutedColor: root.colMuted
                textColor: root.colText
                brightColor: root.colBright
                warnColor: root.colWarn
                fontFamily: root.fontFamily
                onMetricChosen: function(id) { root.chooseMetric(id) }
              }
            }
          }
        }
    }
  }
}
