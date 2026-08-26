import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../commons"

Item {
    id: root

    property var bar: null
    property var barPanel: null
    property var shell: null
    property var settings: ({})

    property int cpuPercent: 0
    property string detailText: "…"
    property var lastPayload: null
    property bool widgetHovered: false
    property real highLoadSince: 0
    property bool loadAlertActive: false

    readonly property int loadAlertThreshold: 80
    readonly property int loadClearThreshold: 75
    readonly property int loadAlertDurationMs: 30000

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string script: Util.evoshellScript(home, shell, "evo-bar-system")
    readonly property string hoverPanelId: settings.onHover ? String(settings.onHover) : "evo.panels.system"
    readonly property string cpuIcon: "󰍛"
    readonly property color cpuColor: Format.loadPercentColor(cpuPercent)

    implicitWidth: contentRow.implicitWidth + Theme.barPaddingX * 2
    implicitHeight: Theme.barHeight

    function applyJson(line) {
        var raw = String(line || "").trim()
        if (!raw) {
            return
        }
        try {
            var json = JSON.parse(raw)
            lastPayload = json
            cpuPercent = parseInt(json.cpuPercent, 10) || 0
            detailText = json.detail ? String(json.detail) : "—"
            publishCache(json)
            updateLoadAlert(cpuPercent)
        } catch (e) {
            console.warn("system widget parse failed:", e)
        }
    }

    function publishCache(json) {
        if (!shell || !hoverPanelId || !json)
            return
        Util.hoverPanelCacheWrite(shell, hoverPanelId, json)
    }

    function bootstrapFromCache() {
        if (!shell || !hoverPanelId)
            return false
        var cached = Util.hoverPanelCacheRead(shell, hoverPanelId)
        if (!cached)
            return false
        try {
            lastPayload = cached
            cpuPercent = parseInt(cached.cpuPercent, 10) || 0
            detailText = cached.detail ? String(cached.detail) : "—"
            updateLoadAlert(cpuPercent)
            return true
        } catch (e) {
            return false
        }
    }

    function updateLoadAlert(pct) {
        var now = Date.now()
        if (pct > loadAlertThreshold) {
            if (highLoadSince <= 0)
                highLoadSince = now
            else if (!loadAlertActive && (now - highLoadSince) >= loadAlertDurationMs)
                loadAlertActive = true
        } else if (pct < loadClearThreshold) {
            highLoadSince = 0
            loadAlertActive = false
        }
        syncHoverPanel()
    }

    function syncHoverPanel() {
        if (!shell || !hoverPanelId)
            return
        if (widgetHovered || loadAlertActive)
            shell.hoverEnter(hoverPanelId, root, barPanel)
        else
            shell.hoverLeave(hoverPanelId)
    }

    function poll() {
        if (!script) return
        proc.command = ["bash", "-lc", script]
        proc.running = false
        proc.running = true
    }

    function restartPolling() {
        intervalTimer.interval = Math.max(1, parseInt(settings.interval, 10) || 5) * 1000
        intervalTimer.stop()
        poll()
        intervalTimer.start()
    }

    function openBtop() {
        Util.dismissHoverPanelFromBar(shell, hoverPanelId)
        if (settings.onClick)
            Quickshell.execDetached(["bash", "-lc", String(settings.onClick)])
        else
            Util.execDetachedTui(["ghostty", "--class=TUI.main", "-e", "btop"])
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: Theme.spacingS

        TrayUsageDial {
            size: 17
            percent: root.cpuPercent
            color: root.cpuColor
            lineWidth: 1.75
            showDot: true
            centerIcon: root.cpuIcon
            Layout.alignment: Qt.AlignVCenter

            Behavior on color {
                ColorAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
        }

        Text {
            text: root.detailText || "…"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeM
            font.bold: Theme.fontBold
            Layout.alignment: Qt.AlignVCenter
            opacity: Theme.opacityEmphasis2
        }
    }

    MouseArea {
        id: rootMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openBtop()
    }

    HoverHandler {
        enabled: root.hoverPanelId !== "" && root.shell
        onHoveredChanged: {
            root.widgetHovered = hovered
            root.syncHoverPanel()
        }
    }

    BarHoverPinArea {
        shell: root.shell
        popupId: root.hoverPanelId
    }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: root.applyJson(text)
        }
    }

    Timer {
        id: intervalTimer
        interval: Math.max(1, parseInt(root.settings.interval, 10) || 5) * 1000
        repeat: true
        onTriggered: root.poll()
    }

    onLoadAlertActiveChanged: syncHoverPanel()
    onSettingsChanged: restartPolling()
    onShellChanged: bootstrapFromCache()
    Component.onCompleted: {
        bootstrapFromCache()
        restartPolling()
    }
}
