import QtQuick
import "../../commons"
import "."

BarHoverPanel {
    pluginId: "evo.panels.cloudflare"
    layerNamespace: "evo-panels-cloudflare"
    contentWidth: Theme.hoverPanelWidthStandard
    minContentHeight: 160

    CloudflareModule {}
}
