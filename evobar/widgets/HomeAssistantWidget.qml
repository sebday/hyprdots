import QtQuick
import Quickshell
import "../../commons"

Item {
    id: root

    property var bar: null
    property var barPanel: null
    property var shell: null
    property var settings: ({})

    readonly property string hoverPanelId: settings.onHover
        ? String(settings.onHover)
        : (trayMode ? "evo.panels.homeassistant" : "")
    readonly property bool trayMode: settings.trayMode === true
    readonly property int trayIconSize: {
        var n = parseInt(settings.trayIconSize, 10)
        return isNaN(n) || n <= 0 ? 18 : n
    }
    readonly property int trayCellWidth: {
        var n = parseInt(settings.trayCellWidth, 10)
        return isNaN(n) || n <= 0 ? trayIconSize + 4 : n
    }

    readonly property var ha: shell ? shell.serviceFor("evo.panels.homeassistant") : null
    readonly property bool configured: ha && ha.configured
    readonly property bool warningState: ha && ha.warning
    readonly property bool heatingActive: ha && ha.heatingActive
    readonly property bool busy: ha && ha.busy
    readonly property string trayIconText: "󰚡"
    readonly property bool attentionPulse: !root.configured || root.warningState || root.heatingActive

    implicitWidth: trayMode ? trayCellWidth : trayIconSize + Theme.barPaddingX * 2
    implicitHeight: Theme.barHeight
    width: trayMode && parent ? parent.width : implicitWidth
    height: Theme.barHeight

    function setHoverPanel(active) {
        if (!shell || !hoverPanelId)
            return
        if (active)
            shell.hoverEnter(hoverPanelId, root, barPanel)
        else
            shell.hoverLeave(hoverPanelId)
    }

    Text {
        id: trayIcon
        anchors.centerIn: parent
        visible: root.trayMode
        text: root.trayIconText
        opacity: root.attentionPulse
            ? Theme.barIconPulseMax
            : (root.busy ? 0.55 : Theme.barIconOpacity)
        font.family: Theme.fontFamily
        font.pixelSize: root.trayIconSize
        font.bold: Theme.fontBold
    }

    BarIconPulse {
        target: trayIcon
        running: root.trayMode && root.attentionPulse && !root.busy
    }

    MouseArea {
        anchors.fill: parent
        visible: root.trayMode
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onContainsMouseChanged: root.setHoverPanel(containsMouse)
        onClicked: function(mouse) {
            if (!ha)
                return
            if (mouse.button === Qt.RightButton) {
                if (Util.pinHoverPanelFromBarIfActive(root.shell, root.hoverPanelId))
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
        popupId: root.hoverPanelId
    }

    function restartPolling() {
        if (ha && typeof ha.refresh === "function")
            ha.refresh()
    }

    onShellChanged: restartPolling()
}
