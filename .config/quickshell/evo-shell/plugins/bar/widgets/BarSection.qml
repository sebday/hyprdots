import QtQuick
import Quickshell
import "../../../Commons"
import "."

Row {
    id: root

    property var bar: null
    property var barPanel: null
    property var shell: null
    property var barConfig: ({})
    property var entries: []
    property int sectionMargin: 0

    spacing: Theme.barGap
    height: Theme.barHeight
    anchors.leftMargin: sectionMargin
    anchors.rightMargin: sectionMargin

    function widgetComponentFor(entry) {
        var id = String(entry.id || "")
        if (id === "evo.menu") return menuWidgetComp
        if (id === "evo.workspaces") return workspacesComp
        if (id === "evo.clock") return clockComp
        if (id === "evo.audio") return audioComp
        if (id === "evo.tray") return trayComp
        if (id === "evo.github") return githubComp
        if (id === "evo.cava" || id === "cava") return cavaComp
        if (id === "evo.shopify") return shopifyComp
        if (entry.type === "command" || entry.exec) return commandComp
        return null
    }

    Component { id: menuWidgetComp; MenuBarWidget { shell: root.shell } }
    Component { id: workspacesComp; WorkspacesWidget {} }
    Component { id: clockComp; ClockWidget {} }
    Component { id: audioComp; AudioWidget { shell: root.shell } }
    Component { id: trayComp; TrayWidget {} }
    Component { id: commandComp; CommandWidget {} }
    Component { id: githubComp; GithubWidget {} }
    Component { id: shopifyComp; ShopifyWidget {} }
    Component { id: cavaComp; CavaWidget {} }

    Repeater {
        model: root.entries
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
