import QtQuick
import "../../commons"
import "."

BarHoverPanel {
    pluginId: "evo.panels.workspaces"
    layerNamespace: "evo-panels-workspaces"
    contentWidth: Theme.hoverPanelWidthStandard

    WorkspacesModule {}
}
