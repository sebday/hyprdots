import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.commons
import qs.ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "evo.now-playing"

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource
  readonly property real outputVolume: sink && sink.audio ? sink.audio.volume : 0
  readonly property bool outputMuted: sink && sink.audio ? sink.audio.muted : false
  readonly property bool hasOutput: !!(sink && sink.audio)

  readonly property bool iconError: panelLoader.item ? panelLoader.item.iconError === true : false
  readonly property bool iconBusy: panelLoader.item ? panelLoader.item.iconBusy === true : false
  readonly property bool iconMuted: panelLoader.item ? panelLoader.item.iconMuted === true : false
  readonly property string tooltip: panelLoader.item ? panelLoader.item.barTooltip : "Now playing"

  function setOutputVolume(v) {
    if (!sink || !sink.audio) return outputVolume
    var volume = Math.max(0, Math.min(1, v))
    sink.audio.volume = volume
    return volume
  }

  function toggleMuted() {
    if (sink && sink.audio)
      sink.audio.muted = !sink.audio.muted
  }

  function launchPlayer() {
    var bin = Quickshell.env("EVOPLAYER_BIN")
    if (!bin || String(bin).trim() === "")
      bin = (Quickshell.env("HOME") || "") + "/.local/lib/evoplayer/evoplayer"
    Quickshell.execDetached(["xdg-terminal-exec", "--", String(bin)])
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  width: implicitWidth
  height: implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  PwObjectTracker {
    objects: {
      var list = []
      if (root.sink) list.push(root.sink)
      if (root.source) list.push(root.source)
      return list
    }
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Model.outputIcon(root.sink, root.outputVolume, root.outputMuted)
    active: root.iconError
    useActiveColor: root.iconError
    dimmed: !root.hasOutput
    tooltipText: Model.plain(root.tooltip)
    opacity: root.iconBusy && !root.iconError ? iconPulse.pulseOpacity : 1

    BarIconPulse {
      id: iconPulse
      running: root.iconBusy && !root.iconError
    }

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton) {
        root.toggleMuted()
        return
      }
      if (b === Qt.MiddleButton) {
        root.launchPlayer()
        return
      }
      root.togglePanel()
    }

    onWheelMoved: function(delta) {
      if (!root.hasOutput || delta === 0) return
      var steps = delta > 0 ? 1 : -1
      root.setOutputVolume(root.outputVolume + steps * 0.05)
    }
  }
}
