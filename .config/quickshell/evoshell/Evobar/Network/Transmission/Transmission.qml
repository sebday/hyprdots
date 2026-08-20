import QtQuick
import "../../../Commons"
import "."

BarHoverPopup {
    pluginId: "evo.bar.network.transmission"
    layerNamespace: "evo-bar-network-transmission"
    contentWidth: Theme.hoverPopupWidthStandard
    minContentHeight: 120

    TransmissionModule {}
}
