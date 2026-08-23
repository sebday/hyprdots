import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "."
import "../commons"

Item {
    id: root

    property var shell: null
    property bool demoMode: false
    property var storeDefs: []

    readonly property int compactBreakpoint: 1000
    readonly property int compactPanelHeight: 635
    readonly property int columnPad: Theme.hoverPanelMargin
    readonly property int columnTopPad: Theme.hoverPanelTopPad
    readonly property bool layoutCompact: root.width > 0 && root.width < compactBreakpoint
    readonly property bool layoutShort: root.height > 0
        && root.height < root.compactPanelHeight + root.columnTopPad + root.columnPad
    readonly property bool stackStores: root.layoutCompact
    readonly property bool scrollStores: root.layoutCompact || root.layoutShort

    readonly property var activeStoreDefs: root.demoMode ? root.demoStores : root.storeDefs

    readonly property var demoStores: [
        { key: "STORE_A", title: "Store A", adminSlug: "" },
        { key: "STORE_B", title: "Store B", adminSlug: "" }
    ]

    onDemoModeChanged: if (!demoMode) bootstrapStoreDefs()

    readonly property string shopifyScript: (shell && shell.configDir)
        ? shell.configDir + "/plugins/shopify/bin/evo-panel-shopify"
        : (Quickshell.env("HOME") || "") + "/.config/evoshell/plugins/shopify/bin/evo-panel-shopify"

    function storesFromShellConfig() {
        var cfg = shell && shell.shellConfig && shell.shellConfig.shopify
        var stores = cfg && cfg.stores
        if (!Array.isArray(stores) || stores.length === 0)
            return []
        return stores
    }

    function bootstrapStoreDefs() {
        var fromCfg = storesFromShellConfig()
        if (fromCfg.length > 0)
            root.storeDefs = fromCfg
        else if (!root.storeDefs || root.storeDefs.length === 0)
            root.storeDefs = root.demoStores
    }

    function applyStoreDefs(raw) {
        try {
            var parsed = JSON.parse(String(raw || "").trim() || "[]")
            if (Array.isArray(parsed) && parsed.length > 0)
                root.storeDefs = parsed
        } catch (e) {}
    }

    Process {
        id: storesProc
        command: ["bash", root.shopifyScript, "stores"]
        stdout: StdioCollector {
            onStreamFinished: root.applyStoreDefs(text)
        }
    }

    onShellChanged: bootstrapStoreDefs()

    Connections {
        target: shell
        enabled: shell !== null
        function onShellConfigChanged() {
            root.bootstrapStoreDefs()
        }
    }

    Component.onCompleted: {
        bootstrapStoreDefs()
        storesProc.running = true
    }

    Flickable {
        id: storeScroller
        anchors.fill: parent
        anchors.topMargin: columnTopPad
        anchors.leftMargin: columnPad
        anchors.rightMargin: columnPad
        anchors.bottomMargin: columnPad
        contentWidth: width
        contentHeight: root.scrollStores ? storeGrid.implicitHeight : height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: false

        WheelHandler {
            onWheel: function(event) {
                if (!root.scrollStores)
                    return
                var delta = event.angleDelta.y
                if (delta === 0)
                    return
                var next = storeScroller.contentY - delta / 2
                var maxY = Math.max(0, storeScroller.contentHeight - storeScroller.height)
                storeScroller.contentY = Math.max(0, Math.min(maxY, next))
                event.accepted = true
            }
        }

        GridLayout {
            id: storeGrid
            width: storeScroller.width
            height: root.scrollStores ? implicitHeight : storeScroller.height
            columnSpacing: columnPad
            rowSpacing: columnPad
            columns: root.stackStores ? 1 : Math.min(2, storeRepeater.count)

            Repeater {
                id: storeRepeater
                model: root.activeStoreDefs

                delegate: StoreColumn {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.fillHeight: !root.scrollStores
                    Layout.preferredHeight: root.scrollStores ? root.compactPanelHeight : -1
                    Layout.minimumHeight: root.compactPanelHeight
                    shell: root.shell
                    demoMode: root.demoMode
                    storeKey: String(modelData.key || "")
                    title: String(modelData.title || modelData.key || "")
                    adminSlug: String(modelData.adminSlug || "")
                }
            }
        }
    }

    component StoreColumn: Item {
        id: column

        required property var shell
        required property bool demoMode
        required property string storeKey
        required property string title
        required property string adminSlug

        readonly property string adminUrl: adminSlug !== ""
            ? "https://admin.shopify.com/store/" + adminSlug + "/analytics/live"
            : ""

        Item {
            id: storeHost
            visible: false
            property bool opened: true
            property var shell: column.shell
        }

        ShopifyStoreModule {
            id: storeModule
            anchors.fill: parent
            chartFillHeight: true
            demoMode: column.demoMode
            host: storeHost
            shell: column.shell
            storeKey: column.storeKey
            title: column.title
            adminSlug: column.adminSlug
            adminUrl: column.adminUrl
            legendTitle: column.title
            hoverPanelWidth: Math.max(0, column.width)

            Component.onCompleted: {
                bootstrapFromCache()
                onActivated()
            }
        }
    }
}
