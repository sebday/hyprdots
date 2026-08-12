import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "modules"

Item {
    id: root

    property var shell: null
    property bool opened: false
    property string activeModule: "calc"

    readonly property string layoutScript: Quickshell.env("HOME") + "/.local/bin/evo-shell-layout.sh"

    Component { id: calcComp; CalcModule {} }
    Component { id: notesComp; NotesModule {} }
    Component { id: settingsComp; SettingsModule {} }

    readonly property var dockModules: [
        { id: "calc", icon: "󰃬", title: "Calculator", component: calcComp },
        { id: "notes", icon: "󰠮", title: "Notes", component: notesComp },
        { id: "settings", icon: "󰒓", title: "Settings", component: settingsComp }
    ]

    readonly property var modules: dockModules.map(function(entry) {
        return { id: entry.id, icon: entry.icon, title: entry.title }
    })

    function parseModule(payloadJson) {
        if (!payloadJson) return ""
        try {
            var payload = JSON.parse(String(payloadJson))
            if (payload && payload.module)
                return String(payload.module)
        } catch (e) {}
        return ""
    }

    function open(payloadJson) {
        var nextModule = parseModule(payloadJson)
        if (moduleIds.indexOf(nextModule) < 0)
            nextModule = activeModule
        if (moduleIds.indexOf(nextModule) < 0)
            nextModule = "calc"
        activeModule = nextModule
        panelScreen = resolvePanelScreen()
        dock.reveal()
        opened = true
        activateModule()
    }

    // Called by shell toggle when panel is already open. Returns true if we
    // switched modules and stayed open; false means the shell should hide us.
    function reopen(payloadJson) {
        var nextModule = parseModule(payloadJson)
        if (!nextModule || moduleIds.indexOf(nextModule) < 0)
            return false
        if (nextModule === activeModule)
            return false
        activeModule = nextModule
        activateModule()
        return true
    }

    function close() {
        dock.conceal()
        opened = false
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

    readonly property var moduleIds: modules.map(function(m) { return m.id })

    readonly property string panelSide: {
        var panel = shell && shell.shellConfig && shell.shellConfig.panel
        return (panel && String(panel.side) === "right") ? "right" : "left"
    }

    property string panelSideLive: panelSide

    onPanelSideChanged: panelSideLive = panelSide

    property var panelScreen: null

    function resolvePanelScreen() {
        try {
            var mon = Hyprland.focusedMonitor
            if (mon) {
                for (var i = 0; i < Quickshell.screens.length; i++) {
                    var s = Quickshell.screens[i]
                    if (s && s.name === mon.name)
                        return s
                }
            }
        } catch (e) {}
        var panel = shell && shell.shellConfig && shell.shellConfig.panel
        var output = panel && panel.output ? String(panel.output).trim() : ""
        return Util.screenForOutput(output, true)
    }

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
            if (loader && loader.item && typeof loader.item.onActivated === "function")
                loader.item.onActivated()
        })
    }

    Process {
        id: sideToggleProc
        command: ["bash", root.layoutScript, "panel", "toggle"]
        onExited: {
            root.panelSideLive = root.panelSide
            root.panelScreen = root.resolvePanelScreen()
        }
    }

    LeftDockPanel {
        id: dock
        layerNamespace: "evo-panel"
        side: root.panelSideLive
        screen: root.panelScreen
        pinned: true
        showCloseButton: true
        showSideButton: true
        onCloseRequested: root.dismiss()
        onSideRequested: root.toggleSide()

        DockModuleBar {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            modules: root.modules
            activeId: root.activeModule
            onModuleActivated: function(id) {
                root.activeModule = id
                root.activateModule()
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 8

            Repeater {
                id: moduleLoaders
                model: root.dockModules

                delegate: Loader {
                    required property var modelData
                    readonly property string moduleId: modelData.id

                    anchors.fill: parent
                    active: true
                    visible: moduleId === root.activeModule
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
