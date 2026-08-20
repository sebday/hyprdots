import QtQuick
import "../../../Commons"
import "."

BarHoverPopup {
    pluginId: "evo.bar.popups.cloudflare"
    layerNamespace: "evo-bar-popups-cloudflare"
    contentWidth: Theme.hoverPopupWidthStandard
    minContentHeight: 160

    CloudflareModule {}
}
