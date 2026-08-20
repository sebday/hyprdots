import QtQuick
import Quickshell
import Quickshell.Io
import "../../Commons"

Item {
    id: commandRoot
    property var bar: null
    property var barPanel: null
    property var shell: null
    property var settings: ({})
    readonly property string hoverPopupId: settings.onHover ? String(settings.onHover) : ""
    readonly property bool trayMode: settings.trayMode === true
    readonly property int trayIconSize: {
        var n = parseInt(settings.trayIconSize, 10)
        return isNaN(n) || n <= 0 ? 18 : n
    }
    readonly property int trayCellWidth: {
        var n = parseInt(settings.trayCellWidth, 10)
        return isNaN(n) || n <= 0 ? trayIconSize + 4 : n
    }
    readonly property string trayDisplay: {
        if (settings.trayDisplay)
            return String(settings.trayDisplay)
        if (hoverPopupId === "evo.bar.popups.cursor-usage")
            return "dial"
        if (hoverPopupId === "evo.bar.popups.weather")
            return "icon"
        return "text"
    }
    readonly property real trayDialPercent: {
        if (!lastPayload || lastPayload.cursorPercent === undefined)
            return 0
        var n = Number(lastPayload.cursorPercent)
        return isFinite(n) ? Math.max(0, Math.min(100, n)) : 0
    }

    property string displayText: ""
    property string displayRichText: ""
    property bool useRichText: false
    property string className: ""
    property var lastPayload: null
    property bool polling: false
    property bool hideWhenEmpty: settings.hideEmpty === true || settings.hideEmptyText === true

    readonly property string tooltipText: lastPayload && lastPayload.tooltip
        ? String(lastPayload.tooltip).trim()
        : ""
    readonly property bool iconOnly: {
        if (className === "icon")
            return true
        var t = displayText
        if (!t || t.length !== 1)
            return false
        var code = t.charCodeAt(0)
        return code >= 0xE000
    }

    function leadingIconFromText(text) {
        var t = String(text || "")
        if (!t)
            return ""
        if (t.charCodeAt(0) >= 0xE000)
            return t.charAt(0)
        return ""
    }

    readonly property string trayIconText: {
        if (!trayMode)
            return ""
        if (lastPayload && lastPayload.current && lastPayload.current.icon)
            return String(lastPayload.current.icon)
        if (lastPayload && lastPayload.cursorPercent !== undefined)
            return leadingIconFromText(displayText) || "󰆧"
        if (lastPayload && lastPayload.trayIcon)
            return String(lastPayload.trayIcon)
        return leadingIconFromText(displayText)
    }

    readonly property string trayValueText: {
        if (!trayMode)
            return ""
        if (lastPayload && lastPayload.current && lastPayload.current.temp !== undefined)
            return String(lastPayload.current.temp) + "°"
        if (lastPayload && lastPayload.cursorPercent !== undefined)
            return String(lastPayload.cursorPercent) + "%"
        if (lastPayload && lastPayload.trayValue !== undefined)
            return String(lastPayload.trayValue)
        return ""
    }

    readonly property bool trayHasContent: {
        if (polling)
            return true
        if (trayDisplay === "dial")
            return lastPayload !== null
        if (trayDisplay === "icon")
            return trayIconText !== ""
        return trayIconText !== "" || trayValueText !== ""
    }

    readonly property color trayIconColor: {
        if (polling)
            return Theme.foreground
        if (hoverPopupId === "evo.bar.popups.weather" && lastPayload && lastPayload.current)
            return Format.tempColor(lastPayload.current.temp)
        if (hoverPopupId === "evo.bar.popups.cursor-usage" && lastPayload && lastPayload.cursorPercent !== undefined)
            return Format.usagePercentColor(lastPayload.cursorPercent)
        return Theme.foreground
    }

    implicitWidth: {
        if (trayMode) {
            if (hideWhenEmpty && !trayHasContent)
                return 0
            if (trayDisplay === "icon" || trayDisplay === "dial")
                return trayCellWidth
            return Math.max(trayTextRow.implicitWidth, trayIconSize)
        }
        if (hideWhenEmpty && displayText === "")
            return 0
        var textWidth = Math.max(label.implicitWidth, label.contentWidth)
        if (iconOnly)
            textWidth = Math.max(textWidth, Theme.fontSizeM)
        return textWidth + Theme.barPaddingX * 2
    }
    implicitHeight: Theme.barHeight
    width: trayMode && parent ? parent.width : implicitWidth
    height: Theme.barHeight

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
        if (!lastPayload)
            polling = true
        execProc.command = ["bash", "-lc", String(settings.exec)]
        execProc.running = false
        execProc.running = true
    }

    function applyJsonPayload(json) {
        lastPayload = json
        if (commandRoot.shell && commandRoot.hoverPopupId)
            Util.hoverPopupCacheWrite(commandRoot.shell, commandRoot.hoverPopupId, json)
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
    }

    function bootstrapFromCache() {
        if (!shell || !hoverPopupId)
            return false
        var cached = Util.hoverPopupCacheRead(shell, hoverPopupId)
        if (!cached || typeof cached !== "object")
            return false
        applyJsonPayload(cached)
        return true
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
                applyJsonPayload(JSON.parse(line))
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

    function setHoverPopup(active) {
        if (!shell || !hoverPopupId) return
        if (active)
            shell.hoverEnter(hoverPopupId, commandRoot, barPanel)
        else
            shell.hoverLeave(hoverPopupId)
    }

    function handleClick(mouse) {
        if (mouse.button === Qt.RightButton) {
            if (Util.pinHoverPopupFromBarIfActive(shell, hoverPopupId))
                return
            if (settings.onClickRight) {
                Util.dismissHoverPopupFromBar(shell, hoverPopupId)
                Quickshell.execDetached(["bash", "-lc", String(settings.onClickRight)])
            }
            return
        }
        if (settings.onClick) {
            Util.dismissHoverPopupFromBar(shell, hoverPopupId)
            Quickshell.execDetached(["bash", "-lc", String(settings.onClick)])
        }
    }

    Item {
        id: trayHost
        anchors.centerIn: parent
        visible: commandRoot.trayMode && commandRoot.trayHasContent
        width: commandRoot.trayDisplay === "text"
            ? trayTextRow.implicitWidth
            : commandRoot.trayCellWidth
        height: Theme.barHeight

        Row {
            id: trayTextRow
            anchors.centerIn: parent
            height: parent.height
            spacing: 3
            visible: commandRoot.trayDisplay === "text"

            Text {
                height: trayTextRow.height
                verticalAlignment: Text.AlignVCenter
                text: commandRoot.trayIconText
                color: commandRoot.trayIconColor
                font.family: Theme.fontFamily
                font.pixelSize: commandRoot.trayIconSize
                font.bold: Theme.fontBold
            }

            Text {
                height: trayTextRow.height
                verticalAlignment: Text.AlignVCenter
                text: commandRoot.trayValueText
                visible: commandRoot.trayValueText !== ""
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                font.bold: Theme.fontBold
            }
        }

        Text {
            anchors.centerIn: parent
            visible: commandRoot.trayDisplay === "icon"
            text: commandRoot.trayIconText
            color: commandRoot.trayIconColor
            font.family: Theme.fontFamily
            font.pixelSize: commandRoot.trayIconSize
            font.bold: Theme.fontBold
        }

        TrayUsageDial {
            anchors.centerIn: parent
            visible: commandRoot.trayDisplay === "dial"
            size: commandRoot.trayIconSize
            percent: commandRoot.trayDialPercent
            color: commandRoot.trayIconColor
            lineWidth: 3
            loading: commandRoot.polling
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        visible: !commandRoot.trayMode
            && (!commandRoot.hideWhenEmpty || commandRoot.displayText !== "")
        text: commandRoot.useRichText ? commandRoot.displayRichText : commandRoot.displayText
        textFormat: commandRoot.useRichText ? Text.RichText : Text.PlainText
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: commandRoot.iconOnly ? Theme.fontSize2xl : Theme.fontSizeM
        font.bold: Theme.fontBold && !commandRoot.iconOnly
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
        bootstrapFromCache()
        runExec()
        intervalTimer.start()
    }

    onShellChanged: bootstrapFromCache()

    onSettingsChanged: restartPolling()

    MouseArea {
        id: trayMouseArea
        anchors.fill: parent
        visible: commandRoot.trayMode
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: (settings.onClick || settings.onClickRight) ? Qt.PointingHandCursor : Qt.ArrowCursor
        onContainsMouseChanged: commandRoot.setHoverPopup(containsMouse)
        onClicked: function(mouse) { commandRoot.handleClick(mouse) }
    }

    HoverHandler {
        enabled: !commandRoot.trayMode && commandRoot.hoverPopupId !== "" && commandRoot.shell
        onHoveredChanged: commandRoot.setHoverPopup(hovered)
    }

    MouseArea {
        id: barMouseArea
        anchors.fill: parent
        visible: !commandRoot.trayMode
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: (settings.onClick || settings.onClickRight) ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: function(mouse) { commandRoot.handleClick(mouse) }
    }

    Component.onCompleted: restartPolling()
}
