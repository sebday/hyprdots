import QtQuick

// Shared open/cycle state for the runner, system menu, and clipboard menu
// action rows. Callers still own which keys open it and what an action runs.
//
// Usage:
//   ActionsMenu { id: actions }
QtObject {
  id: root

  property bool open: false
  property int index: 0

  function reset() {
    open = false
  }

  function toggle(count) {
    if (count <= 0)
      return
    if (!open) {
      index = count > 1 ? 1 : 0
      open = true
      return
    }
    index = (index + 1) % count
  }

  function move(delta, count) {
    if (count <= 0)
      return
    index = (index + delta + count) % count
  }
}
