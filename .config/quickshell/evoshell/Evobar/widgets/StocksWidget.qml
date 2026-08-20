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
        : (trayMode ? "evo.bar.popups.stocks" : "")
    readonly property bool trayMode: settings.trayMode === true
    readonly property int trayIconSize: {
        var n = parseInt(settings.trayIconSize, 10)
        return isNaN(n) || n <= 0 ? 18 : n
    }
    readonly property int trayCellWidth: {
        var n = parseInt(settings.trayCellWidth, 10)
        return isNaN(n) || n <= 0 ? trayIconSize + 4 : n
    }

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string btcCacheKey: "evo.bar.popups.stocks.btc"
    readonly property string spcxCacheKey: "evo.bar.popups.stocks.spcx"
    readonly property int chartHistoryDays: 30
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

    JsonPollRunner {
        id: btcPoll
        shell: root.shell
        cacheKey: root.btcCacheKey
        settings: root.settings
        defaultIntervalSec: 60
        command: ["bash", root.home + "/.local/bin/evo-bar-btc", String(root.chartHistoryDays)]
    }

    JsonPollRunner {
        id: spcxPoll
        shell: root.shell
        cacheKey: root.spcxCacheKey
        settings: root.settings
        defaultIntervalSec: 60
        command: ["bash", root.home + "/.local/bin/evo-bar-spcx", String(root.chartHistoryDays)]
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

    BarHoverPinArea {
        visible: root.trayMode
        shell: root.shell
        popupId: root.hoverPopupId
    }
}
