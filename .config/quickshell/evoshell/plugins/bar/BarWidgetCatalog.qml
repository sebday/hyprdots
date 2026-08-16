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
        registry.register("evo.settings", menuWidgetComp, { displayName: "Settings" })
        registry.register("evo.workspaces", workspacesComp, { displayName: "Workspaces" })
        registry.register("evo.clock", clockComp, { displayName: "Clock" })
        registry.register("evo.audio", volumeComp, { displayName: "Volume" })
        registry.register("evo.network", networkComp, { displayName: "Network" })
        registry.register("evo.tray", trayComp, { displayName: "Tray" })
        registry.register("evo.github", githubComp, { displayName: "GitHub" })
        registry.register("evo.shopify", shopifyComp, { displayName: "Shopify" })
        registry.register("evo.system", systemComp, { displayName: "System" })
    }

    Component.onCompleted: registerAll()
}
