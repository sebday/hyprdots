import QtQuick
import "../../Commons"
import "../stats"

BarHoverTooltip {
    id: root

    required property string storeKey
    required property string title
    required property string adminUrl

    contentWidth: Theme.tooltipWidthStandard

    ShopifyStoreModule {
        storeKey: root.storeKey
        title: root.title
        adminUrl: root.adminUrl
    }
}
