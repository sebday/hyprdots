import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../calc" as Calc
import "../clipboard" as Clipboard
import "modules"

Item {
    id: root

    property var shell: null
    property bool opened: false
    property string activeModule: "calc"
    property string pendingFocus: ""
    property string focusTarget: ""

    readonly property string layoutScript: Quickshell.env("HOME") + "/.local/bin/evo-layout"

    Component { id: calcComp; Calc.AppCalc {} }
    Component { id: clipboardComp; Clipboard.AppClipboard {} }
    Component { id: settingsComp; SettingsModule {} }

    readonly property var dockModules: [
        { id: "calc", component: calcComp },
        { id: "clipboard", component: clipboardComp },
        { id: "settings", component: settingsComp }
    ]

    readonly property var moduleIds: dockModules.map(function(entry) { return entry.id })

    readonly property var navItems: [
        { kind: "module", id: "calc", icon: "󰦬" },
        { kind: "module", id: "clipboard", icon: "󰅌" },
        { kind: "module", id: "settings", icon: "󰒓" }
    ]

    function navActive(item) {
        if (!item) return false
        if (item.kind === "module")
            return activeModule === item.id
        return shell && shell.isPluginOpen(item.id)
    }

    function activateNav(item) {
        if (!item) return
        if (item.kind === "module") {
            if (activeModule === item.id)
                return
            activeModule = item.id
            pendingFocus = ""
            focusTarget = ""
            activateModule()
            return
        }
        if (shell)
            shell.toggle(item.id, "")
    }

    function parsePayload(payloadJson) {
        var out = { module: "", focus: "" }
        if (!payloadJson) return out
        try {
            var payload = JSON.parse(String(payloadJson))
            if (payload && payload.module) {
                var id = String(payload.module)
                if (id === "tools")
                    id = "calc"
                out.module = id
            }
            if (payload && payload.focus)
                out.focus = String(payload.focus)
        } catch (e) {}
        return out
    }

    function parseModule(payloadJson) {
        return parsePayload(payloadJson).module
    }

    function open(payloadJson) {
        var parsed = parsePayload(payloadJson)
        var nextModule = parsed.module
        if (moduleIds.indexOf(nextModule) < 0)
            nextModule = activeModule
        if (moduleIds.indexOf(nextModule) < 0)
            nextModule = "calc"
        activeModule = nextModule
        pendingFocus = parsed.focus
        focusTarget = parsed.focus || ""
        dock.reveal()
        opened = true
        activateModule()
    }

    // Called by shell toggle when panel is already open. Returns true if we
    // switched modules/focus and stayed open; false means the shell should hide us.
    function reopen(payloadJson) {
        var parsed = parsePayload(payloadJson)
        var nextModule = parsed.module
        if (!nextModule || moduleIds.indexOf(nextModule) < 0)
            return false
        var nextFocus = parsed.focus || ""
        if (nextModule === activeModule && nextFocus === focusTarget)
            return false
        pendingFocus = parsed.focus
        focusTarget = nextFocus
        if (nextModule !== activeModule)
            activeModule = nextModule
        activateModule()
        return true
    }

    function close() {
        dock.conceal()
        opened = false
        pendingFocus = ""
        focusTarget = ""
    }

    function dismiss() {
        if (shell) shell.hide("evo.panel")
        else close()
    }

    function toggleSide() {
        if (sideToggleProc.running) return
        panelSideLive = panelSideLive === "right" ? "left" : "right"
        sideToggleProc.running = true
    }

    readonly property string panelSide: {
        var panel = shell && shell.shellConfig && shell.shellConfig.panel
        return (panel && String(panel.side) === "right") ? "right" : "left"
    }

    property string panelSideLive: panelSide

    onPanelSideChanged: panelSideLive = panelSide

    function moduleLoaderFor(id) {
        for (var i = 0; i < moduleLoaders.count; i++) {
            var loader = moduleLoaders.itemAt(i)
            if (loader && loader.moduleId === id)
                return loader
        }
        return null
    }

    function activateModule() {
        Qt.callLater(function() {
            var loader = moduleLoaderFor(activeModule)
            var focus = pendingFocus
            pendingFocus = ""
            if (loader && loader.item && typeof loader.item.onActivated === "function")
                loader.item.onActivated(focus)
        })
    }

    Process {
        id: sideToggleProc
        command: ["bash", root.layoutScript, "panel", "toggle"]
        onExited: {
            root.panelSideLive = root.panelSide
        }
    }

    LeftDockPanel {
        id: dock
        layerNamespace: "evo-panel"
        side: root.panelSideLive
        pinned: true
        showSideButton: true
        onCloseRequested: root.dismiss()
        onSideRequested: root.toggleSide()

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            spacing: 2

            Repeater {
                model: root.navItems

                Item {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28

                    readonly property bool current: root.navActive(modelData)

                    Text {
                        anchors.centerIn: parent
                        text: modelData.icon
                        color: parent.current ? Theme.accent : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.panelIconFontPixelSize
                        font.bold: Theme.fontBold
                        opacity: navMouse.containsMouse || parent.current ? 1 : 0.62
                    }

                    MouseArea {
                        id: navMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activateNav(modelData)
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Repeater {
                id: moduleLoaders
                model: root.dockModules

                delegate: Loader {
                    required property var modelData
                    readonly property string moduleId: modelData.id

                    anchors.fill: parent
                    active: moduleId === root.activeModule
                    visible: active
                    sourceComponent: modelData.component

                    onLoaded: {
                        if (!item) return
                        if ("host" in item) item.host = root
                        if ("shell" in item) item.shell = root.shell
                    }
                }
            }
        }
    }
}
