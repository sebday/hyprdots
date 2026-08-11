import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "modules"

Item {
    id: root

    property var shell: null
    property bool opened: false
    property string activeModule: "calc"

    readonly property var modules: [
        { id: "calc", icon: "󰃬", title: "Calculator" },
        { id: "settings", icon: "󰒓", title: "Settings" }
    ]

    function open(payloadJson) {
        var nextModule = activeModule
        if (payloadJson) {
            try {
                var payload = JSON.parse(String(payloadJson))
                if (payload && payload.module)
                    nextModule = String(payload.module)
            } catch (e) {}
        }
        activeModule = moduleIds.indexOf(nextModule) >= 0 ? nextModule : "calc"
        dock.reveal()
        opened = true
        activateModule()
    }

    function close() {
        dock.conceal()
        opened = false
    }

    function dismiss() {
        if (shell) shell.hide("evo.panel")
        else close()
    }

    readonly property var moduleIds: modules.map(function(m) { return m.id })

    readonly property string panelSide: {
        var panel = shell && shell.shellConfig && shell.shellConfig.panel
        return (panel && String(panel.side) === "right") ? "right" : "left"
    }

    function activateModule() {
        Qt.callLater(function() {
            if (activeModule === "calc" && calcModule)
                calcModule.onActivated()
            else if (activeModule === "settings" && settingsModule)
                settingsModule.onActivated()
        })
    }

    LeftDockPanel {
        id: dock
        layerNamespace: "evo-panel"
        side: root.panelSide
        showCloseButton: true
        onCloseRequested: root.dismiss()

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
            currentIndex: root.activeModule === "settings" ? 1 : 0

            CalcModule {
                id: calcModule
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
