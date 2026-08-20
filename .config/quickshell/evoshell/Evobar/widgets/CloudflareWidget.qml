import QtQuick
import Quickshell
import "../../Commons"
import "../Popups/Cloudflare"

Item {
    id: root

    property var bar: null
    property var barPanel: null
    property var shell: null
    property var settings: ({})

    readonly property string hoverPopupId: settings.onHover
        ? String(settings.onHover)
        : (trayMode ? "evo.bar.popups.cloudflare" : "")
    readonly property bool trayMode: settings.trayMode === true
    readonly property int trayIconSize: {
        var n = parseInt(settings.trayIconSize, 10)
        return isNaN(n) || n <= 0 ? 18 : n
    }
    readonly property int trayCellWidth: {
        var n = parseInt(settings.trayCellWidth, 10)
        return isNaN(n) || n <= 0 ? trayIconSize + 4 : n
    }

    readonly property var cf: shell ? shell.serviceFor("evo.bar.popups.cloudflare") : null
    readonly property bool loggedIn: cf && cf.loggedIn
    readonly property bool warningState: cf && cf.warning
    readonly property bool busy: cf && cf.busy

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

    CloudflareIcon {
        id: trayIcon
        anchors.centerIn: parent
        visible: root.trayMode
        iconSize: root.trayIconSize
        color: root.loggedIn ? Theme.foreground : Theme.urgent
        badgeColor: Theme.urgent
        crossed: !root.loggedIn
        warning: root.loggedIn && root.warningState
        busy: root.busy
    }

    MouseArea {
        id: trayMouseArea
        anchors.fill: parent
        visible: root.trayMode
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onContainsMouseChanged: root.setHoverPopup(containsMouse)
        onClicked: function(mouse) {
            if (!cf)
                return
            if (mouse.button === Qt.RightButton) {
                if (Util.pinHoverPopupFromBarIfActive(root.shell, root.hoverPopupId))
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
