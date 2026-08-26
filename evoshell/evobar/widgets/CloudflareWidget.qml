import QtQuick
import Quickshell
import "../../commons"
import "../../evopanels/cloudflare"

Item {
    id: root

    property var bar: null
    property var barPanel: null
    property var shell: null
    property var settings: ({})

    readonly property string hoverPanelId: settings.onHover
        ? String(settings.onHover)
        : (trayMode ? "evo.panels.cloudflare" : "")
    readonly property bool trayMode: settings.trayMode === true
    readonly property int trayIconSize: {
        var n = parseInt(settings.trayIconSize, 10)
        return isNaN(n) || n <= 0 ? 18 : n
    }
    readonly property int trayCellWidth: {
        var n = parseInt(settings.trayCellWidth, 10)
        return isNaN(n) || n <= 0 ? trayIconSize + 4 : n
    }

    readonly property var cf: shell ? shell.serviceFor("evo.panels.cloudflare") : null
    readonly property bool loggedIn: cf && cf.loggedIn
    readonly property bool warningState: cf && cf.warning
    readonly property bool busy: cf && cf.busy
    readonly property bool attentionPulse: !root.loggedIn || root.warningState

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

    CloudflareIcon {
        id: trayIcon
        anchors.centerIn: parent
        visible: root.trayMode
        iconSize: root.trayIconSize
        badgeColor: Theme.urgent
        crossed: !root.loggedIn
        warning: root.loggedIn && root.warningState
        busy: root.busy
        opacity: root.attentionPulse
            ? Theme.barIconPulseMax
            : (root.busy ? 0.55 : Theme.barIconOpacity)
    }

    BarIconPulse {
        target: trayIcon
        running: root.trayMode && root.attentionPulse && !root.busy
    }

    MouseArea {
        id: trayMouseArea
        anchors.fill: parent
        visible: root.trayMode
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onContainsMouseChanged: root.setHoverPanel(containsMouse)
        onClicked: function(mouse) {
            if (!cf)
                return
            if (mouse.button === Qt.RightButton) {
                if (Util.pinHoverPanelFromBarIfActive(root.shell, root.hoverPanelId))
                    return
                cf.refresh()
                cf.refreshAnalytics()
                return
            }
            if (mouse.button === Qt.MiddleButton) {
                cf.openUrl("https://dash.cloudflare.com/?to=/:account/workers")
                return
            }
            cf.openUrl("https://dash.cloudflare.com")
        }
    }

    function restartPolling() {}

    onShellChanged: {
        if (cf && typeof cf.refresh === "function")
            cf.refresh()
    }
}
