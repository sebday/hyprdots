import QtQuick
import "../../commons"
import "."

BarHoverPanel {
    pluginId: "evo.panels.steam"
    layerNamespace: "evo-panels-steam"
    contentWidth: Theme.hoverPanelWidthStandard
    minContentHeight: 120

    SteamModule {}
}
