import QtQuick

AttachedOverlay {
    id: root

    property var shell: null

    anchorItem: shell ? shell.popupAnchorItem : null
    anchorWindow: shell ? shell.popupAnchorWindow : null
    barPosition: shell && shell.barConfig && shell.barConfig.position
        ? String(shell.barConfig.position)
        : "bottom"

    onHoverEntered: if (shell) shell.popupHoverEnter()
    onHoverLeft: if (shell) shell.popupHoverLeave()
}
