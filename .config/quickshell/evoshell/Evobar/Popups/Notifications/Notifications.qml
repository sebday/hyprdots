import QtQuick
import "../../../Commons"
import "."

BarHoverPopup {
    pluginId: "evo.bar.popups.notifications"
    layerNamespace: "evo-bar-popups-notifications"
    contentWidth: Theme.hoverPopupWidthWide
    minContentHeight: 220

    NotificationsModule {}
}
