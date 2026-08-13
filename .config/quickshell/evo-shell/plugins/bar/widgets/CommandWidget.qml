import QtQuick
import Quickshell
import Quickshell.Io
import "../../../Commons"

Item {
    id: commandRoot
    property var bar: null
    property var barPanel: null
    property var shell: null
    property var settings: ({})
    readonly property string hoverPopupId: settings.onHover ? String(settings.onHover) : ""

    property string displayText: ""
    property string displayRichText: ""
    property bool useRichText: false
    property string className: ""
    property var lastPayload: null
    property bool polling: false
    property bool hideWhenEmpty: settings.hideEmpty === true || settings.hideEmptyText === true

    implicitWidth: (hideWhenEmpty && displayText === "") ? 0 : Math.max(label.implicitWidth, label.contentWidth) + Theme.barPaddingX * 2
    implicitHeight: Theme.barHeight

    function pangoToRichText(raw) {
        var s = String(raw || "")
        s = s.replace(/<span foreground='([^']+)'>(.*?)<\/span>/g, "<font color=\"$1\">$2</font>")
        s = s.replace(/<span foreground=\"([^\"]+)\">(.*?)<\/span>/g, "<font color=\"$1\">$2</font>")
        return s
    }

    function runExec() {
        if (!settings.exec) return
        if (settings.execIf) {
            execIfProc.command = ["bash", "-lc", String(settings.execIf)]
            execIfProc.running = false
            execIfProc.running = true
            return
        }
        startExecProc()
    }

    function startExecProc() {
        polling = true
        execProc.command = ["bash", "-lc", String(settings.exec)]
        execProc.running = false
        execProc.running = true
    }

    function applyOutput(raw) {
        polling = false
        var line = String(raw || "").trim()
        if (!line) {
            displayText = ""
            displayRichText = ""
            useRichText = false
            className = ""
            lastPayload = null
            return
        }

        if (line.charAt(0) === "{") {
            try {
                var json = JSON.parse(line)
                lastPayload = json
                var text = String(json.text || json.content || "")
                className = String(json.class || "")
                if (text.indexOf("<span") !== -1) {
                    useRichText = true
                    displayRichText = pangoToRichText(text)
                    displayText = text.replace(/<[^>]+>/g, "")
                } else {
                    useRichText = false
                    displayRichText = ""
                    displayText = text
                }
                return
            } catch (e) {
                console.warn("command widget json parse failed:", settings.id || "", e)
            }
        }

        useRichText = false
        displayRichText = ""
        displayText = line
        className = ""
        lastPayload = null
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: commandRoot.useRichText ? commandRoot.displayRichText : commandRoot.displayText
        textFormat: commandRoot.useRichText ? Text.RichText : Text.PlainText
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.barFontPixelSize
        font.bold: Theme.fontBold
        visible: !commandRoot.hideWhenEmpty || commandRoot.displayText !== ""
    }

    Process {
        id: execIfProc
        stdout: StdioCollector {
            onStreamFinished: {
                var ok = String(text || "").trim()
                if (ok) commandRoot.startExecProc()
                else commandRoot.applyOutput("")
            }
        }
    }

    Process {
        id: execProc
        property string stdoutText: ""
        property string stderrText: ""
        stdout: StdioCollector {
            onStreamFinished: execProc.stdoutText = text
        }
        stderr: StdioCollector {
            onStreamFinished: execProc.stderrText = text
        }
        onExited: {
            var raw = String(execProc.stdoutText || "").trim()
            if (!raw) raw = String(execProc.stderrText || "").trim()
            commandRoot.applyOutput(raw)
        }
    }

    Timer {
        id: intervalTimer
        interval: Math.max(1, parseInt(commandRoot.settings.interval, 10) || 5) * 1000
        repeat: true
        onTriggered: commandRoot.runExec()
    }

    function restartPolling() {
        if (!settings || !settings.exec) return
        intervalTimer.interval = Math.max(1, parseInt(settings.interval, 10) || 5) * 1000
        intervalTimer.stop()
        runExec()
        intervalTimer.start()
    }

    onSettingsChanged: restartPolling()

    HoverHandler {
        enabled: commandRoot.hoverPopupId !== ""
        onHoveredChanged: {
            if (!commandRoot.shell || !commandRoot.hoverPopupId) return
            if (hovered)
                commandRoot.shell.hoverEnter(commandRoot.hoverPopupId, commandRoot, commandRoot.barPanel)
            else
                commandRoot.shell.hoverLeave(commandRoot.hoverPopupId)
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: (settings.onClick || settings.onClickRight) ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton && settings.onClickRight)
                Quickshell.execDetached(["bash", "-lc", String(settings.onClickRight)])
            else if (settings.onClick)
                Quickshell.execDetached(["bash", "-lc", String(settings.onClick)])
        }
    }

    Component.onCompleted: restartPolling()
}
