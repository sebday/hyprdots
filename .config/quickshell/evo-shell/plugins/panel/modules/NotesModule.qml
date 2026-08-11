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
    readonly property int editorFontSize: 15
    readonly property bool active: host && host.opened && host.activeModule === "notes"

    property bool loading: false
    property bool dirty: false

    function loadNotes() {
        notesFile.reload()
    }

    function applyLoadedText(raw) {
        loading = true
        editor.text = String(raw || "")
        dirty = false
        loading = false
        Qt.callLater(function() {
            if (root.active)
                editor.forceActiveFocus()
        })
    }

    function saveNotes() {
        if (loading || !dirty) return
        notesFile.setText(editor.text)
        dirty = false
    }

    function focusEditor() {
        Qt.callLater(function() {
            editor.forceActiveFocus()
            editor.cursorPosition = editor.text.length
        })
    }

    function onActivated() {
        if (dirty)
            saveNotes()
        loadNotes()
        focusEditor()
    }

    Connections {
        target: root.host
        function onActiveModuleChanged() {
            if (root.host && root.host.activeModule !== "notes")
                root.saveNotes()
        }
        function onOpenedChanged() {
            if (root.host && !root.host.opened)
                root.saveNotes()
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
            if (!root.dirty)
                reload()
        }
        onSaved: root.dirty = false
    }

    Timer {
        id: saveTimer
        interval: 400
        repeat: false
        onTriggered: root.saveNotes()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

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
                    focus: root.active

                    onTextChanged: {
                        if (root.loading) return
                        root.dirty = true
                        saveTimer.restart()
                    }

                    Keys.onEscapePressed: {
                        root.saveNotes()
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
    }

    Component.onDestruction: root.saveNotes()
}
