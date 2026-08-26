import QtQuick
import "../../../commons"
import "."

BarHoverPanel {
    pluginId: "evo.panels.network.transmission"
    layerNamespace: "evo-panels-network-transmission"
    contentWidth: Theme.hoverPanelWidthStandard
    minContentHeight: 120

    TransmissionModule {}
}
