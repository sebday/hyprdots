import QtQuick
import QtQuick.Layouts
import "../stats"
import "../../Commons"

Item {
    id: root

    property var shell: null

    readonly property int columnPad: Theme.hoverPopupMargin

    RowLayout {
        anchors.fill: parent
        anchors.margins: columnPad
        spacing: columnPad

        StoreColumn {
            Layout.fillWidth: true
            Layout.fillHeight: true
            shell: root.shell
            storeKey: "DIY"
            title: "DIY"
            adminUrl: "https://admin.shopify.com/store/diy-buildingsupplies/analytics/live"
        }

        StoreColumn {
            Layout.fillWidth: true
            Layout.fillHeight: true
            shell: root.shell
            storeKey: "TGS"
            title: "TGS"
            adminUrl: "https://admin.shopify.com/store/thegoodsheet-uk/analytics/live"
        }
    }

    component StoreColumn: Item {
        id: column

        required property var shell
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
