import QtQuick
import Quickshell
import "../../../Commons"

Item {
    id: root

    property var bar: null
    property var barPanel: null
    property var shell: null
    property var settings: ({})

    readonly property string hoverPopupId: settings.onHover
        ? String(settings.onHover)
        : (trayMode ? "evo.stocks" : "")
    readonly property bool trayMode: settings.trayMode === true
    readonly property int trayIconSize: {
        var n = parseInt(settings.trayIconSize, 10)
        return isNaN(n) || n <= 0 ? 18 : n
    }
    readonly property int trayCellWidth: {
        var n = parseInt(settings.trayCellWidth, 10)
        return isNaN(n) || n <= 0 ? trayIconSize + 4 : n
    }

    readonly property string trayIconText: "󰄪"

    implicitWidth: trayMode ? trayCellWidth : trayIconSize + Theme.barPaddingX * 2
    implicitHeight: Theme.barHeight
    width: trayMode && parent ? parent.width : implicitWidth
    height: Theme.barHeight

    function setHoverPopup(active) {
        if (!shell || !hoverPopupId) return
        if (active)
            shell.hoverEnter(hoverPopupId, root, barPanel)
        else
            shell.hoverLeave(hoverPopupId)
    }

    Text {
        id: trayIcon
        anchors.centerIn: parent
        visible: root.trayMode
        text: root.trayIconText
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: root.trayIconSize
        font.bold: Theme.fontBold
    }

    MouseArea {
        anchors.fill: parent
        visible: root.trayMode
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: root.setHoverPopup(containsMouse)
    }
}
