import QtQuick
import QtQuick.Layouts
import "."
import "../../Commons"

Item {
    id: root

    property var shell: null
    property bool demoMode: false

    readonly property int compactBreakpoint: 1000
    readonly property bool layoutCompact: root.width > 0 && root.width < compactBreakpoint
    readonly property int compactPanelHeight: 635
    readonly property int columnPad: Theme.hoverPopupMargin

    Flickable {
        id: storeScroller
        anchors.fill: parent
        anchors.margins: columnPad
        contentWidth: width
        contentHeight: root.layoutCompact ? storeGrid.implicitHeight : height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: root.layoutCompact && contentHeight > height

        GridLayout {
            id: storeGrid
            width: storeScroller.width
            height: root.layoutCompact ? implicitHeight : storeScroller.height
            columnSpacing: columnPad
            rowSpacing: columnPad
            columns: root.layoutCompact ? 1 : 2

            StoreColumn {
                Layout.fillWidth: true
                Layout.fillHeight: !root.layoutCompact
                Layout.preferredHeight: root.layoutCompact ? root.compactPanelHeight : -1
                Layout.minimumHeight: root.layoutCompact ? root.compactPanelHeight : 0
                shell: root.shell
                demoMode: root.demoMode
                storeKey: "DIY"
                title: "DIY"
                adminUrl: "https://admin.shopify.com/store/diy-buildingsupplies/analytics/live"
            }

            StoreColumn {
                Layout.fillWidth: true
                Layout.fillHeight: !root.layoutCompact
                Layout.preferredHeight: root.layoutCompact ? root.compactPanelHeight : -1
                Layout.minimumHeight: root.layoutCompact ? root.compactPanelHeight : 0
                shell: root.shell
                demoMode: root.demoMode
                storeKey: "TGS"
                title: "TGS"
                adminUrl: "https://admin.shopify.com/store/thegoodsheet-uk/analytics/live"
            }
        }
    }

    component StoreColumn: Item {
        id: column

        required property var shell
        required property bool demoMode
        required property string storeKey
        required property string title
        required property string adminUrl

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
            adminUrl: column.adminUrl
            hoverPopupWidth: Math.max(0, column.width)

            Component.onCompleted: {
                bootstrapFromCache()
                onActivated()
            }
        }
    }
}
