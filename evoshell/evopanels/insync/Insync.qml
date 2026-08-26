import QtQuick
import "../../commons"
import "."

BarHoverPanel {
    pluginId: "evo.panels.insync"
    layerNamespace: "evo-panels-insync"
    contentWidth: Theme.hoverPanelWidthStandard
    minContentHeight: 120

    InsyncModule {}
}
