import QtQuick
import "../../../Commons"
import "."

BarHoverPopup {
    pluginId: "evo.bar.popups.home-assistant"
    layerNamespace: "evo-bar-popups-home-assistant"
    contentWidth: Theme.hoverPopupWidthStandard

    HomeAssistantModule {}
}
