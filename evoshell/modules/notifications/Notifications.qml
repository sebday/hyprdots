import QtQuick
import qs.commons
import "."

BarHoverPanel {
    pluginId: "evo.panels.notifications"
    layerNamespace: "evo-panels-notifications"
    contentWidth: Theme.hoverPanelWidthStandard

    NotificationsModule {}
}
