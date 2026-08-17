import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../Commons"

Item {
    id: root

    property var bar: null
    property var barPanel: null
    property var shell: null
    property var settings: ({})

    property int cpuPercent: 0
    property string detailText: "…"
    property var lastPayload: null

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string script: home + "/.local/bin/evo-bar-system"
    readonly property string btopScript: home + "/.local/bin/evo-bar-btop"
    readonly property string hoverPopupId: settings.onHover ? String(settings.onHover) : "evo.system"
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
        } catch (e) {
            console.warn("system widget parse failed:", e)
        }
    }

    function publishCache(json) {
        if (!shell || !hoverPopupId || !json)
            return
        shell.setHoverPopupData(hoverPopupId, json)
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

    function swapShopifyBtop() {
        Quickshell.execDetached(["bash", btopScript, "swap"])
    }

    function setHoverPopup(active) {
        if (!shell || !hoverPopupId)
            return
        if (active)
            shell.hoverEnter(hoverPopupId, root, barPanel)
        else
            shell.hoverLeave(hoverPopupId)
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            id: cpuIconText
            text: root.cpuIcon
            color: root.cpuColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeM
            font.bold: Theme.fontBold
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
            opacity: 0.92
        }
    }

    HoverHandler {
        enabled: root.hoverPopupId !== "" && root.shell
        onHoveredChanged: root.setHoverPopup(hovered)
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.swapShopifyBtop()
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

    onSettingsChanged: restartPolling()
    onShellChanged: {
        if (lastPayload)
            publishCache(lastPayload)
    }
    Component.onCompleted: restartPolling()
}
