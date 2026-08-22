import QtQuick
import Quickshell
import Quickshell.Io
import "../../commons"

Item {
    id: root

    property var bar: null
    property var barPanel: null
    property var shell: null
    property var settings: ({})

    readonly property string hoverPanelId: settings.onHover
        ? String(settings.onHover)
        : (trayMode ? "evo.panels.github" : "")
    readonly property bool trayMode: settings.trayMode === true
    readonly property int trayIconSize: {
        var n = parseInt(settings.trayIconSize, 10)
        return isNaN(n) || n <= 0 ? 18 : n
    }
    readonly property int trayCellWidth: {
        var n = parseInt(settings.trayCellWidth, 10)
        return isNaN(n) || n <= 0 ? trayIconSize + 4 : n
    }

    property bool loading: false
    property bool isError: false
    property string statusText: ""
    property int todayCount: 0
    property var cells: []
    property var lastPayload: null

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string script: Util.evoshellScript(home, shell, "evo-bar-github")
    readonly property string trayIconText: ""
    readonly property bool trayHasContent: loading || (lastPayload !== null && !isError)
    readonly property real trayIconOpacity: {
        if (loading || isError || attentionPulse)
            return Theme.barIconPulseMax
        if (todayCount > 0)
            return Theme.barIconOpacityActive
        return Theme.barIconOpacityDim
    }
    readonly property bool attentionPulse: root.isError

    implicitWidth: trayMode ? trayCellWidth : contentRow.implicitWidth + Theme.barPaddingX * 2
    implicitHeight: Theme.barHeight
    width: trayMode && parent ? parent.width : implicitWidth
    height: Theme.barHeight

    function applyJson(line) {
        loading = false
        var raw = String(line || "").trim()
        if (!raw) {
            lastPayload = null
            return
        }
        try {
            var json = JSON.parse(raw)
            lastPayload = json
            if (root.shell && root.hoverPanelId)
                Util.hoverPanelCacheWrite(root.shell, root.hoverPanelId, json)

            if (json.class === "error") {
                isError = true
                statusText = String(json.tooltip || json.text || "GitHub error").replace(/<[^>]+>/g, "").trim()
                cells = []
                return
            }

            isError = false
            statusText = ""
            todayCount = parseInt(json.today, 10) || 0
            cells = Array.isArray(json.cells) ? json.cells : []
        } catch (e) {
            console.warn("github widget parse failed:", e)
            lastPayload = null
        }
    }

    function bootstrapFromCache() {
        if (!shell || !hoverPanelId)
            return false
        var cached = Util.hoverPanelCacheRead(shell, hoverPanelId)
        if (!cached)
            return false
        applyJson(JSON.stringify(cached))
        return true
    }

    function poll() {
        if (!script) return
        loading = true
        proc.command = ["bash", "-lc", script]
        proc.running = false
        proc.running = true
    }

    function setHoverPanel(active) {
        if (!shell || !hoverPanelId) return
        if (active)
            shell.hoverEnter(hoverPanelId, root, barPanel)
        else
            shell.hoverLeave(hoverPanelId)
    }

    function openGithub() {
        Util.dismissHoverPanelFromBar(shell, hoverPanelId)
        if (settings.onClick)
            Quickshell.execDetached(["bash", "-lc", String(settings.onClick)])
        else {
            var url = lastPayload && lastPayload.profileUrl
                ? String(lastPayload.profileUrl)
                : "https://github.com/"
            Quickshell.execDetached(["xdg-open", url])
        }
    }

    Text {
        id: trayIcon
        anchors.centerIn: parent
        visible: root.trayMode && root.trayHasContent
        text: root.trayIconText
        opacity: root.trayIconOpacity
        font.family: Theme.fontFamily
        font.pixelSize: root.trayIconSize
        font.bold: Theme.fontBold
    }

    BarIconPulse {
        target: trayIcon
        running: root.trayMode && root.attentionPulse
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Theme.sparklineGap
        visible: !root.trayMode

        Row {
            spacing: 0
            visible: !root.loading && !root.isError

            Text {
                text: "  "
                color: Theme.barIconColor
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeM
                font.bold: Theme.fontBold
            }

            Text {
                text: String(root.todayCount)
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeM
                font.bold: Theme.fontBold
            }
        }

        Text {
            visible: root.loading || root.isError
            text: root.loading ? " …" : root.statusText
            color: Theme.barIconColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeM
            font.bold: Theme.fontBold
        }

        Row {
            id: nativeHeatmap
            spacing: Theme.sparklineBarSpacing
            visible: !root.loading && root.cells.length > 0
            height: Theme.sparklineCellSize
            anchors.verticalCenter: parent.verticalCenter

            Item {
                width: Theme.sparklineChartMargin
                height: 1
            }

            Repeater {
                model: root.cells
                Rectangle {
                    required property var modelData
                    width: Theme.sparklineCellSize
                    height: Theme.sparklineCellSize
                    color: modelData.color
                        || Theme.heatmapColors[Math.max(0, Math.min(4, parseInt(modelData.level, 10) || 0))]
                        || Theme.foreground
                }
            }
        }
    }

    Process {
        id: proc
        property string stdoutText: ""
        property string stderrText: ""
        stdout: StdioCollector {
            onStreamFinished: proc.stdoutText = text
        }
        stderr: StdioCollector {
            onStreamFinished: proc.stderrText = text
        }
        onExited: {
            root.loading = false
            var raw = String(proc.stdoutText || "").trim()
            if (!raw) raw = String(proc.stderrText || "").trim()
            root.applyJson(raw)
        }
    }

    MouseArea {
        id: trayMouseArea
        anchors.fill: parent
        visible: root.trayMode && root.trayHasContent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: root.setHoverPanel(containsMouse)
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                if (Util.pinHoverPanelFromBarIfActive(root.shell, root.hoverPanelId))
                    return
                return
            }
            root.openGithub()
        }
    }

    HoverHandler {
        enabled: !root.trayMode && root.hoverPanelId !== "" && root.shell
        onHoveredChanged: root.setHoverPanel(hovered)
    }

    MouseArea {
        id: barMouseArea
        anchors.fill: parent
        visible: !root.trayMode
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                if (Util.pinHoverPanelFromBarIfActive(root.shell, root.hoverPanelId))
                    return
                return
            }
            root.openGithub()
        }
    }

    function restartPolling() {
        if (!script) return
        poll()
        intervalTimer.interval = Theme.pollGithubSec * 1000
        intervalTimer.stop()
        intervalTimer.start()
    }

    Timer {
        id: intervalTimer
        interval: Theme.pollGithubSec * 1000
        repeat: true
        onTriggered: root.poll()
    }

    onSettingsChanged: restartPolling()
    onShellChanged: bootstrapFromCache()
    Component.onCompleted: {
        bootstrapFromCache()
        restartPolling()
    }
}
