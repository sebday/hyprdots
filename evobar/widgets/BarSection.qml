import QtQuick
import Quickshell
import "../../commons"
import "."

Row {
    id: root

    property var bar: null
    property var barPanel: null
    property var shell: null
    property var barConfig: ({})
    property var entries: []
    property var widgetRegistry: null
    property int sectionMargin: 0

    spacing: Theme.barGap
    height: Theme.barHeight
    anchors.leftMargin: sectionMargin
    anchors.rightMargin: sectionMargin

    function widgetComponentFor(entry) {
        if (entry.type === "command" || entry.exec) return commandComp
        if (!widgetRegistry) return null
        return widgetRegistry.componentFor(String(entry.id || ""))
    }

    function entryVisible(entry) {
        if (!entry || entry.enabled === false)
            return false
        if (String(entry.id || "") === "evo.bar.workspaces") {
            var chrome = barConfig && barConfig.barWidgets ? barConfig.barWidgets.workspaces : null
            if (chrome && chrome.enabled === false)
                return false
        }
        return true
    }

    readonly property var visibleEntries: {
        var out = []
        var i
        for (i = 0; i < entries.length; i++) {
            if (entryVisible(entries[i]))
                out.push(entries[i])
        }
        return out
    }

    Component { id: commandComp; CommandWidget {} }

    Repeater {
        model: root.visibleEntries
        delegate: Loader {
            required property var modelData
            property var entry: modelData
            height: Theme.barHeight
            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: root.widgetComponentFor(entry)
            onLoaded: {
                if (!item) return
                if ("bar" in item) item.bar = root.bar
                if ("barPanel" in item) item.barPanel = root.barPanel
                if ("settings" in item) item.settings = entry
                if ("shell" in item) item.shell = root.shell
                if (typeof item.restartPolling === "function") item.restartPolling()
                else if (typeof item.runExec === "function") item.runExec()
            }
        }
    }
}
