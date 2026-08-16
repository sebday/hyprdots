import QtQuick
import "../../Commons"
import "."

BarHoverPopup {
    layerNamespace: "evo-cloudflare"
    contentWidth: Theme.hoverPopupWidthWide
    minContentHeight: 160

    CloudflareModule {}
}
