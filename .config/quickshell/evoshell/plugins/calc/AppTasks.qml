import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property var host: null

    readonly property string taskPath: Quickshell.env("HOME") + "/.local/state/evoshell/apps/tasks.json"
    readonly property int taskFontSize: Theme.fontSizeL
    readonly property int taskRowMin: 28
    readonly property int taskBottomPad: 8
    readonly property bool active: host && host.opened === true

    property bool taskLoading: false
    property bool taskDirty: false
    property bool suppressTaskReload: false
    property bool pendingNewTaskFocus: false
    property int taskUiTick: 0

    readonly property int listHeight: Math.max(root.taskRowMin, taskList.contentHeight)
    implicitHeight: tasksPanel.verticalChrome + listHeight + 10 + 22

    readonly property bool completedTasksPresent: {
        var tick = taskUiTick
        for (var i = 0; i < taskModel.count; i++) {
            var row = taskModel.get(i)
            if (row.done && String(row.text || "").trim())
                return true
        }
        return false
    }

    ListModel {
        id: taskModel
    }
    Process {
        id: migrateTasksProc
        running: true
        command: ["bash", "-c", 'd="$HOME/.local/state/evoshell/apps"; mkdir -p "$d"; legacy="$HOME/.local/state/evoshell/notes-task.json"; target="$d/tasks.json"; [ -f "$legacy" ] && [ ! -f "$target" ] && mv "$legacy" "$target"; true']
    }



    function ensureTrailingRow(list) {
        var out = []
        var source = Array.isArray(list) ? list : []
        for (var i = 0; i < source.length; i++) {
            var t = source[i]
            if (!t) continue
            out.push({
                text: String(t.text || ""),
                done: t.done === true
            })
        }
        if (out.length === 0 || String(out[out.length - 1].text || "") !== "")
            out.push({ text: "", done: false })
        return out
    }

    function setTaskModel(list) {
        taskModel.clear()
        var rows = ensureTrailingRow(list)
        for (var i = 0; i < rows.length; i++)
            taskModel.append(rows[i])
        taskUiTick++
    }

    function tasksForSave() {
        var out = []
        for (var i = 0; i < taskModel.count; i++) {
            var row = taskModel.get(i)
            var text = String(row.text || "").trim()
            if (!text) continue
            out.push({ text: text, done: row.done === true })
        }
        return out
    }

    function setTaskText(index, value) {
        if (taskLoading || index < 0 || index >= taskModel.count) return
        var current = String(taskModel.get(index).text || "")
        if (current === String(value || "")) return
        taskModel.setProperty(index, "text", String(value || ""))
        taskDirty = true
        taskUiTick++
        taskSaveTimer.restart()
    }

    function toggleTaskDone(index) {
        if (taskLoading || index < 0 || index >= taskModel.count) return
        var rows = []
        for (var i = 0; i < taskModel.count; i++) {
            rows.push({
                text: String(taskModel.get(i).text || ""),
                done: taskModel.get(i).done === true
            })
        }
        var toggled = rows[index]
        toggled.done = !toggled.done
        rows.splice(index, 1)

        var completed = []
        var incomplete = []
        for (var j = 0; j < rows.length; j++) {
            if (rows[j].done && String(rows[j].text || "").trim())
                completed.push(rows[j])
            else
                incomplete.push(rows[j])
        }

        var text = String(toggled.text || "").trim()
        if (text) {
            if (toggled.done)
                completed.push(toggled)
            else
                incomplete.unshift(toggled)
        } else {
            incomplete.push(toggled)
        }

        setTaskModel(completed.concat(incomplete))
        taskDirty = true
        taskUiTick++
        taskSaveTimer.restart()
    }

    function ensureTrailingModelRow() {
        if (taskModel.count === 0) {
            taskModel.append({ text: "", done: false })
            return
        }
        var last = taskModel.get(taskModel.count - 1)
        if (String(last.text || "") !== "") {
            taskModel.append({ text: "", done: false })
            taskUiTick++
        }
    }

    function onTaskReturn(index) {
        var text = String(taskModel.get(index).text || "").trim()
        if (!text)
            return
        ensureTrailingModelRow()
        focusTaskRow(Math.min(index + 1, taskModel.count - 1))
    }

    function applyLoadedTask(raw) {
        taskLoading = true
        try {
            var data = JSON.parse(String(raw || "").trim() || "{}")
            if (Array.isArray(data.tasks)) {
                setTaskModel(data.tasks)
            } else if (data.text !== undefined) {
                setTaskModel([{
                    text: String(data.text || ""),
                    done: data.done === true
                }])
            } else {
                setTaskModel([])
            }
        } catch (e) {
            setTaskModel([])
        }
        taskDirty = false
        taskLoading = false
        if (pendingNewTaskFocus)
            focusTaskRow(Math.max(0, taskModel.count - 1))
    }

    function saveTask() {
        if (taskLoading || !taskDirty) return
        suppressTaskReload = true
        taskFile.setText(JSON.stringify({ tasks: tasksForSave() }))
        taskDirty = false
    }

    function clearTasks() {
        taskLoading = true
        setTaskModel([])
        taskLoading = false
        taskDirty = true
        saveTask()
        focusTaskRow(0)
    }

    function clearCompletedTasks() {
        var remaining = []
        for (var i = 0; i < taskModel.count; i++) {
            var row = taskModel.get(i)
            if (!row.done)
                remaining.push({ text: String(row.text || ""), done: false })
        }
        taskLoading = true
        setTaskModel(remaining)
        taskLoading = false
        taskDirty = true
        saveTask()
        focusTaskRow(Math.max(0, taskModel.count - 1))
    }

    function focusTaskRow(row) {
        Qt.callLater(function() {
            taskList.positionViewAtIndex(row, ListView.Contain)
            Qt.callLater(function() {
                var item = taskList.itemAtIndex(row)
                if (item && item.taskField) {
                    item.taskField.forceActiveFocus()
                    item.taskField.cursorPosition = item.taskField.text.length
                    pendingNewTaskFocus = false
                }
            })
        })
    }

    function focusNewTask() {
        pendingNewTaskFocus = true
        focusTaskRow(Math.max(0, taskModel.count - 1))
    }

    function onActivated() {
        saveTask()
        loadTask()
    }

    Connections {
        target: root.host
        function onOpenedChanged() {
            if (root.host && !root.host.opened)
                root.saveTask()
        }
    }

    FileView {
        id: taskFile
        path: root.taskPath
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onLoaded: root.applyLoadedTask(text())
        onLoadFailed: root.applyLoadedTask("")
        onFileChanged: {
            if (root.suppressTaskReload) {
                root.suppressTaskReload = false
                return
            }
            if (!root.taskDirty && !root.active)
                reload()
        }
        onSaved: root.taskDirty = false
    }

    Timer {
        id: taskSaveTimer
        interval: 600
        repeat: false
        onTriggered: root.saveTask()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingL

        FramedPanel {
            id: tasksPanel
            label: "Tasks"
            labelBackground: Theme.background
            contentFill: true
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: taskList
                anchors.fill: parent
                clip: true
                spacing: Theme.spacing2
                boundsBehavior: Flickable.StopAtBounds
                model: taskModel
                footer: Item {
                    width: taskList.width
                    height: root.taskBottomPad
                }

                delegate: Item {
                    id: taskRow
                    required property int index
                    required property string text
                    required property bool done

                    width: taskList.width
                    height: Math.max(root.taskRowMin, inner.implicitHeight + 6)
                    property alias taskField: taskInput

                    RowLayout {
                        id: inner
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingM

                        Item {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -1
                                text: taskRow.done ? "󰄲" : "󰄱"
                                color: taskRow.done ? Theme.accent : Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize2xl
                                font.bold: Theme.fontBold
                                opacity: taskCheckMouse.containsMouse ? 1 : 0.85
                            }

                            MouseArea {
                                id: taskCheckMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleTaskDone(index)
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredHeight: Math.max(root.taskFontSize + 6, taskInput.implicitHeight)

                            TextInput {
                                id: taskInput
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.taskFontSize
                                font.bold: Theme.fontBold
                                font.strikeout: taskRow.done
                                opacity: taskRow.done ? 0.55 : 1
                                selectByMouse: true
                                wrapMode: TextInput.Wrap
                                clip: true

                                Component.onCompleted: text = taskRow.text
                                onTextEdited: root.setTaskText(index, text)
                                Keys.onReturnPressed: root.onTaskReturn(index)
                                Keys.onEscapePressed: {
                                    root.saveTask()
                                    if (host) host.dismiss()
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                visible: taskInput.text.length === 0 && !taskInput.activeFocus
                                text: index === taskModel.count - 1 ? "Add a task…" : "Task"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.taskFontSize
                                opacity: Theme.opacityDisabled
                            }
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 28

            Text {
                anchors.centerIn: parent
                text: "󰩈"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize2xl
                font.bold: Theme.fontBold
                opacity: !clearCompletedMouse.enabled
                    ? 0.35
                    : (clearCompletedMouse.containsMouse ? 1 : 0.72)
            }

            MouseArea {
                id: clearCompletedMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: root.completedTasksPresent
                onClicked: root.clearCompletedTasks()
            }
        }
    }

    Component.onCompleted: setTaskModel([])
    Component.onDestruction: root.saveTask()
}
