import QtQuick
import "."

AttachedOverlay {
    id: root

    property var shell: null

    onHoverEntered: if (shell) shell.popupHoverEnter()
    onHoverLeft: if (shell) shell.popupHoverLeave()
}
