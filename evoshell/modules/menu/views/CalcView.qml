import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs.commons
import "../LauncherSources.js" as LauncherSources

Item {
    id: root

    property var shell: null
    property string expression: ""
    property var entries: []
    property var exprHistory: []
    property int historyRecallIndex: -1
    property string lastExpr: ""
    property string lastResult: ""

    signal recalled(string text)

    readonly property string script: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-calculator")
    readonly property var live: LauncherSources.calculatorEntry(expression)
    readonly property int highlightedHistory: {
        if (historyRecallIndex < 0 || historyRecallIndex >= exprHistory.length)
            return -1
        return entries.length - 1 - historyRecallIndex
    }

    function refresh() {
        if (!historyProc.running)
            historyProc.running = true
    }

    function parseHistory(raw) {
        var out = []
        var exprs = []
        var lines = String(raw || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (!line.trim())
                continue
            var tab = line.indexOf("\t")
            if (tab < 1)
                continue
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

    function recall(delta) {
        if (exprHistory.length === 0)
            return
        if (historyRecallIndex < 0)
            historyRecallIndex = exprHistory.length
        historyRecallIndex = Math.max(0, Math.min(exprHistory.length, historyRecallIndex + delta))
        if (historyRecallIndex >= exprHistory.length) {
            historyRecallIndex = -1
            root.recalled("")
            return
        }
        root.recalled(exprHistory[historyRecallIndex])
    }

    function remember(expr, result) {
        lastExpr = String(expr || "")
        lastResult = String(result || "")
        if (!lastExpr || !lastResult || addProc.running)
            return
        addProc.running = true
    }

    function clearHistory() {
        if (entries.length === 0 || clearProc.running)
            return
        clearProc.running = true
    }

    function useEntry(entry) {
        if (!entry)
            return
        var expr = String(entry.expr || "")
        for (var i = 0; i < exprHistory.length; i++) {
            if (exprHistory[i] === expr) {
                historyRecallIndex = i
                break
            }
        }
        root.recalled(expr)
    }

    Process {
        id: clearProc
        command: ["bash", root.script, "clear"]
        onExited: root.refresh()
    }

    Process {
        id: historyProc
        command: ["bash", root.script, "history"]
        stdout: StdioCollector {
            onStreamFinished: root.entries = root.parseHistory(text)
        }
    }

    Process {
        id: addProc
        command: ["bash", root.script, "add", root.lastExpr, root.lastResult]
        onExited: root.refresh()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingM

        Text {
            visible: root.live !== null
            Layout.fillWidth: true
            text: root.live ? root.live.result : ""
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize6xl
            font.bold: Theme.fontBold
            elide: Text.ElideRight
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: historyView
                anchors.fill: parent
                clip: true
                model: root.entries
                boundsBehavior: Flickable.StopAtBounds
                spacing: 2

                delegate: Rectangle {
                    id: historyRow
                    required property var modelData
                    required property int index
                    width: historyView.width
                    height: rowText.implicitHeight + 10
                    radius: Theme.cornerRadius
                    color: index === root.highlightedHistory || rowMouse.containsMouse
                        ? Theme.foregroundWash
                        : "transparent"

                    Text {
                        id: rowText
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        text: historyRow.modelData ? historyRow.modelData.label : ""
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeS
                        font.bold: Theme.fontBold
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.useEntry(historyRow.modelData)
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: historyView.count === 0
                text: "No history yet"
                color: Theme.foreground
                opacity: Theme.opacityMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                font.bold: Theme.fontBold
            }
        }
    }
}
