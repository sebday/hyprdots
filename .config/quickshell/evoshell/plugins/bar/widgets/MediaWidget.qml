import QtQuick
import Quickshell
import "../../../Commons"

Item {
    id: root

    property var bar: null
    property var barPanel: null
    property var settings: ({})
    property var shell: null

    readonly property string mediaHoverPopupId: settings.mediaOnHover
        ? String(settings.mediaOnHover)
        : "evo.media"
    readonly property bool trayMode: settings.trayMode === true
    readonly property int trayIconSize: {
        var n = parseInt(settings.trayIconSize, 10)
        return isNaN(n) || n <= 0 ? 18 : n
    }
    readonly property int trayCellWidth: {
        var n = parseInt(settings.trayCellWidth, 10)
        return isNaN(n) || n <= 0 ? trayIconSize + 4 : n
    }

    implicitWidth: trayMode ? trayCellWidth : iconLabel.implicitWidth + Theme.barPaddingX * 2
    implicitHeight: Theme.barHeight
    width: trayMode && parent ? parent.width : implicitWidth
    height: Theme.barHeight

    function setMediaHoverPopup(active) {
        if (!shell || !mediaHoverPopupId) return
        if (active)
            shell.hoverEnter(mediaHoverPopupId, iconLabel, barPanel)
        else
            shell.hoverLeave(mediaHoverPopupId)
    }

    function openMediaLibrary() {
        if (shell) {
            shell.toggle("evo.library", "")
            return
        }
        Quickshell.execDetached(["bash", (Quickshell.env("HOME") || "") + "/.local/bin/evo-ipc", "shell", "toggle", "evo.library"])
    }

    Text {
        id: iconLabel
        anchors.centerIn: parent
        text: "󰍹"
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: root.trayMode ? root.trayIconSize : Theme.fontSizeM
        font.bold: Theme.fontBold
    }

    MouseArea {
        id: mediaMouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: root.setMediaHoverPopup(containsMouse)
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                Util.pinHoverPopupFromBarIfActive(root.shell, root.mediaHoverPopupId)
                return
            }
            root.openMediaLibrary()
        }
    }

}
