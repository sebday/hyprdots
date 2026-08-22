import QtQuick
import "widgets"

Item {
    id: catalog

    property var registry: null
    visible: false

    Component { id: menuWidgetComp; SettingsWidget {} }
    Component { id: workspacesComp; WorkspacesWidget {} }
    Component { id: clockComp; ClockWidget {} }
    Component { id: volumeComp; VolumeWidget {} }
    Component { id: trayComp; TrayWidget {} }
    Component { id: githubComp; GitHubWidget {} }
    Component { id: systemComp; SystemWidget {} }
    Component { id: networkComp; NetworkWidget {} }

    function registerAll() {
        if (!registry) return
        registry.register("evo.sys.settings", menuWidgetComp, { displayName: "Settings" })
        registry.register("evo.bar.workspaces", workspacesComp, { displayName: "Workspaces" })
        registry.register("evo.bar.clock", clockComp, { displayName: "Clock" })
        registry.register("evo.bar.volume", volumeComp, { displayName: "Volume" })
        registry.register("evo.panels.network.stats", networkComp, { displayName: "Network" })
        registry.register("evo.bar.tray", trayComp, { displayName: "Tray" })
        registry.register("evo.panels.github", githubComp, { displayName: "GitHub" })
        registry.register("evo.panels.system", systemComp, { displayName: "System" })
        registry.register("evo.panels.notifications", notificationsComp, { displayName: "Notifications" })
    }

    Component { id: notificationsComp; NotificationsWidget {} }

    Component.onCompleted: registerAll()
}
