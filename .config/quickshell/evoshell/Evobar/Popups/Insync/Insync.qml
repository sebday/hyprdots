import QtQuick
import "../../../Commons"
import "."

BarHoverPopup {
    pluginId: "evo.bar.popups.insync"
    layerNamespace: "evo-bar-popups-insync"
    contentWidth: Theme.hoverPopupWidthStandard
    minContentHeight: 120

    InsyncModule {}
}
