import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.commons
import qs.ui
import "Model.js" as Model

PanelHost {
  id: root
  moduleName: "evo.now-playing"
  panelUrl: Qt.resolvedUrl("Panel.qml")
  anchor: button

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource
  readonly property real outputVolume: sink && sink.audio ? sink.audio.volume : 0
  readonly property bool outputMuted: sink && sink.audio ? sink.audio.muted : false
  readonly property bool hasOutput: !!(sink && sink.audio)

  readonly property bool iconError: panel ? panel.iconError === true : false
  readonly property bool iconBusy: panel ? panel.iconBusy === true : false
  readonly property bool iconMuted: panel ? panel.iconMuted === true : false
  readonly property string tooltip: panel ? panel.barTooltip : "Now playing"

  function showVolumeOsd(volume, muted) {
    var shell = bar && bar.shell
    if (!shell || typeof shell.summon !== "function") return
    var pct = Math.round(volume * 100)
    shell.summon("evo.osd", JSON.stringify({
      icon: muted ? "volume-muted" : "",
      value: muted ? 0 : Math.min(pct, 100),
      max: 100,
      progressText: muted ? "Muted" : pct + "%"
    }))
  }

  function setOutputVolume(v) {
    if (!sink || !sink.audio) return outputVolume
    var volume = Math.max(0, Math.min(1, v))
    sink.audio.volume = volume
    showVolumeOsd(volume, sink.audio.muted)
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

  PwObjectTracker {
    objects: {
      var list = []
      if (root.sink) list.push(root.sink)
      if (root.source) list.push(root.source)
      return list
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
