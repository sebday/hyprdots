import Quickshell
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
    property bool pinned: false

    readonly property string layoutScript: Quickshell.env("HOME") + "/.local/bin/evo-panel-layout.sh"

    readonly property var modules: [
        { id: "calc", icon: "󰃬", title: "Calculator" },
        { id: "notes", icon: "󰠮", title: "Notes" },
        { id: "stats", icon: "󰄨", title: "Stats" },
        { id: "clipboard", icon: "󰅌", title: "Clipboard" },
        { id: "weather", icon: "󰖐", title: "Weather" },
        { id: "settings", icon: "󰒓", title: "Settings" }
    ]

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
        pinned = false
        var nextModule = parseModule(payloadJson)
        if (moduleIds.indexOf(nextModule) < 0)
            nextModule = activeModule
        if (moduleIds.indexOf(nextModule) < 0)
            nextModule = "calc"
        activeModule = nextModule
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
        pinned = false
        dock.conceal()
        opened = false
    }

    function dismiss() {
        if (shell) shell.hide("evo.panel")
        else close()
    }

    function togglePinned() {
        pinned = !pinned
    }

    function toggleSide() {
        if (sideToggleProc.running) return
        sideToggleProc.running = true
    }

    readonly property var moduleIds: modules.map(function(m) { return m.id })

    readonly property string panelSide: {
        var panel = shell && shell.shellConfig && shell.shellConfig.panel
        return (panel && String(panel.side) === "right") ? "right" : "left"
    }

    readonly property string panelOutput: {
        var panel = shell && shell.shellConfig && shell.shellConfig.panel
        return (panel && panel.output) ? String(panel.output).trim() : ""
    }

    function screenForOutput(outputName) {
        var screens = Quickshell.screens
        if (!screens || screens.length === 0) return null
        var output = String(outputName || "").trim()
        if (!output) return null
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i]
            if (s && String(s.name) === output) return s
        }
        return null
    }

    readonly property var panelScreen: screenForOutput(root.panelOutput)

    function activateModule() {
        Qt.callLater(function() {
            if (activeModule === "calc" && calcModule)
                calcModule.onActivated()
            else if (activeModule === "notes" && notesModule)
                notesModule.onActivated()
            else if (activeModule === "stats" && statsModule)
                statsModule.onActivated()
            else if (activeModule === "clipboard" && clipboardModule)
                clipboardModule.onActivated()
            else if (activeModule === "weather" && weatherModule)
                weatherModule.onActivated()
            else if (activeModule === "settings" && settingsModule)
                settingsModule.onActivated()
        })
    }

    Process {
        id: sideToggleProc
        command: ["bash", root.layoutScript, "toggle"]
    }

    LeftDockPanel {
        id: dock
        layerNamespace: "evo-panel"
        side: root.panelSide
        screen: root.panelScreen
        pinned: root.pinned
        showCloseButton: true
        showPinButton: true
        showSideButton: true
        onCloseRequested: root.dismiss()
        onPinRequested: root.togglePinned()
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

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 8
            currentIndex: Math.max(0, root.moduleIds.indexOf(root.activeModule))

            CalcModule {
                id: calcModule
                panel: root
                shell: root.shell
            }

            NotesModule {
                id: notesModule
                panel: root
                shell: root.shell
            }

            StatsModule {
                id: statsModule
                panel: root
                shell: root.shell
            }

            ClipboardModule {
                id: clipboardModule
                panel: root
                shell: root.shell
            }

            WeatherModule {
                id: weatherModule
                panel: root
                shell: root.shell
            }

            SettingsModule {
                id: settingsModule
                panel: root
                shell: root.shell
            }
        }
    }
}
