import QtQuick
import "../../../Commons"
import "."

BarHoverPopup {
    pluginId: "evo.bar.media.evo-player"
    layerNamespace: "evo-bar-media-evo-player"
    contentWidth: Theme.hoverPopupWidthStandard

    EvoPlayerModule {}
}
