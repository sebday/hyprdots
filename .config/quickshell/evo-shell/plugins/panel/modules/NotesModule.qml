import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../../Commons"

Item {
    id: root

    property var host: null
    property var shell: null

    readonly property string notesPath: Quickshell.env("HOME") + "/.local/state/evo-shell/notes.txt"
    readonly property string taskPath: Quickshell.env("HOME") + "/.local/state/evo-shell/notes-task.json"
    readonly property int editorFontSize: 15
    readonly property int taskFontSize: 14
    readonly property int taskRowHeight: 28
    readonly property int taskBottomPad: 14
    readonly property int taskPanelMaxHeight: 196
    readonly property bool active: host && host.opened && host.activeModule === "notes"

    property bool loading: false
    property bool dirty: false
    property bool taskLoading: false
    property bool taskDirty: false
    property bool suppressTaskReload: false
    property int taskUiTick: 0

    readonly property bool completedTasksPresent: {
        var tick = taskUiTick
        for (var i = 0; i < taskModel.count; i++) {
            var row = taskModel.get(i)
            if (row.done && String(row.text || "").trim())
                return true
        }
        return false
    }

    readonly property bool anyTasksPresent: {
        var tick = taskUiTick
        for (var i = 0; i < taskModel.count; i++) {
            if (String(taskModel.get(i).text || "").trim())
                return true
        }
        return false
    }

    ListModel {
        id: taskModel
    }

    function loadNotes() {
        notesFile.reload()
    }

    function loadTask() {
        taskFile.reload()
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
        if (!text) {
            focusEditor()
            return
        }
        ensureTrailingModelRow()
        focusTaskRow(Math.min(index + 1, taskModel.count - 1))
    }

    function applyLoadedText(raw) {
        loading = true
        editor.text = String(raw || "")
        dirty = false
        loading = false
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
    }

    function saveNotes() {
        if (loading || !dirty) return
        notesFile.setText(editor.text)
        dirty = false
    }

    function saveTask() {
        if (taskLoading || !taskDirty) return
        suppressTaskReload = true
        taskFile.setText(JSON.stringify({ tasks: tasksForSave() }))
        taskDirty = false
    }

    function saveAll() {
        saveNotes()
        saveTask()
    }

    function clearNotes() {
        loading = true
        editor.text = ""
        loading = false
        dirty = true
        saveNotes()
        focusEditor()
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

    function focusEditor() {
        Qt.callLater(function() {
            editor.forceActiveFocus()
            editor.cursorPosition = editor.text.length
        })
    }

    function focusTaskRow(row) {
        Qt.callLater(function() {
            var item = taskList.itemAtIndex(row)
            if (item && item.taskField) {
                item.taskField.forceActiveFocus()
                item.taskField.cursorPosition = item.taskField.text.length
            }
        })
    }

    function onActivated() {
        saveAll()
        loadNotes()
        loadTask()
        focusTaskRow(0)
    }

    Connections {
        target: root.host
        function onActiveModuleChanged() {
            if (root.host && root.host.activeModule !== "notes")
                root.saveAll()
        }
        function onOpenedChanged() {
            if (root.host && !root.host.opened)
                root.saveAll()
        }
    }

    FileView {
        id: notesFile
        path: root.notesPath
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onLoaded: root.applyLoadedText(text())
        onLoadFailed: root.applyLoadedText("")
        onFileChanged: {
            if (!root.dirty && !root.active)
                reload()
        }
        onSaved: root.dirty = false
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
        id: saveTimer
        interval: 400
        repeat: false
        onTriggered: root.saveNotes()
    }

    Timer {
        id: taskSaveTimer
        interval: 600
        repeat: false
        onTriggered: root.saveTask()
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.bottom: parent.bottom
        spacing: 10

        FramedPanel {
            label: "Tasks"
            contentFill: true
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            Layout.preferredHeight: Math.min(
                root.taskPanelMaxHeight,
                taskModel.count * root.taskRowHeight + root.taskBottomPad + 18
            )

            ListView {
                id: taskList
                anchors.fill: parent
                clip: true
                spacing: 0
                boundsBehavior: Flickable.StopAtBounds
                model: taskModel
                footer: Item {
                    width: taskList.width
                    height: root.taskBottomPad
                }

                delegate: RowLayout {
                    id: taskRow
                    required property int index
                    required property string text
                    required property bool done

                    width: taskList.width
                    height: root.taskRowHeight
                    spacing: 8

                    property alias taskField: taskInput

                    Item {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24

                        Text {
                            anchors.centerIn: parent
                            text: taskRow.done ? "󰄲" : "󰄱"
                            color: taskRow.done ? Theme.accent : Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 18
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
                        Layout.preferredHeight: taskInput.implicitHeight

                        TextInput {
                            id: taskInput
                            anchors.fill: parent
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.taskFontSize
                            font.bold: Theme.fontBold
                            font.strikeout: taskRow.done
                            opacity: taskRow.done ? 0.55 : 1
                            selectByMouse: true
                            wrapMode: TextInput.NoWrap
                            clip: true

                            Component.onCompleted: text = taskRow.text

                            onTextEdited: root.setTaskText(index, text)

                            Keys.onReturnPressed: root.onTaskReturn(index)
                            Keys.onTabPressed: root.focusEditor()
                            Keys.onEscapePressed: {
                                root.saveAll()
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
                            opacity: 0.45
                        }
                    }
                }
            }
        }

        FramedPanel {
            label: "Notes"
            contentFill: true
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                id: flick
                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: Math.max(height, editor.implicitHeight)
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                TextEdit {
                    id: editor
                    width: flick.width
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.editorFontSize
                    font.bold: Theme.fontBold
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.background
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    activeFocusOnPress: true
                    selectByMouse: true

                    onTextChanged: {
                        if (root.loading) return
                        root.dirty = true
                        saveTimer.restart()
                    }

                    Keys.onEscapePressed: {
                        root.saveAll()
                        if (host) host.dismiss()
                    }
                }
            }

            Text {
                anchors.fill: parent
                visible: editor.text.length === 0 && !editor.activeFocus
                text: "Write a note…"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.editorFontSize
                opacity: 0.45
                verticalAlignment: Text.AlignTop
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 28

            Row {
                anchors.centerIn: parent
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Clear:"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    opacity: 0.65
                }

                Text {
                    id: clearCompletedLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Completed"
                    color: clearCompletedMouse.enabled
                        ? (clearCompletedMouse.containsMouse ? Theme.accent : Theme.foreground)
                        : Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: Theme.fontBold
                    opacity: clearCompletedMouse.enabled
                        ? (clearCompletedMouse.containsMouse ? 1 : 0.82)
                        : 0.35

                    MouseArea {
                        id: clearCompletedMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.completedTasksPresent
                        onClicked: root.clearCompletedTasks()
                    }
                }

                Text {
                    id: clearAllLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: "All"
                    color: clearAllMouse.enabled
                        ? (clearAllMouse.containsMouse ? Theme.accent : Theme.foreground)
                        : Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: Theme.fontBold
                    opacity: clearAllMouse.enabled
                        ? (clearAllMouse.containsMouse ? 1 : 0.82)
                        : 0.35

                    MouseArea {
                        id: clearAllMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.anyTasksPresent
                        onClicked: root.clearTasks()
                    }
                }

                Text {
                    id: clearNotesLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Notes"
                    color: clearNotesMouse.enabled
                        ? (clearNotesMouse.containsMouse ? Theme.accent : Theme.foreground)
                        : Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: Theme.fontBold
                    opacity: clearNotesMouse.enabled
                        ? (clearNotesMouse.containsMouse ? 1 : 0.82)
                        : 0.35

                    MouseArea {
                        id: clearNotesMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: editor.text.length > 0
                        onClicked: root.clearNotes()
                    }
                }
            }
        }
    }

    Component.onCompleted: setTaskModel([])
    Component.onDestruction: root.saveAll()
}
