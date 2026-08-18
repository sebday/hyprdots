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
    readonly property int inputFontSize: Theme.fontSize6xl
    readonly property int historyFontSize: Theme.fontSizeL
    readonly property bool active: host && host.opened && host.activeModule === "calc"

    property string flashDigit: ""

    function flashDigitKey(digit) {
        if (!digit) return
        flashDigit = digit
        flashTimer.restart()
    }

    function digitFromKey(key) {
        if (key >= Qt.Key_0 && key <= Qt.Key_9)
            return String(key - Qt.Key_0)
        if (key >= Qt.Key_Keypad0 && key <= Qt.Key_Keypad9)
            return String(key - Qt.Key_Keypad0)
        return ""
    }

    Timer {
        id: flashTimer
        interval: 140
        repeat: false
        onTriggered: root.flashDigit = ""
    }

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

    function focusInput(selectAll) {
        var all = selectAll !== false
        function apply() {
            if (!root.active) return
            inputField.forceActiveFocus()
            if (all)
                inputField.selectAll()
        }
        Qt.callLater(apply)
        focusRetryTimer.selectAll = all
        focusRetryTimer.restart()
    }

    Timer {
        id: focusRetryTimer
        property bool selectAll: true
        interval: 100
        repeat: false
        onTriggered: {
            if (!root.active) return
            inputField.forceActiveFocus()
            if (selectAll)
                inputField.selectAll()
        }
    }

    function focusInputFromKeypad() {
        Qt.callLater(function() { inputField.forceActiveFocus() })
    }

    component CalcKey: Item {
        id: key
        property string label: ""
        property string action: "focus"
        property bool isIcon: false
        property bool enabled: true
        readonly property bool flashing: action === "focus" && root.flashDigit === label

        Rectangle {
            id: keyBg
            anchors.fill: parent
            radius: Theme.fieldsetCornerRadius
            opacity: key.enabled ? 1 : 0.35
            color: key.flashing ? Theme.withOpacity(Theme.accent, 0.5) : "transparent"
            border.color: key.flashing ? Theme.accent : Theme.withOpacity(Theme.foreground, 0.22)
            border.width: 1

            Behavior on color {
                ColorAnimation {
                    duration: 70
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 70
                    easing.type: Easing.OutCubic
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: key.label
            color: key.flashing ? Theme.accent : Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: key.isIcon
                ? Theme.fontSize2xl
                : (key.label.length > 1 ? Theme.fontSizeS : Theme.fontSizeL)
            font.bold: Theme.fontBold

            Behavior on color {
                ColorAnimation { duration: 70 }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: false
            enabled: key.enabled
            cursorShape: key.action === "clear" ? Qt.PointingHandCursor : Qt.IBeamCursor
            onClicked: {
                if (key.action === "clear")
                    root.clearHistory()
                else
                    root.focusInputFromKeypad()
            }
        }
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

    onActiveChanged: {
        if (!active) return
        if (host && host.focusTarget === "tasks")
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
        spacing: Theme.spacingL

        SectionPanel {
            id: calculatorPanel
            contentPad: Theme.panelContentPad
            legendBackground: Theme.background
            label: ""

            HoverPopupLabelPill {
                text: "Calculator"
                fontSize: Theme.fontSizeS
            }

            TextInput {
                id: inputField
                Layout.fillWidth: true
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
                    var digit = root.digitFromKey(event.key)
                    if (digit)
                        root.flashDigitKey(digit)
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.submit()
                        event.accepted = true
                    }
                }
                Keys.onEscapePressed: if (host) host.dismiss()
                Keys.onUpPressed: root.recallHistory(-1)
                Keys.onDownPressed: root.recallHistory(1)
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 6
                rowSpacing: 6

                readonly property var keys: [
                    "7", "8", "9",
                    "4", "5", "6",
                    "1", "2", "3",
                    "CE", "0", "clear"
                ]

                Repeater {
                    model: parent.keys
                    delegate: Item {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36

                        CalcKey {
                            anchors.fill: parent
                            label: modelData === "clear" ? "󰃢" : modelData
                            action: modelData === "clear" ? "clear" : "focus"
                            isIcon: modelData === "clear"
                            enabled: modelData !== "clear"
                                || (root.entries.length > 0 && !clearProc.running)
                        }
                    }
                }
            }
        }

        SectionPanel {
            contentPad: Theme.panelContentPad
            legendBackground: Theme.background
            label: ""

            HoverPopupLabelPill {
                text: "History"
                fontSize: Theme.fontSizeS
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: historyView.height

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
