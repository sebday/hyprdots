import QtQuick
import "widgets"

Item {
    id: catalog

    property var registry: null
    visible: false

    Component { id: menuWidgetComp; MenuBarWidget {} }
    Component { id: workspacesComp; WorkspacesWidget {} }
    Component { id: clockComp; ClockWidget {} }
    Component { id: volumeComp; VolumeWidget {} }
    Component { id: trayComp; TrayWidget {} }
    Component { id: githubComp; GithubWidget {} }
    Component { id: shopifyComp; ShopifyWidget {} }
    Component { id: systemComp; SystemWidget {} }
    Component { id: networkComp; NetworkWidget {} }

    function registerAll() {
        if (!registry) return
        registry.register("evo.sys.settings", menuWidgetComp, { displayName: "Settings" })
        registry.register("evo.bar.workspaces", workspacesComp, { displayName: "Workspaces" })
        registry.register("evo.bar.clock", clockComp, { displayName: "Clock" })
        registry.register("evo.bar.media.audio", volumeComp, { displayName: "Volume" })
        registry.register("evo.bar.network.stats", networkComp, { displayName: "Network" })
        registry.register("evo.bar.tray", trayComp, { displayName: "Tray" })
        registry.register("evo.bar.popups.github", githubComp, { displayName: "GitHub" })
        registry.register("evo.panel.shopify", shopifyComp, { displayName: "Shopify" })
        registry.register("evo.bar.popups.system-stats", systemComp, { displayName: "System" })
        registry.register("evo.bar.popups.notifications", notificationsComp, { displayName: "Notifications" })
    }

    Component { id: notificationsComp; NotificationsWidget {} }

    Component.onCompleted: registerAll()
}
