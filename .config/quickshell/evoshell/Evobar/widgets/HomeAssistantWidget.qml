import QtQuick
import Quickshell
import "../../Commons"

Item {
    id: root

    property var bar: null
    property var barPanel: null
    property var shell: null
    property var settings: ({})

    readonly property string hoverPopupId: settings.onHover
        ? String(settings.onHover)
        : (trayMode ? "evo.bar.popups.home-assistant" : "")
    readonly property bool trayMode: settings.trayMode === true
    readonly property int trayIconSize: {
        var n = parseInt(settings.trayIconSize, 10)
        return isNaN(n) || n <= 0 ? 18 : n
    }
    readonly property int trayCellWidth: {
        var n = parseInt(settings.trayCellWidth, 10)
        return isNaN(n) || n <= 0 ? trayIconSize + 4 : n
    }

    readonly property var ha: shell ? shell.serviceFor("evo.bar.popups.home-assistant") : null
    readonly property bool configured: ha && ha.configured
    readonly property bool warningState: ha && ha.warning
    readonly property bool heatingActive: ha && ha.heatingActive
    readonly property bool busy: ha && ha.busy
    readonly property string trayIconText: "󰚡"
    readonly property color trayIconColor: {
        if (!root.configured)
            return Theme.urgent
        if (root.heatingActive)
            return Theme.mixColors(Theme.urgent, "#ffaa00", 0.55)
        if (root.warningState)
            return Theme.urgent
        return Theme.foreground
    }

    implicitWidth: trayMode ? trayCellWidth : trayIconSize + Theme.barPaddingX * 2
    implicitHeight: Theme.barHeight
    width: trayMode && parent ? parent.width : implicitWidth
    height: Theme.barHeight

    function setHoverPopup(active) {
        if (!shell || !hoverPopupId)
            return
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
        color: root.trayIconColor
        opacity: root.busy ? 0.55 : 1
        font.family: Theme.fontFamily
        font.pixelSize: root.trayIconSize
        font.bold: Theme.fontBold
    }

    MouseArea {
        anchors.fill: parent
        visible: root.trayMode
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onContainsMouseChanged: root.setHoverPopup(containsMouse)
        onClicked: function(mouse) {
            if (!ha)
                return
            if (mouse.button === Qt.RightButton) {
                if (Util.pinHoverPopupFromBarIfActive(root.shell, root.hoverPopupId))
                    return
                ha.refresh()
                return
            }
            ha.openDashboard()
        }
    }

    BarHoverPinArea {
        visible: root.trayMode
        shell: root.shell
        popupId: root.hoverPopupId
    }

    function restartPolling() {
        if (ha && typeof ha.refresh === "function")
            ha.refresh()
    }

    onShellChanged: restartPolling()
}
