import QtQuick
import Quickshell
import Quickshell.Io
import "../../../Commons"

Item {
    id: root

    property var bar: null
    property var barPanel: null
    property var shell: null
    property var settings: ({})

    readonly property string hoverPopupId: settings.onHover
        ? String(settings.onHover)
        : (trayMode ? "evo.github" : "")
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
    readonly property string script: home + "/.local/bin/evo-bar-github"
    readonly property string trayIconText: ""
    readonly property bool trayHasContent: trayIconText !== "" || loading
    readonly property real trayIconOpacity: {
        if (loading || isError)
            return 1
        return todayCount > 0 ? 1 : 0.55
    }
    readonly property color trayIconColor: {
        if (isError)
            return Theme.urgent
        if (loading)
            return Theme.foreground
        return Format.contributionColor(todayCount)
    }

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
            if (root.shell && root.hoverPopupId)
                root.shell.setHoverPopupData(root.hoverPopupId, json)

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

    function poll() {
        if (!script) return
        loading = true
        proc.command = ["bash", "-lc", script]
        proc.running = false
        proc.running = true
    }

    function setHoverPopup(active) {
        if (!shell || !hoverPopupId) return
        if (active)
            shell.hoverEnter(hoverPopupId, root, barPanel)
        else
            shell.hoverLeave(hoverPopupId)
    }

    function openGithub() {
        if (settings.onClick)
            Quickshell.execDetached(["bash", "-lc", String(settings.onClick)])
        else
            Quickshell.execDetached(["xdg-open", "https://github.com/sebday"])
    }

    Text {
        id: trayIcon
        anchors.centerIn: parent
        visible: root.trayMode && root.trayHasContent
        text: root.trayIconText
        color: root.trayIconColor
        opacity: root.trayIconOpacity
        font.family: Theme.fontFamily
        font.pixelSize: root.trayIconSize
        font.bold: Theme.fontBold
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Theme.sparklineGap
        visible: !root.trayMode

        Text {
            text: root.loading ? " …" : root.isError ? root.statusText : "  " + root.todayCount
            color: Theme.foreground
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
                    color: modelData.color || Theme.foreground
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
        anchors.fill: parent
        visible: root.trayMode
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: root.setHoverPopup(containsMouse)
        onClicked: root.openGithub()
    }

    HoverHandler {
        enabled: !root.trayMode && root.hoverPopupId !== "" && root.shell
        onHoveredChanged: root.setHoverPopup(hovered)
    }

    MouseArea {
        anchors.fill: parent
        visible: !root.trayMode
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openGithub()
    }

    function restartPolling() {
        if (!script) return
        poll()
        intervalTimer.interval = Math.max(1, parseInt(settings.interval, 10) || 300) * 1000
        intervalTimer.stop()
        intervalTimer.start()
    }

    Timer {
        id: intervalTimer
        interval: 300000
        repeat: true
        onTriggered: root.poll()
    }

    onSettingsChanged: restartPolling()
    Component.onCompleted: restartPolling()
}
