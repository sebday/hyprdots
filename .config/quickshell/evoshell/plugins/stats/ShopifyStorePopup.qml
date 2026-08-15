import QtQuick
import "../../Commons"
import "."

BarHoverPopup {
    id: root

    required property string storeKey
    required property string title
    required property string adminUrl

    contentWidth: Theme.hoverPopupWidthWide

    ShopifyStoreModule {
        storeKey: root.storeKey
        title: root.title
        adminUrl: root.adminUrl
    }
}
