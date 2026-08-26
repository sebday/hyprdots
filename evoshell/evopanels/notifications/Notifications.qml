import QtQuick
import "../../commons"
import "."

BarHoverPanel {
    pluginId: "evo.panels.notifications"
    layerNamespace: "evo-panels-notifications"
    contentWidth: Theme.hoverPanelWidthStandard

    NotificationsModule {}
}
