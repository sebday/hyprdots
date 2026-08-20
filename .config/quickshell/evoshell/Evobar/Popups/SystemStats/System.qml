import QtQuick
import "../../../Commons"
import "."

BarHoverPopup {
    pluginId: "evo.bar.popups.system-stats"
    layerNamespace: "evo-bar-popups-system-stats"
    contentWidth: Theme.hoverPopupWidthStandard

    SystemModule {}
}
