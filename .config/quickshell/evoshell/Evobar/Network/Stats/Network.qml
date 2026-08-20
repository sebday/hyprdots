import QtQuick
import "../../../Commons"
import "."

BarHoverPopup {
    pluginId: "evo.bar.network.stats"
    layerNamespace: "evo-bar-network-stats"
    contentWidth: Theme.hoverPopupWidthStandard

    NetworkModule {}
}
