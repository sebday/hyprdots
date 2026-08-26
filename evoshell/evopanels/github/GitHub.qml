import QtQuick
import "../../commons"
import "."

BarHoverPanel {
    pluginId: "evo.panels.github"
    layerNamespace: "evo-panels-github"
    contentWidth: Theme.hoverPanelWidthStandard

    GitHubModule {}
}
