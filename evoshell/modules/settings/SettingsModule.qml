import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.commons
import "."

Item {
    id: root

    property var host: null
    property var shell: null
    property bool showTabBar: true
    readonly property bool compactLayout: !showTabBar
    property alias tabIndex: settingsTabs.currentIndex
    property string menuFilterText: ""
    property int settingsKeyIndex: 0
    property var settingsNavItems: []

    readonly property string hyprScript: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-hyprland")
    readonly property string barScript: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-layout")

    property bool roundingOn: false
    property bool gapsOn: false
    property bool animationsOn: false
    property int activeOpacityPercent: 97
    property int inactiveOpacityPercent: 88
    property bool fieldsetRoundingOn: true
    property bool hyprReady: false
    property bool uiReady: false
    readonly property bool settingsBusy: hyprToggleProc.running || hyprSetProc.running
        || uiToggleProc.running
    readonly property bool active: host && host.opened
        && (host.activeModule === "settings" || host.settingsEmbedded === true)

    Keys.onEscapePressed: {
        if (root.focusInTextInput()) {
            root.releaseTextFocus()
            return
        }
        if (host)
            host.dismiss()
    }
    Keys.onPressed: function(event) {
        if (!root.showTabBar)
            return
        if (event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backtab)
            return
        if (!(event.modifiers & Qt.ControlModifier) && focusInTextInput())
            return
        if (event.modifiers & Qt.ShiftModifier || event.key === Qt.Key_Backtab)
            settingsTabs.currentIndex = (settingsTabs.currentIndex + looksTabModel.length - 1) % looksTabModel.length
        else
            settingsTabs.currentIndex = (settingsTabs.currentIndex + 1) % looksTabModel.length
        event.accepted = true
    }

    function focusInTextInput() {
        var item = root.activeFocusItem
        while (item) {
            if (item instanceof TextInput || item instanceof TextField)
                return true
            item = item.parent
        }
        return false
    }

    function isEffectivelyVisible(item) {
        var node = item
        while (node) {
            if (node.visible === false || node.opacity === 0)
                return false
            node = node.parent
        }
        return true
    }

    function collectSettingsNavItems(item, out) {
        if (!item)
            return
        if (item.enabled !== false && root.isEffectivelyVisible(item)) {
            if (item.settingsNavInput !== undefined)
                out.push({ kind: "input", target: item, input: item.settingsNavInput })
            else if (item.settingsNavActivate === true && item.keyboardSelected !== undefined)
                out.push({ kind: "activate", target: item })
            else if (typeof item.toggled === "function" && item.keyboardSelected !== undefined)
                out.push({ kind: "toggle", target: item })
            else if (typeof item.valueCommitted === "function" && item.maximum !== undefined)
                out.push({ kind: "slider", target: item })
        }
        var kids = item.children
        if (!kids)
            return
        for (var i = 0; i < kids.length; i++)
            root.collectSettingsNavItems(kids[i], out)
    }

    function currentSettingsNavEntry() {
        var list = root.settingsNavItems
        if (!list || list.length === 0)
            return null
        var idx = Math.max(0, Math.min(root.settingsKeyIndex, list.length - 1))
        return list[idx]
    }

    function clearSettingsNavHighlights() {
        var list = root.settingsNavItems
        for (var i = 0; i < list.length; i++) {
            var target = list[i].target
            if (target && target.keyboardSelected !== undefined)
                target.keyboardSelected = false
        }
    }

    function releaseTextFocus() {
        if (!root.focusInTextInput())
            return
        var item = root.activeFocusItem
        if (item && item.focus !== undefined)
            item.focus = false
        if (host && typeof host.focusSearch === "function")
            host.focusSearch()
        else
            root.forceActiveFocus()
    }

    function activeTabContent() {
        return looksTab
    }

    function activeTabFlickable() {
        return looksTabScroll
    }

    function rebuildSettingsNav() {
        if (!root.compactLayout)
            return
        var out = []
        root.collectSettingsNavItems(root.activeTabContent(), out)
        root.clearSettingsNavHighlights()
        root.settingsNavItems = out
        if (root.settingsKeyIndex >= out.length)
            root.settingsKeyIndex = Math.max(0, out.length - 1)
        root.applySettingsKeyFocus()
    }

    function applySettingsKeyFocus() {
        root.clearSettingsNavHighlights()
        var entry = root.currentSettingsNavEntry()
        if (!entry)
            return
        if (entry.target && entry.target.keyboardSelected !== undefined)
            entry.target.keyboardSelected = true
        root.ensureSettingsNavVisible(entry.target)
    }

    function ensureSettingsNavVisible(target) {
        var flick = root.activeTabFlickable()
        if (!flick || !target)
            return
        var pos = target.mapToItem(flick.contentItem, 0, 0)
        var y = pos.y
        var bottom = y + target.height
        if (y < flick.contentY)
            flick.contentY = Math.max(0, y)
        else if (bottom > flick.contentY + flick.height)
            flick.contentY = Math.max(0, bottom - flick.height)
    }

    function moveSettingsFocus(delta) {
        if (!root.compactLayout)
            return
        root.releaseTextFocus()
        root.rebuildSettingsNav()
        var count = root.settingsNavItems.length
        if (count <= 0)
            return
        root.settingsKeyIndex = (root.settingsKeyIndex + delta + count) % count
        root.applySettingsKeyFocus()
    }

    function adjustSettingsNavHorizontal(delta) {
        if (!root.compactLayout || root.focusInTextInput())
            return false
        root.rebuildSettingsNav()
        var entry = root.currentSettingsNavEntry()
        if (!entry || entry.kind !== "slider" || !entry.target || entry.target.enabled === false)
            return false
        var slider = entry.target
        var next = Math.max(slider.minimum, Math.min(slider.maximum, slider.value + delta * slider.step))
        if (next === slider.value)
            return true
        slider.dragValue = next
        slider.value = next
        slider.valueEdited(next)
        slider.valueCommitted(next)
        return true
    }

    function activateSettingsFocus() {
        if (!root.compactLayout)
            return
        root.rebuildSettingsNav()
        var entry = root.currentSettingsNavEntry()
        if (!entry || !entry.target || entry.target.enabled === false)
            return
        if (entry.kind === "toggle")
            entry.target.toggled()
        else if (entry.kind === "activate" && typeof entry.target.clicked === "function")
            entry.target.clicked()
        else if (entry.kind === "input" && entry.input)
            entry.input.forceActiveFocus()
    }

    onMenuFilterTextChanged: Qt.callLater(root.rebuildSettingsNav)

    function sectionFilterVisible(label) {
        var q = String(menuFilterText || "").trim().toLowerCase()
        if (!q)
            return true
        return String(label || "").toLowerCase().indexOf(q) >= 0
    }

    property var jsonJobs: []

    function runJsonScript(command, applyFn) {
        var key = JSON.stringify(command || [])
        if (jsonScriptProc.running && JSON.stringify(jsonScriptProc.command) === key)
            return
        for (var i = 0; i < jsonJobs.length; i++) {
            if (JSON.stringify(jsonJobs[i].command) === key)
                return
        }
        var jobs = jsonJobs.slice()
        jobs.push({ command: command, apply: applyFn })
        jsonJobs = jobs
        if (!jsonScriptProc.running)
            startNextJsonJob()
    }

    function startNextJsonJob() {
        if (jsonJobs.length === 0)
            return
        var job = jsonJobs[0]
        jsonScriptProc.applyFn = job.apply
        jsonScriptProc.command = job.command
        jsonScriptProc.running = true
    }

    function finishJsonJob(text) {
        var jobs = jsonJobs.slice()
        var job = jobs.shift()
        jsonJobs = jobs
        if (job && job.apply)
            job.apply(text)
        if (jsonJobs.length > 0)
            Qt.callLater(startNextJsonJob)
    }

    function refresh() {
        Theme.reloadLooks()
        runJsonScript(["bash", hyprScript, "get"], function(text) {
            root.parseHyprState(text)
            Theme.reloadLooks()
        })
        runJsonScript(["bash", barScript, "ui", "get"], function(text) { root.parseUiState(text) })
    }

    function toggleHypr(key) {
        if (!hyprReady || settingsBusy) return
        hyprToggleProc.command = ["bash", root.hyprScript, "toggle", String(key)]
        hyprToggleProc.running = true
    }

    function setHyprOpacity(key, percent) {
        if (!hyprReady || settingsBusy) return
        hyprSetProc.key = key
        hyprSetProc.value = String(percent)
        hyprSetProc.running = true
    }

    function toggleFieldsetRounding() {
        if (!uiReady || settingsBusy) return
        uiToggleProc.running = true
    }

    function onActivated() {
        refresh()
        Qt.callLater(function() {
            if (!(host && host.keepSearchFocus))
                root.forceActiveFocus()
            root.rebuildSettingsNav()
        })
    }

    onActiveChanged: {
        if (active && !(host && host.keepSearchFocus))
            Qt.callLater(function() { root.forceActiveFocus() })
    }

    function parseHyprState(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            root.roundingOn = data.roundingOn === true
            root.gapsOn = data.gapsOn === true
            root.animationsOn = data.animationsOn === true
            root.activeOpacityPercent = Math.round(Number(data.activeOpacity || 0.97) * 100)
            root.inactiveOpacityPercent = Math.round(Number(data.inactiveOpacity || 0.88) * 100)
            root.hyprReady = true
        } catch (e) {
            root.hyprReady = false
        }
    }

    function parseUiState(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            root.fieldsetRoundingOn = data.fieldsetRounding !== false
            root.uiReady = true
        } catch (e) {
            root.uiReady = false
        }
    }

    Process {
        id: jsonScriptProc
        property var applyFn: null
        stdout: StdioCollector {
            onStreamFinished: root.finishJsonJob(text)
        }
    }

    Process {
        id: hyprToggleProc
        stdout: StdioCollector {
            onStreamFinished: root.parseHyprState(text)
        }
        onExited: Theme.reloadLooks()
    }

    Process {
        id: hyprSetProc
        property string key: ""
        property string value: ""
        command: ["bash", root.hyprScript, "set", hyprSetProc.key, hyprSetProc.value]
        stdout: StdioCollector {
            onStreamFinished: root.parseHyprState(text)
        }
        onExited: Theme.reloadLooks()
    }

    Process {
        id: uiToggleProc
        command: ["bash", root.barScript, "ui", "toggle", "fieldsetRounding"]
        stdout: StdioCollector {
            onStreamFinished: root.parseUiState(text)
        }
        onExited: Theme.reloadUi()
    }

    readonly property var looksTabModel: [
        { label: "Looks", icon: "󰒠" }
    ]

    implicitHeight: parent && parent.height > 0 ? parent.height : settingsLayout.implicitHeight
    implicitWidth: root.compactLayout
        ? (host && host.width > 0
            ? host.width
            : Theme.menuPanelWidth(Quickshell.screens.length > 0 ? Quickshell.screens[0].width : 1920))
        : Theme.settingsPanelWidth

    RowLayout {
        id: settingsLayout
        anchors.fill: parent
        spacing: root.showTabBar ? Theme.spacingM : 0

        SettingsTabBar {
            id: settingsTabs
            visible: root.showTabBar
            vertical: true
            Layout.preferredWidth: root.showTabBar ? Theme.settingsSideTabWidth : 0
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
            tabs: root.looksTabModel
            onTabActivated: function(index) {
                settingsTabs.currentIndex = index
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Flickable {
                id: looksTabScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: width
                contentHeight: looksTab.implicitHeight

                LooksTab {
                    id: looksTab
                    width: parent.width
                    module: root
                }
            }
        }
    }
}
