import QtQuick
import "../../commons"
import "."

BarHoverPanel {
    pluginId: "evo.panels.homeassistant"
    layerNamespace: "evo-panels-homeassistant"
    contentWidth: Theme.hoverPanelWidthStandard

    HomeAssistantModule {}
}
