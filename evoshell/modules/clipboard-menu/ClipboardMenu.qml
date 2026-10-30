import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.commons
import "../menu/LauncherSources.js" as LauncherSources
import "views"

Item {
    id: root

    property var shell: null
    property bool opened: false
    property var openScreen: null
    property string lastView: "clipboard"
    property string view: "clipboard"
    property string query: ""
    property int selectedIndex: 0
    property bool actionsOpen: false
    property int actionIndex: 0

    property var emojiAll: []
    property var emojiRecents: []

    readonly property string home: Quickshell.env("HOME")
    readonly property string emojiRecentsPath: Util.statePath(home, "launcher-emoji-recents.json")
    readonly property string emojiPath: {
        var dir = shell && shell.shellDir ? String(shell.shellDir) : String(Quickshell.shellDir)
        return dir + "/modules/clipboard-menu/emoji.json"
    }
    readonly property var emojiResults: view === "emoji"
        ? LauncherSources.filterEmoji(emojiAll, query, emojiRecents)
        : []
    readonly property var currentEntries: {
        if (view === "clipboard")
            return clipboardView.visibleEntries
        if (view === "emoji")
            return emojiResults
        return []
    }
    readonly property var selectedEntry: {
        var list = currentEntries
        if (!list || selectedIndex < 0 || selectedIndex >= list.length)
            return null
        return list[selectedIndex]
    }
    readonly property var actionItems: LauncherSources.actionsFor(selectedEntry)
    readonly property bool gridNav: view === "emoji"
    readonly property int gridColumns: gridNav ? emojiGrid.columnCount : 1
    readonly property var sectionPills: [
        { id: "clipboard", label: "Clipboard" },
        { id: "emoji", label: "Emoji" }
    ]
    readonly property string sectionLabel: view === "emoji" ? "Emoji" : "Clipboard"
    readonly property string placeholder: view === "emoji" ? "Search emoji…" : "Search clipboard…"

    function parsePayload(payloadJson) {
        var viewName = ""
        var nextQuery = ""
        try {
            var payload = JSON.parse(payloadJson || "{}")
            if (payload.view)
                viewName = String(payload.view)
            if (payload.query)
                nextQuery = String(payload.query)
        } catch (e) {
            viewName = ""
        }
        if (viewName !== "clipboard" && viewName !== "emoji")
            viewName = lastView
        return { view: viewName, query: nextQuery }
    }

    function applyView(nextView, nextQuery) {
        view = nextView
        lastView = nextView
        query = String(nextQuery || "")
        selectedIndex = 0
        actionsOpen = false
        if (searchField.text !== query)
            searchField.text = query
        if (nextView === "clipboard")
            clipboardView.refresh()
    }

    function selectSection(sectionId) {
        var next = String(sectionId || "clipboard")
        if (view === next && query === "")
            return
        applyView(next, "")
        Qt.callLater(function() { searchField.forceActiveFocus() })
    }

    function cycleSection(direction) {
        var pills = sectionPills
        var index = view === "emoji" ? 1 : 0
        var next = (index + direction + pills.length) % pills.length
        selectSection(pills[next].id)
    }

    function focusedScreen() {
        var screens = Quickshell.screens
        var monitor = Hyprland.focusedMonitor
        if (!monitor)
            return screens.length > 0 ? screens[0] : null
        var name = String(monitor.name || "")
        for (var i = 0; i < screens.length; i++) {
            if (screens[i] && String(screens[i].name || "") === name)
                return screens[i]
        }
        for (var j = 0; j < screens.length; j++) {
            var screen = screens[j]
            if (screen && screen.x === monitor.x && screen.y === monitor.y)
                return screen
        }
        return screens.length > 0 ? screens[0] : null
    }

    function hideSiblings() {
        if (!shell)
            return
        shell.hide("evo.dock")
        shell.hide("evo.power")
        shell.hide("evo.sys.menu")
        shell.hide("evo.sys.runner")
    }

    function open(payloadJson) {
        hideSiblings()
        openScreen = focusedScreen()
        var next = parsePayload(payloadJson)
        opened = true
        applyView(next.view, next.query)
        Qt.callLater(function() {
            searchField.forceActiveFocus()
        })
    }

    function close() {
        if (!opened)
            return
        opened = false
        actionsOpen = false
        query = ""
        if (searchField.text !== "")
            searchField.text = ""
    }

    function dismiss() {
        if (shell)
            shell.hide("evo.sys.clipboard")
        else
            close()
    }

    function reopen(payloadJson) {
        if (!opened)
            return false
        var next = parsePayload(payloadJson)
        if (next.view === view && next.query === query)
            return false
        applyView(next.view, next.query)
        Qt.callLater(function() {
            searchField.forceActiveFocus()
        })
        return true
    }

    function setQuery(text) {
        var next = String(text || "")
        if (query !== next)
            query = next
        selectedIndex = 0
        actionsOpen = false
    }

    function handleEscape() {
        if (actionsOpen) {
            actionsOpen = false
            return
        }
        dismiss()
    }

    function toggleActions() {
        var count = actionItems.length
        if (count <= 0)
            return
        if (!actionsOpen) {
            actionIndex = count > 1 ? 1 : 0
            actionsOpen = true
            return
        }
        actionIndex = (actionIndex + 1) % count
    }

    function actionIndexForEvent(event, fieldText) {
        var items = actionItems
        var empty = String(fieldText || "").length === 0
        var alt = (event.modifiers & Qt.AltModifier) !== 0
        var shift = (event.modifiers & Qt.ShiftModifier) !== 0
        var ctrl = (event.modifiers & Qt.ControlModifier) !== 0
        if (!items || ctrl)
            return -1
        for (var i = 0; i < items.length; i++) {
            var key = items[i] && items[i].key ? String(items[i].key) : ""
            if (!key)
                continue
            if (key === "backspace" && event.key === Qt.Key_Backspace)
                return empty ? i : -1
            if (key.length === 1 && !shift && event.text && String(event.text).toLowerCase() === key) {
                if (alt || (empty && !items[i].alt))
                    return i
            }
        }
        return -1
    }

    function runVisibleAction(index) {
        var action = actionItems[index]
        if (!action)
            return
        actionsOpen = false
        if (selectedEntry)
            runAction(selectedEntry, action.id)
    }

    function moveVertical(delta) {
        if (actionsOpen) {
            var count = actionItems.length
            if (count <= 0)
                return
            actionIndex = (actionIndex + delta + count) % count
            return
        }
        if (gridNav) {
            moveGrid(0, delta)
            return
        }
        moveSelection(delta)
    }

    function moveHorizontal(delta) {
        if (actionsOpen || !gridNav)
            return
        moveGrid(delta, 0)
    }

    function moveSelection(delta) {
        var count = currentEntries.length
        if (count <= 0) {
            selectedIndex = 0
            return
        }
        var next = selectedIndex + delta
        if (next < 0)
            next = count - 1
        else if (next >= count)
            next = 0
        selectedIndex = next
    }

    function moveGrid(dx, dy) {
        var count = currentEntries.length
        if (count <= 0) {
            selectedIndex = 0
            return
        }
        var cols = Math.max(1, gridColumns)
        var index = selectedIndex
        if (index < 0)
            index = 0
        if (dx !== 0) {
            var stepped = index + dx
            if (stepped < 0)
                stepped = count - 1
            else if (stepped >= count)
                stepped = 0
            selectedIndex = stepped
            return
        }
        var col = index % cols
        var row = Math.floor(index / cols)
        var rows = Math.max(1, Math.ceil(count / cols))
        var targetRow = row + dy
        if (targetRow < 0)
            targetRow = rows - 1
        else if (targetRow >= rows)
            targetRow = 0
        var target = targetRow * cols + col
        if (target >= count)
            target = count - 1
        selectedIndex = target
    }

    function activateSelection() {
        if (actionsOpen) {
            runVisibleAction(actionIndex)
            return
        }
        if (selectedEntry)
            runAction(selectedEntry, "")
    }

    function runAction(entry, actionId) {
        if (!entry)
            return
        var action = String(actionId || "")
        if (!action) {
            var actions = LauncherSources.actionsFor(entry)
            action = actions.length > 0 ? actions[0].id : "copy"
        }
        if (entry.kind === "clipboard") {
            if (action === "pin") {
                clipboardView.togglePin(entry)
                return
            }
            if (action === "delete") {
                clipboardView.deleteEntry(entry)
                return
            }
            clipboardView.copyEntry(entry)
            dismiss()
            return
        }
        if (entry.kind === "emoji") {
            rememberEmoji(entry.emoji)
            if (action === "type") {
                dismiss()
                typeText(entry.emoji)
                return
            }
            copyText(entry.emoji)
            dismiss()
        }
    }

    function copyText(text) {
        Quickshell.execDetached(["bash", "-lc", "printf %s " + Util.shellQuote(String(text || "")) + " | wl-copy"])
    }

    function typeText(text) {
        Quickshell.execDetached(["bash", "-lc",
            "sleep 0.2; command -v wtype >/dev/null && wtype -- " + Util.shellQuote(String(text || ""))])
    }

    function loadEmojiRecents() {
        try {
            var raw = String(emojiRecentsFile.text() || "").trim()
            var data = raw ? JSON.parse(raw) : []
            emojiRecents = Array.isArray(data) ? data : []
        } catch (e) {
            emojiRecents = []
        }
    }

    function saveEmojiRecents() {
        var payload = JSON.stringify(emojiRecents)
        saveEmojiRecentsProc.command = ["bash", "-lc",
            "mkdir -p $(dirname " + Util.shellQuote(emojiRecentsPath) + ") && printf '%s' "
                + Util.shellQuote(payload) + " > " + Util.shellQuote(emojiRecentsPath)]
        if (!saveEmojiRecentsProc.running)
            saveEmojiRecentsProc.running = true
    }

    function rememberEmoji(ch) {
        var key = String(ch || "")
        if (!key)
            return
        var next = [key]
        for (var i = 0; i < emojiRecents.length; i++) {
            if (emojiRecents[i] !== key)
                next.push(emojiRecents[i])
            if (next.length >= 32)
                break
        }
        emojiRecents = next
        saveEmojiRecents()
    }

    onCurrentEntriesChanged: {
        if (selectedIndex >= currentEntries.length)
            selectedIndex = Math.max(0, currentEntries.length - 1)
    }

    Process { id: saveEmojiRecentsProc }

    FileView {
        id: emojiRecentsFile
        path: root.emojiRecentsPath
        watchChanges: false
        printErrors: false
        onLoaded: root.loadEmojiRecents()
        onLoadFailed: root.emojiRecents = []
    }

    FileView {
        id: emojiFile
        path: root.emojiPath
        watchChanges: false
        printErrors: false
        onLoaded: {
            try {
                var data = JSON.parse(String(emojiFile.text() || "[]"))
                root.emojiAll = Array.isArray(data) ? data : []
            } catch (e) {
                console.warn("clipboard emoji load failed:", e)
                root.emojiAll = []
            }
        }
    }

    PanelWindow {
        id: panel
        visible: root.opened
        screen: root.openScreen
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.namespace: "evo-sys-clipboard"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore

        MouseArea {
            anchors.fill: parent
            onClicked: root.dismiss()
        }

        Item {
            id: menuPanel
            z: 1
            anchors.centerIn: parent
            width: Theme.launcherWidth + Theme.hoverPanelContentPad * 2
            height: Theme.launcherHeight + Theme.hoverPanelContentPad * 2

            Rectangle {
                anchors.fill: parent
                radius: Theme.fieldsetCornerRadius
                color: Theme.background
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: {}
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.hoverPanelContentPad
                spacing: Theme.hoverPanelContentPad

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.minimumWidth: Theme.space(160)
                        Layout.preferredHeight: Theme.launcherSearchHeight
                        radius: Theme.cornerRadius
                        color: Theme.panelMantle

                        TextInput {
                            id: searchField
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeS
                            font.bold: Theme.fontBold
                            clip: true
                            selectByMouse: true
                            focus: root.opened
                            onTextEdited: function() { root.setQuery(searchField.text) }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                elide: Text.ElideRight
                                visible: searchField.text.length === 0
                                text: root.placeholder
                                color: Theme.foreground
                                opacity: Theme.opacityMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeS
                                font.bold: Theme.fontBold
                            }

                            Keys.onEscapePressed: function(event) {
                                root.handleEscape()
                                event.accepted = true
                            }
                            Keys.onUpPressed: function(event) {
                                root.moveVertical(-1)
                                event.accepted = true
                            }
                            Keys.onDownPressed: function(event) {
                                root.moveVertical(1)
                                event.accepted = true
                            }
                            Keys.onLeftPressed: function(event) {
                                if (!root.gridNav || cursorPosition !== 0) {
                                    event.accepted = false
                                    return
                                }
                                root.moveHorizontal(-1)
                                event.accepted = true
                            }
                            Keys.onRightPressed: function(event) {
                                if (!root.gridNav || cursorPosition !== text.length) {
                                    event.accepted = false
                                    return
                                }
                                root.moveHorizontal(1)
                                event.accepted = true
                            }
                            Keys.onReturnPressed: function(event) {
                                root.activateSelection()
                                event.accepted = true
                            }
                            Keys.onEnterPressed: function(event) {
                                root.activateSelection()
                                event.accepted = true
                            }
                            Keys.onTabPressed: function(event) {
                                root.cycleSection(1)
                                event.accepted = true
                            }
                            Keys.onBacktabPressed: function(event) {
                                root.cycleSection(-1)
                                event.accepted = true
                            }
                            Keys.onPressed: function(event) {
                                if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_K) {
                                    root.toggleActions()
                                    event.accepted = true
                                    return
                                }
                                var shortcut = root.actionIndexForEvent(event, text)
                                if (shortcut >= 0) {
                                    root.runVisibleAction(shortcut)
                                    event.accepted = true
                                    return
                                }
                                if (event.key === Qt.Key_Backspace && text.length === 0 && !root.actionsOpen) {
                                    root.dismiss()
                                    event.accepted = true
                                    return
                                }
                                event.accepted = false
                            }
                        }
                    }

                    Row {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: Theme.spacingS

                        Repeater {
                            model: root.sectionPills

                            delegate: Item {
                                id: sectionPill
                                required property var modelData
                                readonly property bool selected: root.view === String(modelData.id || "")
                                width: sectionPillBox.implicitWidth
                                height: sectionPillBox.implicitHeight

                                Rectangle {
                                    id: sectionPillBox
                                    radius: height / 2
                                    color: sectionPill.selected
                                        ? Theme.accent
                                        : (sectionPillMouse.containsMouse
                                            ? Theme.withOpacity(Theme.foreground, 0.1)
                                            : Theme.withOpacity(Theme.foreground, 0.06))
                                    implicitWidth: sectionPillLabel.implicitWidth + 16
                                    implicitHeight: sectionPillLabel.implicitHeight + 8

                                    Text {
                                        id: sectionPillLabel
                                        anchors.centerIn: parent
                                        text: sectionPill.modelData ? String(sectionPill.modelData.label || "") : ""
                                        color: sectionPill.selected ? Theme.mantle : Theme.foreground
                                        opacity: sectionPill.selected ? 1 : Theme.opacitySecondary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeS
                                        font.bold: Theme.fontBold
                                    }
                                }

                                MouseArea {
                                    id: sectionPillMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectSection(sectionPill.modelData ? sectionPill.modelData.id : "clipboard")
                                }
                            }
                        }
                    }
                }

                SectionPanel {
                    id: mainFrame
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    fillHeight: true
                    filled: true
                    fillColor: Theme.background
                    legendBackground: Theme.background
                    frameBorder: Theme.withOpacity(Theme.foreground, 0.32)
                    label: ""
                    contentPad: Theme.launcherPad
                    sectionSpacing: Theme.spacingS

                    HoverPanelLabelPill {
                        text: root.sectionLabel
                        fontSize: Theme.font.caption
                        textColor: Theme.foreground
                        fieldsetFill: Theme.background
                    }

                    Item {
                        id: contentHost
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ClipboardView {
                            id: clipboardView
                            anchors.fill: parent
                            visible: root.view === "clipboard"
                            shell: root.shell
                            query: root.query
                            selectedIndex: root.selectedIndex
                            onIndexMoved: function(index) { root.selectedIndex = index }
                            onActivated: function(entry) { root.runAction(entry, "copy") }
                        }

                        EmojiGrid {
                            id: emojiGrid
                            anchors.fill: parent
                            visible: root.view === "emoji"
                            model: root.emojiResults
                            selectedIndex: root.selectedIndex
                            onIndexMoved: function(index) { root.selectedIndex = index }
                            onActivated: function(entry) { root.runAction(entry, "copy") }
                        }
                    }
                }
            }

            Item {
                z: 4
                x: mainFrame.mapToItem(menuPanel, 0, 0).x
                y: mainFrame.mapToItem(menuPanel, 0, mainFrame.height).y - height / 2
                width: mainFrame.width
                height: hintRow.implicitHeight

                Rectangle {
                    visible: hintRow.visible
                    x: hintRow.x - 4
                    y: hintRow.y - 2
                    width: hintRow.width + 8
                    height: hintRow.height + 4
                    color: Theme.background
                }

                Row {
                    id: hintRow
                    visible: root.actionItems.length > 0
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Repeater {
                        model: root.actionItems

                        delegate: Item {
                            id: actionChip
                            required property var modelData
                            required property int index
                            readonly property bool armed: root.actionsOpen
                                ? index === root.actionIndex
                                : index === 0
                            readonly property string keyText: {
                                if (index === 0)
                                    return "⏎"
                                var key = modelData && modelData.key ? String(modelData.key) : ""
                                if (key === "backspace")
                                    return "⌫"
                                if (key && modelData.alt)
                                    return "alt+" + key
                                return key
                            }
                            width: chipRow.implicitWidth
                            height: chipRow.implicitHeight

                            Row {
                                id: chipRow
                                spacing: 4

                                Text {
                                    visible: actionChip.keyText !== ""
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: actionChip.keyText
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeS
                                    font.bold: Theme.fontBold
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: actionChip.modelData
                                        ? String(actionChip.modelData.label || "").toLowerCase()
                                        : ""
                                    color: Theme.foreground
                                    opacity: actionChip.armed ? Theme.opacitySecondary : Theme.opacityMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeS
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.runVisibleAction(actionChip.index)
                            }
                        }
                    }
                }
            }
        }
    }
}
