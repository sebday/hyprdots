import QtQuick
import "../../commons"
import "."

BarHoverPanel {
    pluginId: "evo.panels.system"
    layerNamespace: "evo-panels-system"
    contentWidth: Theme.hoverPanelWidthStandard

    SystemModule {}
}
