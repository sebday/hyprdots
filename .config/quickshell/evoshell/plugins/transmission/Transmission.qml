import QtQuick
import "../../Commons"
import "."

BarHoverPopup {
    layerNamespace: "evo-transmission"
    contentWidth: Theme.hoverPopupWidthStandard
    minContentHeight: 120

    TransmissionModule {}
}
