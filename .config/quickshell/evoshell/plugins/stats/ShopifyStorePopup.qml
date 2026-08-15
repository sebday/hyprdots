import QtQuick
import "../../Commons"
import "."

BarHoverTooltip {
    id: root

    required property string storeKey
    required property string title
    required property string adminUrl

    contentWidth: Theme.tooltipWidthWide

    ShopifyStoreModule {
        storeKey: root.storeKey
        title: root.title
        adminUrl: root.adminUrl
    }
}
