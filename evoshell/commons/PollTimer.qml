import QtQuick

// Status poll for a bar panel. closedMs 0 skips polling while the panel is
// closed. openMs 0 keeps the closed interval while the panel is open.
// Opening the panel polls once immediately.
Timer {
    id: root

    property bool open: false
    property int closedMs: 0
    property int openMs: 0

    signal poll()

    readonly property int activeMs: open && openMs > 0 ? openMs : closedMs

    interval: Math.max(activeMs, 1)
    repeat: true
    running: activeMs > 0

    onTriggered: poll()
    onOpenChanged: if (open) poll()
}
