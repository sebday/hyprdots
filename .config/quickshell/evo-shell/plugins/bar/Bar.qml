import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../Commons"
import "widgets"

Scope {
    id: root

    property var shell: null
    property var barConfig: ({})
    property var manifest: null

    readonly property string position: {
        var p = barConfig && barConfig.position ? String(barConfig.position) : "bottom"
        return p
    }

    readonly property string barOutput: {
        if (barConfig && barConfig.output) return String(barConfig.output).trim()
        return ""
    }

    readonly property var barScreenModel: {
        var screens = Quickshell.screens
        var output = barOutput
        if (!screens || screens.length === 0) return []
        if (!output) return screens
        var matched = []
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i]
            if (s && String(s.name) === output) matched.push(s)
        }
        return matched
    }

    function widgetComponentFor(entry) {
        var id = String(entry.id || "")
        if (id === "evo.menu") return menuWidgetComp
        if (id === "evo.workspaces") return workspacesComp
        if (id === "evo.clock") return clockComp
        if (id === "evo.audio") return audioComp
        if (id === "evo.tray") return trayComp
        if (id === "evo.github") return githubComp
        if (id === "evo.cava" || id === "cava") return cavaComp
        if (id === "evo.shopify" || id === "shopify_diy" || id === "shopify_tgs") return shopifyComp
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

    Variants {
        model: root.barScreenModel

        PanelWindow {
            id: barPanel
            required property var modelData
            screen: modelData
            color: Theme.background
            implicitHeight: root.position === "top" || root.position === "bottom" ? Theme.barHeight : 0
            implicitWidth: root.position === "left" || root.position === "right" ? Theme.barHeight : 0

            anchors.top: root.position === "top"
            anchors.bottom: root.position === "bottom"
            anchors.left: root.position === "left" || root.position === "top" || root.position === "bottom"
            anchors.right: root.position === "right" || root.position === "top" || root.position === "bottom"

            WlrLayershell.namespace: "evo-bar"
            WlrLayershell.layer: WlrLayer.Top

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Theme.barGap
                spacing: Theme.barGap
                height: Theme.barHeight

                Repeater {
                    model: (root.barConfig.layout && root.barConfig.layout.left) ? root.barConfig.layout.left : []
                    delegate: Loader {
                        required property var modelData
                        property var entry: modelData
                        height: Theme.barHeight
                        anchors.verticalCenter: parent.verticalCenter
                        sourceComponent: root.widgetComponentFor(entry)
                        onLoaded: {
                            if (!item) return
                            if ("bar" in item) item.bar = root
                            if ("barPanel" in item) item.barPanel = barPanel
                            if ("settings" in item) item.settings = entry
                            if ("shell" in item) item.shell = root.shell
                            if (typeof item.restartPolling === "function") item.restartPolling()
                            else if (typeof item.runExec === "function") item.runExec()
                        }
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.barGap
                height: Theme.barHeight

                Repeater {
                    model: (root.barConfig.layout && root.barConfig.layout.center) ? root.barConfig.layout.center : []
                    delegate: Loader {
                        required property var modelData
                        property var entry: modelData
                        height: Theme.barHeight
                        anchors.verticalCenter: parent.verticalCenter
                        sourceComponent: root.widgetComponentFor(entry)
                        onLoaded: {
                            if (!item) return
                            if ("bar" in item) item.bar = root
                            if ("barPanel" in item) item.barPanel = barPanel
                            if ("settings" in item) item.settings = entry
                            if ("shell" in item) item.shell = root.shell
                            if (typeof item.restartPolling === "function") item.restartPolling()
                            else if (typeof item.runExec === "function") item.runExec()
                        }
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: Theme.barGap
                spacing: Theme.barGap
                height: Theme.barHeight

                Repeater {
                    model: (root.barConfig.layout && root.barConfig.layout.right) ? root.barConfig.layout.right : []
                    delegate: Loader {
                        required property var modelData
                        property var entry: modelData
                        height: Theme.barHeight
                        anchors.verticalCenter: parent.verticalCenter
                        sourceComponent: root.widgetComponentFor(entry)
                        onLoaded: {
                            if (!item) return
                            if ("bar" in item) item.bar = root
                            if ("barPanel" in item) item.barPanel = barPanel
                            if ("settings" in item) item.settings = entry
                            if ("shell" in item) item.shell = root.shell
                            if (typeof item.restartPolling === "function") item.restartPolling()
                            else if (typeof item.runExec === "function") item.runExec()
                        }
                    }
                }
            }
        }
    }
}
