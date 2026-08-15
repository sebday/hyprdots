import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property var host: null
    property var shell: null

    property var entries: []
    property string pendingExpr: ""
    property string lastExpr: ""
    property string lastResult: ""
    property int historyRecallIndex: -1
    property var exprHistory: []

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/evo-calculator"
    readonly property int inputFontSize: 24
    readonly property int historyFontSize: 15
    readonly property bool active: host && host.opened && host.activeModule === "calc"

    function refreshHistory() {
        if (!historyProc.running) historyProc.running = true
    }

    function parseHistory(raw) {
        var out = []
        var exprs = []
        var lines = String(raw || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (!line.trim()) continue
            var tab = line.indexOf("\t")
            if (tab < 1) continue
            var expr = line.substring(0, tab)
            var result = line.substring(tab + 1)
            out.push({
                expr: expr,
                result: result,
                label: expr + " = " + result
            })
            exprs.push(expr)
        }
        out.reverse()
        root.exprHistory = exprs
        root.historyRecallIndex = -1
        return out
    }

    function submit() {
        var expr = inputField.text.trim()
        if (!expr || evalProc.running) return
        pendingExpr = expr
        evalProc.running = true
    }

    function recallHistory(delta) {
        if (exprHistory.length === 0) return
        if (historyRecallIndex < 0) historyRecallIndex = exprHistory.length
        historyRecallIndex = Math.max(0, Math.min(exprHistory.length, historyRecallIndex + delta))
        if (historyRecallIndex >= exprHistory.length) {
            inputField.text = ""
            historyRecallIndex = -1
            return
        }
        inputField.text = exprHistory[historyRecallIndex]
        inputField.cursorPosition = inputField.text.length
    }

    function saveEntry(expr, result) {
        lastExpr = expr
        lastResult = result
        if (!addProc.running) addProc.running = true
    }

    function copyResult(result) {
        Quickshell.execDetached(["bash", "-lc", "printf '%s' " + Util.shellQuote(result) + " | wl-copy -n"])
        var notif = shell ? shell.serviceFor("evo.notifications") : null
        if (!notif || typeof notif.showBrief !== "function") return
        notif.showBrief("Calculator", "Copied " + result)
    }

    function clearHistory() {
        if (entries.length === 0 || clearProc.running) return
        clearProc.running = true
    }

    function focusInput() {
        Qt.callLater(function() {
            inputField.forceActiveFocus()
            inputField.selectAll()
        })
    }

    function onActivated(focusTarget) {
        historyRecallIndex = -1
        refreshHistory()
        tasksBlock.onActivated()
        if (focusTarget === "tasks")
            tasksBlock.focusNewTask()
        else
            focusInput()
    }

    Process {
        id: clearProc
        command: ["bash", root.script, "clear"]
        onExited: root.refreshHistory()
    }

    Process {
        id: historyProc
        command: ["bash", root.script, "history"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = root.parseHistory(text)
                Qt.callLater(function() {
                    if (historyView.count > 0)
                        historyView.positionViewAtBeginning()
                })
            }
        }
    }

    Process {
        id: evalProc
        command: ["bash", root.script, "eval", root.pendingExpr]
        stdout: StdioCollector {
            onStreamFinished: {
                var result = String(text || "").trim()
                var expr = root.pendingExpr
                root.pendingExpr = ""
                if (result && result !== "error") {
                    root.saveEntry(expr, result)
                    root.copyResult(result)
                }
                inputField.text = ""
                inputField.forceActiveFocus()
            }
        }
    }

    Process {
        id: addProc
        command: ["bash", root.script, "add", root.lastExpr, root.lastResult]
        onExited: root.refreshHistory()
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.bottom: parent.bottom
        spacing: 10

        FramedPanel {
            label: "Calculator"
            Layout.fillWidth: true

            TextInput {
                id: inputField
                width: parent.width
                height: Math.ceil(font.pixelSize * 1.45)
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.inputFontSize
                font.bold: Theme.fontBold
                selectionColor: Theme.accent
                selectedTextColor: Theme.background
                clip: false

                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.submit()
                        event.accepted = true
                    }
                }
                Keys.onEscapePressed: if (host) host.dismiss()
                Keys.onUpPressed: root.recallHistory(-1)
                Keys.onDownPressed: root.recallHistory(1)
            }
        }

        FramedPanel {
            label: "History"
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.fillHeight: false

            ListView {
                id: historyView
                width: parent.width
                height: count === 0
                    ? root.historyFontSize + 8
                    : Math.min(contentHeight, root.historyFontSize * 8)
                clip: true
                model: root.entries
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    required property var modelData
                    width: historyView.width
                    height: rowText.implicitHeight + 6

                    Text {
                        id: rowText
                        width: parent.width
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.historyFontSize
                        wrapMode: Text.Wrap
                        opacity: mouseArea.containsMouse ? 1 : 0.9
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.copyResult(modelData.result)
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: historyView.count === 0
                text: "No history yet"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.historyFontSize
                opacity: 0.5
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            Layout.topMargin: 2

            Text {
                anchors.centerIn: parent
                text: "Clear history"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.bold: Theme.fontBold
                opacity: !clearMouse.enabled ? 0.35 : (clearMouse.containsMouse ? 1 : 0.72)
            }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: root.entries.length > 0 && !clearProc.running
                onClicked: root.clearHistory()
            }
        }

        AppTasks {
            id: tasksBlock
            host: root.host
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 0
            Layout.minimumHeight: 80
        }
    }
}
