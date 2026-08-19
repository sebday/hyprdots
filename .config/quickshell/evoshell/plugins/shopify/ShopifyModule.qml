import QtQuick
import QtQuick.Layouts
import "."
import "../../Commons"

Item {
    id: root

    property var shell: null
    property bool demoMode: false

    readonly property int compactBreakpoint: 1000
    readonly property int compactPanelHeight: 635
    readonly property int columnPad: Theme.hoverPopupMargin
    readonly property int columnTopPad: Theme.hoverPopupTopPad
    readonly property bool layoutCompact: root.width > 0 && root.width < compactBreakpoint
    readonly property bool layoutShort: root.height > 0
        && root.height < root.compactPanelHeight + root.columnTopPad + root.columnPad
    readonly property bool stackStores: root.layoutCompact
    readonly property bool scrollStores: root.layoutCompact || root.layoutShort

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
        interactive: root.scrollStores && contentHeight > height

        GridLayout {
            id: storeGrid
            width: storeScroller.width
            height: root.scrollStores ? implicitHeight : storeScroller.height
            columnSpacing: columnPad
            rowSpacing: columnPad
            columns: root.stackStores ? 1 : 2

            StoreColumn {
                Layout.fillWidth: true
                Layout.fillHeight: !root.scrollStores
                Layout.preferredHeight: root.scrollStores ? root.compactPanelHeight : -1
                Layout.minimumHeight: root.compactPanelHeight
                shell: root.shell
                demoMode: root.demoMode
                storeKey: "DIY"
                title: "DIY"
                adminUrl: "https://admin.shopify.com/store/diy-buildingsupplies/analytics/live"
            }

            StoreColumn {
                Layout.fillWidth: true
                Layout.fillHeight: !root.scrollStores
                Layout.preferredHeight: root.scrollStores ? root.compactPanelHeight : -1
                Layout.minimumHeight: root.compactPanelHeight
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
