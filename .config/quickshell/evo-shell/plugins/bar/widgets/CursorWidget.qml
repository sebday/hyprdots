import QtQuick
import Quickshell
import Quickshell.Io
import "../../../Commons"

Item {
    id: root

    property var bar: null
    property var shell: null
    property var settings: ({})

    property bool loading: false
    property bool isError: false
    property string mainText: ""

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string script: home + "/.local/bin/evo-bar-cursor.sh"

    implicitWidth: label.implicitWidth + Theme.barPaddingX * 2
    implicitHeight: Theme.barHeight

    function applyJson(line) {
        loading = false
        var raw = String(line || "").trim()
        if (!raw) return
        try {
            var json = JSON.parse(raw)
            if (json.class === "error") {
                isError = true
                mainText = String(json.text || "󰆧 …")
                return
            }
            isError = false
            mainText = String(json.text || "").replace(/<[^>]+>/g, "").trim()
        } catch (e) {
            console.warn("cursor widget parse failed:", e)
        }
    }

    function poll() {
        if (!script) return
        loading = true
        proc.command = ["bash", "-lc", script]
        proc.running = false
        proc.running = true
    }

    Process {
        id: proc
        property string stdoutText: ""
        stdout: StdioCollector {
            onStreamFinished: proc.stdoutText = text
        }
        onExited: {
            root.loading = false
            root.applyJson(proc.stdoutText)
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.loading ? "󰆧 …" : root.mainText
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontPixelSize
        font.bold: Theme.fontBold
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (shell) shell.toggle("evo.cursor-usage", "")
        }
    }

    function restartPolling() {
        if (!script) return
        poll()
        intervalTimer.interval = Math.max(60, parseInt(settings.interval, 10) || 300) * 1000
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
