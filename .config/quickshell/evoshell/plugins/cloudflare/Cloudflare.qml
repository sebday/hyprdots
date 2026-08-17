import QtQuick
import "../../Commons"
import "."

BarHoverPopup {
    layerNamespace: "evo-cloudflare"
    contentWidth: Theme.hoverPopupWidthStandard
    minContentHeight: 160

    CloudflareModule {}
}
