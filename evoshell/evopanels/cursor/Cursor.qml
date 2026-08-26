import QtQuick
import "../../commons"
import "."

BarHoverPanel {
    pluginId: "evo.panels.cursor"
    layerNamespace: "evo-panels-cursor"
    contentWidth: Theme.hoverPanelWidthStandard
    minContentHeight: 320

    CursorModule {}
}
