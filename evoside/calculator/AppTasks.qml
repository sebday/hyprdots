import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../commons"

Item {
    id: root

    property var host: null

    readonly property string tasksScript: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-tasks")
    readonly property string fallbackTaskPath: Util.statePath(Quickshell.env("HOME"), "apps/tasks.json")
    property string tasksFilePath: root.fallbackTaskPath
    property string tasksFormat: "json"
    readonly property int taskFontSize: Theme.fontSizeL
    readonly property int taskRowMin: 28
    readonly property int taskBottomPad: 8
    readonly property bool active: host && host.opened === true
    readonly property color legendBackground: host && host.fieldsetLegendBackground !== undefined
        ? host.fieldsetLegendBackground
        : Theme.background

    TextMetrics {
        id: taskLineMetrics
        font.family: Theme.fontFamily
        font.pixelSize: root.taskFontSize
        font.bold: Theme.fontBold
        text: "Ag"
    }

    TextMetrics {
        id: taskCheckMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize2xl
        font.bold: Theme.fontBold
        text: "󰄱"
    }

    TextMetrics {
        id: taskDragMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeL
        font.bold: Theme.fontBold
        text: "󰇅"
    }

    readonly property int taskLineHeight: taskLineMetrics.height
    readonly property int taskCheckOffset: Math.max(0, Math.round((taskLineHeight - taskCheckMetrics.height) / 2) - 1)
    readonly property int taskDragOffset: Math.max(0, Math.round((taskLineHeight - taskDragMetrics.height) / 2) - 1)

    property bool taskLoading: false
    property bool taskDirty: false
    property bool suppressTaskReload: false
    property bool pendingNewTaskFocus: false
    property int taskUiTick: 0

    readonly property int listHeight: Math.max(root.taskRowMin, taskList.contentHeight)
    implicitHeight: tasksSection.verticalChrome + listHeight + root.taskBottomPad + 28 + Theme.spacingL

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

    function copyTaskText(index) {
        if (index < 0 || index >= taskModel.count) return
        var text = String(taskModel.get(index).text || "").trim()
        if (!text) return
        taskCopyProc.payload = JSON.stringify(text)
        taskCopyProc.running = true
    }

    function moveTask(from, to) {
        if (taskLoading || from === to) return
        if (from < 0 || to < 0) return
        if (from >= taskModel.count || to >= taskModel.count) return

        var lastIndex = taskModel.count - 1
        var trailingEmpty = lastIndex >= 0 && String(taskModel.get(lastIndex).text || "") === ""
        if (trailingEmpty) {
            if (from === lastIndex) return
            if (to > lastIndex) to = lastIndex
        }

        taskModel.move(from, to, 1)
        taskDirty = true
        saveTask()
    }

    function setTaskText(index, value) {
        if (taskLoading || index < 0 || index >= taskModel.count) return
        var current = String(taskModel.get(index).text || "")
        if (current === String(value || "")) return
        taskModel.setProperty(index, "text", String(value || ""))
        taskDirty = true
        taskUiTick++
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
        saveTask()
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
        saveTask()
        focusTaskRow(Math.min(index + 1, taskModel.count - 1))
    }

    function applyLoadedTasks(list) {
        taskLoading = true
        setTaskModel(Array.isArray(list) ? list : [])
        taskDirty = false
        taskLoading = false
        if (pendingNewTaskFocus)
            focusTaskRow(Math.max(0, taskModel.count - 1))
    }

    function loadTask() {
        if (!loadTaskProc.running)
            loadTaskProc.running = true
    }

    function refreshTaskSettings() {
        if (!loadTaskSettingsProc.running)
            loadTaskSettingsProc.running = true
    }

    function saveTask() {
        if (taskLoading || !taskDirty) return
        suppressTaskReload = true
        taskSaveProc.payload = JSON.stringify({ tasks: tasksForSave() })
        taskSaveProc.running = true
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
        id: taskFileWatch
        path: root.tasksFilePath
        watchChanges: true
        printErrors: false
        onFileChanged: {
            if (root.suppressTaskReload) {
                root.suppressTaskReload = false
                return
            }
            if (!root.taskDirty)
                root.loadTask()
        }
    }

    FileView {
        id: uiStateWatch
        path: Theme.uiConfigPath
        watchChanges: true
        printErrors: false
        onFileChanged: root.refreshTaskSettings()
    }

    Process {
        id: loadTaskSettingsProc
        command: ["bash", root.tasksScript, "settings", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(String(text || "{}"))
                    var nextPath = String(data.tasksFile || root.fallbackTaskPath)
                    var nextFormat = String(data.format || "json")
                    var pathChanged = nextPath !== root.tasksFilePath
                    root.tasksFilePath = nextPath
                    root.tasksFormat = nextFormat
                    if (pathChanged)
                        taskFileWatch.reload()
                    root.loadTask()
                } catch (e) {
                    root.loadTask()
                }
            }
        }
    }

    Process {
        id: loadTaskProc
        command: ["bash", root.tasksScript, "load"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(String(text || "{}"))
                    if (data.tasksFile)
                        root.tasksFilePath = String(data.tasksFile)
                    if (data.format)
                        root.tasksFormat = String(data.format)
                    root.applyLoadedTasks(data.tasks)
                } catch (e) {
                    root.applyLoadedTasks([])
                }
            }
        }
    }

    Process {
        id: taskSaveProc
        property string payload: "{}"
        command: ["bash", root.tasksScript, "save", taskSaveProc.payload]
        stdout: StdioCollector { }
    }

    Process {
        id: taskCopyProc
        property string payload: '""'
        command: ["bash", root.tasksScript, "copy", taskCopyProc.payload]
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingL

        SectionPanel {
            id: tasksSection
            legendBackground: root.legendBackground
            label: ""
            fillHeight: true
            Layout.fillWidth: true
            Layout.fillHeight: true

            HoverPanelLabelPill {
                text: "Tasks"
                icon: "󰄴"
                fontSize: Theme.fontSizeS
            }

            ListView {
                id: taskList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Theme.spacing2
                boundsBehavior: Flickable.StopAtBounds
                interactive: dragIndex < 0
                model: taskModel
                property int dragIndex: -1
                property int dropIndex: -1
                footer: Item {
                    width: taskList.width
                    height: root.taskBottomPad
                }

                delegate: Item {
                    id: taskRow
                    required property int index
                    required property string text
                    required property bool done

                    readonly property bool isTrailingRow: index === taskModel.count - 1 && taskInput.text.length === 0
                    readonly property bool draggable: !root.taskLoading && !isTrailingRow
                    readonly property int rowBodyHeight: Math.max(
                        root.taskLineHeight,
                        taskInput.contentHeight,
                        taskInput.implicitHeight
                    )

                    width: taskList.width
                    height: Math.max(root.taskRowMin, rowBodyHeight + 6)
                    opacity: taskList.dragIndex === index ? 0.55 : 1
                    property alias taskField: taskInput

                    Rectangle {
                        anchors.top: parent.top
                        width: parent.width
                        height: 2
                        color: Theme.accent
                        visible: taskList.dragIndex >= 0
                            && taskList.dropIndex === index
                            && taskList.dropIndex !== taskList.dragIndex
                    }

                    Row {
                        id: inner
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.topMargin: 3
                        width: parent.width
                        spacing: Theme.spacingM

                        Item {
                            width: 20
                            height: rowBodyHeight

                            Text {
                                anchors.top: parent.top
                                anchors.topMargin: root.taskCheckOffset
                                anchors.horizontalCenter: parent.horizontalCenter
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
                            width: Math.max(0, inner.width - 20 - 20 - Theme.spacingM * 2)
                            height: rowBodyHeight
                            clip: true

                            TextInput {
                                id: taskInput
                                anchors.top: parent.top
                                width: parent.width
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.taskFontSize
                                font.bold: Theme.fontBold
                                font.strikeout: taskRow.done
                                opacity: taskRow.done ? 0.55 : 1
                                selectByMouse: taskList.dragIndex < 0
                                wrapMode: TextInput.Wrap
                                clip: true

                                Component.onCompleted: text = taskRow.text
                                Connections {
                                    target: taskRow
                                    function onTextChanged() {
                                        if (!taskInput.activeFocus
                                                && taskList.dragIndex < 0
                                                && taskInput.text !== taskRow.text)
                                            taskInput.text = taskRow.text
                                    }
                                }
                                onTextEdited: root.setTaskText(index, text)
                                Keys.onReturnPressed: root.onTaskReturn(index)
                                Keys.onEscapePressed: {
                                    root.saveTask()
                                    if (host) host.dismiss()
                                }
                            }

                            Text {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                visible: taskInput.text.length === 0 && !taskInput.activeFocus
                                text: index === taskModel.count - 1 ? "Add a task…" : "Task"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.taskFontSize
                                opacity: Theme.opacityDisabled
                            }
                        }

                        Item {
                            id: dragHandle
                            width: 20
                            height: rowBodyHeight
                            enabled: taskRow.draggable
                            z: 2

                            Text {
                                anchors.top: parent.top
                                anchors.topMargin: root.taskDragOffset
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "󰇅"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeL
                                opacity: dragMouse.drag.active || dragMouse.pressed
                                    ? 0.95
                                    : (dragMouse.containsMouse ? 0.72 : 0.28)
                            }

                            MouseArea {
                                id: dragMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.SizeAllCursor
                                preventStealing: true
                                propagateComposedEvents: false
                                acceptedButtons: Qt.LeftButton

                                drag.target: dragLift
                                drag.axis: Drag.YAxis
                                drag.threshold: 6

                                Item {
                                    id: dragLift
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 1
                                    height: parent.height
                                }

                                onPressed: function(mouse) {
                                    taskList.dragIndex = taskRow.index
                                    taskList.dropIndex = taskRow.index
                                    taskInput.deselect()
                                    if (taskInput.activeFocus)
                                        taskInput.focus = false
                                    mouse.accepted = true
                                }

                                onPositionChanged: function(mouse) {
                                    if (!drag.active || taskList.dragIndex < 0)
                                        return
                                    var pos = mapToItem(taskList.contentItem, width / 2, mouse.y)
                                    var target = taskList.indexAt(pos.x, pos.y)
                                    if (target < 0)
                                        return

                                    var lastIdx = taskModel.count - 1
                                    if (lastIdx >= 0 && String(taskModel.get(lastIdx).text || "") === "" && target >= lastIdx)
                                        target = Math.max(0, lastIdx - 1)

                                    taskList.dropIndex = target
                                }

                                onReleased: {
                                    if (taskList.dragIndex >= 0
                                            && taskList.dropIndex >= 0
                                            && taskList.dropIndex !== taskList.dragIndex)
                                        root.moveTask(taskList.dragIndex, taskList.dropIndex)
                                    dragLift.y = 0
                                    taskList.dragIndex = -1
                                    taskList.dropIndex = -1
                                }

                                onCanceled: {
                                    dragLift.y = 0
                                    taskList.dragIndex = -1
                                    taskList.dropIndex = -1
                                }

                                onClicked: root.copyTaskText(taskRow.index)
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

    Component.onCompleted: refreshTaskSettings()
    Component.onDestruction: root.saveTask()
}
