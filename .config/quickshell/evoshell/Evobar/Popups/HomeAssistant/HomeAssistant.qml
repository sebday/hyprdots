import QtQuick
import "../../../Commons"
import "."

BarHoverPopup {
    pluginId: "evo.bar.popups.home-assistant"
    layerNamespace: "evo-bar-popups-home-assistant"
    contentWidth: Theme.hoverPopupWidthWide + 300
    minContentHeight: 200

    HomeAssistantModule {}
}
