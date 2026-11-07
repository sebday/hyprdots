import QtQuick
import Quickshell.Wayland

// Open/close slide shared by the dock, runner, and power menu.
// `opened` drops as soon as hide starts, while the layer stays mapped until
// the slide finishes, so a second summon during the exit is not swallowed.
//
// progress is 0 hidden and 1 shown. Callers map that onto their own offset.
// An Item, not a QtObject, so the prime timer and the progress animation can
// live here. It takes no space in the parent.
//
// Usage:
//   SlideLifecycle { id: life; durationMs: Theme.duration(180) }
Item {
  id: root
  width: 0
  height: 0
  visible: false

  property string phase: "closed"
  property real progress: 0
  property int durationMs: 180
  // Dock and power prime Exclusive, then settle on OnDemand. The runner keeps
  // Exclusive for the whole open interval.
  property bool primeFocus: true
  property bool focusPrimed: false

  readonly property bool opened: phase === "entering" || phase === "open"
  readonly property bool mapped: phase !== "closed"
  readonly property int focusMode: {
    if (!opened)
      return WlrKeyboardFocus.None
    if (!primeFocus)
      return WlrKeyboardFocus.Exclusive
    return focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive
  }

  signal settled()

  function show() {
    if (phase === "open") {
      beginPrime()
      settled()
      return
    }
    if (phase === "entering") {
      beginPrime()
      return
    }
    phase = "entering"
    beginPrime()
    // Park on this turn, then slide in on the next, matching the old snap.
    Qt.callLater(function() {
      if (root.phase !== "entering")
        return
      var resting = root.progress >= 0.999
      root.progress = 1
      if (resting)
        root.finishOpen()
    })
  }

  function hide() {
    if (!opened)
      return
    phase = "leaving"
    primeTimer.stop()
    focusPrimed = false
    if (progress <= 0.02) {
      progress = 0
      phase = "closed"
      return
    }
    progress = 0
  }

  function beginPrime() {
    focusPrimed = false
    if (!primeFocus) {
      primeTimer.stop()
      return
    }
    primeTimer.restart()
  }

  function finishOpen() {
    if (phase !== "entering")
      return
    phase = "open"
    settled()
  }

  function noteProgress() {
    if (phase === "entering" && progress >= 0.999)
      finishOpen()
    else if (phase === "leaving" && progress <= 0.02)
      phase = "closed"
  }

  onProgressChanged: noteProgress()

  Behavior on progress {
    NumberAnimation {
      duration: root.durationMs
      easing.type: Easing.OutCubic
    }
  }

  Timer {
    id: primeTimer
    interval: 75
    onTriggered: if (root.opened) root.focusPrimed = true
  }
}
