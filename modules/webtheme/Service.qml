import QtQuick
import Quickshell
import Quickshell.Io
import qs.commons

Item {
  id: root
  visible: false

  property var shell: null
  property var manifest: null
  property bool flagsChanged: false
  property string lastError: ""
  property int siteCount: 0

  readonly property string webthemeScript: Qt.resolvedUrl("bin/webtheme").toString().replace("file://", "")

  function setup() {
    if (!webthemeScript || setupProc.running) return
    setupProc.command = [webthemeScript, "setup"]
    setupProc.running = true
  }

  function assemble() {
    if (!webthemeScript || setupProc.running) return
    setupProc.command = [webthemeScript, "assemble"]
    setupProc.running = true
  }

  Process {
    id: setupProc
    onStarted: { stdoutBuf = ""; stderrBuf = "" }

    property string stdoutBuf: ""
    property string stderrBuf: ""
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        setupProc.stdoutBuf += chunk
        if (setupProc.stdoutBuf.length > 262144) {
          setupProc.signal(15)
          setupProc.stdoutBuf = ""
        }
      }
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        setupProc.stderrBuf += chunk
        if (setupProc.stderrBuf.length > 4096) {
          setupProc.signal(15)
          setupProc.stderrBuf = ""
        }
      }
    }
      onExited: function(exitCode) {
      var raw = String(stdoutBuf || "").trim()
        if (!raw) return
        try {
          var parsed = JSON.parse(raw)
          root.flagsChanged = parsed.flagsChanged === true
          if (parsed.sites !== undefined) root.siteCount = Number(parsed.sites) || 0
          root.lastError = ""
        } catch (e) {
          root.lastError = "could not parse webtheme setup"
        }
      var err = String(stderrBuf || "").trim()
        if (err) root.lastError = err
    }
  }

  // evo-theme swaps ~/.themes/current and then pushes the palette into Theme;
  // re-render the extension colors.css once the new colours land.
  function syncTheme() {
    if (!webthemeScript) return
    if (syncProc.running) {
      syncTimer.restart()
      return
    }
    syncProc.command = [webthemeScript, "sync-theme"]
    syncProc.running = true
  }

  Timer {
    id: syncTimer
    interval: 800
    onTriggered: root.syncTheme()
  }

  Connections {
    target: Theme
    function onBackgroundChanged() { syncTimer.restart() }
    function onForegroundChanged() { syncTimer.restart() }
    function onAccentChanged() { syncTimer.restart() }
  }

  Process {
    id: syncProc
    stderr: StdioCollector {
      onStreamFinished: {
        var err = String(text || "").trim()
        if (err) root.lastError = err.slice(0, 400)
      }
    }
  }

  Component.onCompleted: syncTimer.restart()
}
