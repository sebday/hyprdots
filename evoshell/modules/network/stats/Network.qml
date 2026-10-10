import QtQuick
import qs.commons
import "."

BarHoverPanel {
    pluginId: "evo.panels.network.stats"
    layerNamespace: "evo-panels-network-stats"
    contentWidth: Theme.hoverPanelWidthStandard

    NetworkModule {}
}
