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
        : (trayMode ? "evo.panels.stocks" : "")
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
    readonly property string btcCacheKey: "evo.panels.stocks.btc"
    readonly property string spcxCacheKey: "evo.panels.stocks.spcx"
    readonly property int chartHistoryDays: 30
    readonly property string trayIconText: "󰄪"

    implicitWidth: trayMode ? trayCellWidth : trayIconSize + Theme.barPaddingX * 2
    implicitHeight: Theme.barHeight
    width: trayMode && parent ? parent.width : implicitWidth
    height: Theme.barHeight

    function setHoverPanel(active) {
        if (!shell || !hoverPanelId) return
        if (active)
            shell.hoverEnter(hoverPanelId, root, barPanel)
        else
            shell.hoverLeave(hoverPanelId)
    }

    JsonPollRunner {
        id: btcPoll
        shell: root.shell
        cacheKey: root.btcCacheKey
        settings: root.settings
        defaultIntervalSec: 60
        command: [Util.evoshellScript(home, shell, "evo-bar-btc"), String(root.chartHistoryDays)]
    }

    JsonPollRunner {
        id: spcxPoll
        shell: root.shell
        cacheKey: root.spcxCacheKey
        settings: root.settings
        defaultIntervalSec: 60
        command: [Util.evoshellScript(home, shell, "evo-bar-spcx"), String(root.chartHistoryDays)]
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
        onContainsMouseChanged: root.setHoverPanel(containsMouse)
    }

    BarHoverPinArea {
        visible: root.trayMode
        shell: root.shell
        popupId: root.hoverPanelId
    }
}
